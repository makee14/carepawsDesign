import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Splash v2 ambient scene — the badge is the star, the background breathes.
///
/// Two layers, both procedural (no video, no image assets, APK stays light):
///
/// * [SplashAmbient] — the supporting backdrop. Three large soft aurora blobs
///   (amber / orange / warm neutral; deeper tones at lower alpha in dark mode)
///   drift on a seamless 16s loop behind everything, plus ten tiny motes that
///   rise slowly and fade in/out. Blobs stay in the upper two-thirds, dim and
///   clear of the bottom CTA zone.
/// * [BadgeHero] — the animated subject. The badge gets a cinematic entrance
///   (slow fade + gentle scale settle, ease-out only, never a spring), keeps
///   its looping rock + breathe, gains a slow diagonal sheen sweep every 9s
///   and five soft motes emitted from the mark itself.
///
/// Performance: one repeating controller per layer, one [CustomPainter] each.
/// Blob gradients are precomputed once as unit-circle shaders — per frame the
/// painter only translates/scales the canvas, never rebuilds a gradient or
/// allocates. Paint objects are reused; per-frame work is a handful of
/// sin() calls and circle draws. No BackdropFilter, no blur stacks.
///
/// Reduced motion parks every controller on one composed static frame and the
/// entrance renders its final state immediately.
class SplashAmbient extends StatefulWidget {
  const SplashAmbient({super.key});

  /// Loop-safe sinusoid: identical at t=0 and t=1 for any base/amp/phase, so
  /// a `repeat()`ing controller never visibly jumps at the wrap.
  @visibleForTesting
  static double loopOffset(double base, double amp, double phase, double t) =>
      base + amp * math.sin(2 * math.pi * (t + phase));

  /// Loop-safe cycle position in [0, 1): identical at t=0 and t=1.
  @visibleForTesting
  static double loopPhase(double speed, double phase, double t) =>
      (t * speed + phase) % 1;

  /// The colour + peak alpha wash each blob lays over the background.
  /// Test seam: the contrast tests assert text stays readable over these.
  @visibleForTesting
  static List<({Color color, double alpha})> blobWash(bool isDark) => isDark
      ? const [
          (color: T.terracotta, alpha: 0.10),
          (color: T.amber, alpha: 0.09),
          (color: T.taupe, alpha: 0.08),
        ]
      : const [
          (color: T.amber, alpha: 0.12),
          (color: T.orange, alpha: 0.07),
          (color: T.sand, alpha: 0.10),
        ];

  @override
  State<SplashAmbient> createState() => SplashAmbientState();
}

class SplashAmbientState extends State<SplashAmbient>
    with SingleTickerProviderStateMixin {
  /// The slowest authored loop on the splash — one full aurora cycle.
  static const loopDuration = Duration(seconds: 16);

  /// Loop time the scene parks on when motion is reduced.
  static const _staticT = 0.3;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: loopDuration,
  );

  /// Test seam: true while the ambient loop is running.
  bool get debugAmbientRepeating => _c.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      if (_c.isAnimating) _c.stop();
      // One composed static frame — the painter reads value once and rests.
      _c.value = _staticT;
      return;
    }
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _AmbientScenePainter(progress: _c, isDark: context.p.isDark),
        ),
      ),
    );
  }
}

/// The badge as the animated subject: cinematic settle entrance, the existing
/// rock + breathe loop, a slow sheen sweep, and motes emitted from the mark.
///
/// The badge artwork itself comes in as [child] (the splash's [LogoMark]) so
/// this widget never reaches back into app.dart.
class BadgeHero extends StatefulWidget {
  const BadgeHero({
    super.key,
    required this.loop,
    required this.child,
    this.size = 152,
  });

  /// The splash's continuous rock + breathe loop (2.6s), owned by the screen.
  final Animation<double> loop;

  /// The badge artwork, rendered at [size].
  final Widget child;

  final double size;

  /// Sheen alpha at loop time t in [0, 1]. Zero at both ends of the loop so
  /// the sweep is invisible at the wrap — the seamlessness that matters.
  @visibleForTesting
  static double sheenAlpha(double t) {
    if (t < _Sheen.sweepStart || t > _Sheen.sweepEnd) return 0;
    return _Sheen.peakAlpha *
        math.sin(
          math.pi *
              (t - _Sheen.sweepStart) /
              (_Sheen.sweepEnd - _Sheen.sweepStart),
        );
  }

  @override
  State<BadgeHero> createState() => BadgeHeroState();
}

class BadgeHeroState extends State<BadgeHero>
    with SingleTickerProviderStateMixin {
  /// One loop carries both the sheen sweep and the badge motes — they share
  /// a rhythm, so one controller does both.
  static const sheenLoop = Duration(seconds: 9);

  /// Parked loop time under reduced motion: sheen off-badge, motes mid-flight.
  static const _staticT = 0.35;

  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: sheenLoop,
  );

  /// Test seam: true while the sheen/motes loop is running.
  bool get debugSheenRepeating => _sheen.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      if (_sheen.isAnimating) _sheen.stop();
      _sheen.value = _staticT;
      return;
    }
    if (!_sheen.isAnimating) _sheen.repeat();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loop = widget.loop;
    final size = widget.size;
    // Cinematic entrance: a slow fade paired with a gentle scale settle on
    // the house curve — ease-out only, never a spring. Under reduced motion
    // FadeIn paints the final state on the first frame by itself.
    return FadeIn(
      duration: const Duration(milliseconds: 1100),
      settleFrom: 0.94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Badge-emitted motes drift behind the mark.
          SizedBox.square(
            dimension: size + 96,
            child: CustomPaint(
              painter: _BadgeMotesPainter(
                progress: _sheen,
                isDark: context.p.isDark,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: loop,
            builder: (context, child) {
              final t = loop.value;
              // The approved icon-self loop, untouched: a gentle rock (±4°)
              // plus a soft breathing scale, phase-offset so the two never
              // read as mechanical.
              final rock = 0.07 * math.sin(t * math.pi * 2);
              final scale = 1.0 + 0.028 * math.sin(t * math.pi * 2 + 0.9);
              return Transform.rotate(
                angle: rock,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Stack(
              children: [
                widget.child,
                _Sheen(progress: _sheen, size: size),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A slow diagonal light sweep across the badge, once per 9s loop. Rendered
/// as a narrow white band masked to the badge's own alpha (srcIn), so the
/// sheen only ever appears on the mark — never on the background.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.progress, required this.size});

  final Animation<double> progress;
  final double size;

  /// The sweep occupies this slice of each loop; the long idle tail is what
  /// keeps it calm rather than showy.
  static const sweepStart = 0.12;
  static const sweepEnd = 0.34;

  /// Peak band alpha — a glint, not a flash. Perceptible on the mark, never
  /// competing with it.
  static const peakAlpha = 0.18;

  /// Band centre in gradient space, swept diagonally across the badge.
  static double sweepCenter(double t) {
    final p = ((t - sweepStart) / (sweepEnd - sweepStart)).clamp(0.0, 1.0);
    return -0.45 + 1.9 * Curves.easeInOut.transform(p);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final alpha = BadgeHero.sheenAlpha(progress.value);
        if (alpha <= 0.001) return const SizedBox.shrink();
        final s = sweepCenter(progress.value);
        return SizedBox.square(
          dimension: size,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0x00FFFFFF),
                Color(0xFFFFFFFF).withValues(alpha: alpha),
                const Color(0x00FFFFFF),
              ],
              stops: [s - 0.30, s, s + 0.30],
            ).createShader(rect),
            // The badge artwork as an alpha mask only — excluded from
            // semantics so the logo isn't announced twice.
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: size,
                child: Ic.badgeIcon(size: size),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One drifting aurora blob. Positions are fractions of the canvas; the loop
/// math in [SplashAmbient.loopOffset] keeps the motion seamless. Colour and
/// peak alpha come from [SplashAmbient.blobWash] so light and dark themes
/// share one geometry.
class _DriftBlob {
  const _DriftBlob({
    required this.bx,
    required this.by,
    required this.ax,
    required this.ay,
    required this.px,
    required this.py,
    required this.r,
  });

  final double bx, by; // base centre, fractions of w/h
  final double ax, ay; // drift amplitude, fractions of w/h
  final double px, py; // phases
  final double r; // radius, fraction of min(w, h)
}

/// One rising ambient mote. Deterministic per index (seeded), so every run
/// composes the same calm field.
class _AmbientDot {
  _AmbientDot(this.index, bool isDark) {
    final r = math.Random(1100 + index);
    x = r.nextDouble();
    phase = r.nextDouble();
    // Integer cycles per aurora loop: the particle always lands exactly where
    // it started at the wrap, so the loop is seamless. Fractional speeds
    // would visibly jump every 16s.
    speed = index.isEven ? 1.0 : 2.0;
    sway = 0.015 + r.nextDouble() * 0.02;
    swayPhase = r.nextDouble();
    radius = 1.5 + r.nextDouble() * 2.0;
    alpha = isDark
        ? 0.10 + r.nextDouble() * 0.14
        : 0.10 + r.nextDouble() * 0.16;
    color =
        (isDark ? _darkDotColors : _lightDotColors)[r.nextInt(
          isDark ? _darkDotColors.length : _lightDotColors.length,
        )];
  }

  final int index;
  late final double x;
  late final double phase;
  late final double speed;
  late final double sway;
  late final double swayPhase;
  late final double radius;
  late final double alpha;
  late final Color color;

  static const _lightDotColors = [
    T.terracotta,
    T.amber,
    T.sand,
    Color(0xFFFFFFFF),
  ];
  static const _darkDotColors = [T.amber, T.sand, T.terracotta];
}

/// One mote emitted from the badge: starts at the mark's edge, rises and
/// fades over the shared 9s loop.
class _BadgeMote {
  _BadgeMote(this.index, bool isDark) {
    final r = math.Random(2300 + index);
    // Spread around the badge; the rise does the rest.
    angle = index * (2 * math.pi / _moteCount) + r.nextDouble() * 0.5;
    radius = 80 + r.nextDouble() * 12;
    rise = 44 + r.nextDouble() * 24;
    drift = (r.nextDouble() - 0.5) * 28;
    size = 2.0 + r.nextDouble() * 1.8;
    alpha = isDark
        ? 0.14 + r.nextDouble() * 0.08
        : 0.16 + r.nextDouble() * 0.10;
    phase = index / _moteCount + r.nextDouble() * 0.08;
    color =
        (isDark ? _darkMoteColors : _lightMoteColors)[r.nextInt(
          isDark ? _darkMoteColors.length : _lightMoteColors.length,
        )];
  }

  final int index;
  late final double angle;
  late final double radius;
  late final double rise;
  late final double drift;
  late final double size;
  late final double alpha;
  late final double phase;
  late final Color color;

  static const _lightMoteColors = [
    T.amber,
    T.sand,
    Color(0xFFFFFFFF),
    T.terracotta,
  ];
  static const _darkMoteColors = [T.amber, T.sand];
}

const _moteCount = 5;

class _AmbientScenePainter extends CustomPainter {
  _AmbientScenePainter({required this.progress, required this.isDark})
    : blobs = const [
        // Upper two-thirds only, dim — the CTA zone stays clean.
        _DriftBlob(
          bx: 0.30,
          by: 0.22,
          ax: 0.07,
          ay: 0.05,
          px: 0.00,
          py: 0.13,
          r: 0.46,
        ),
        _DriftBlob(
          bx: 0.82,
          by: 0.40,
          ax: 0.06,
          ay: 0.07,
          px: 0.33,
          py: 0.47,
          r: 0.44,
        ),
        _DriftBlob(
          bx: 0.12,
          by: 0.64,
          ax: 0.05,
          ay: 0.05,
          px: 0.66,
          py: 0.71,
          r: 0.40,
        ),
      ],
      dots = List.generate(10, (i) => _AmbientDot(i, isDark), growable: false),
      super(repaint: progress) {
    _rebuildBlobPaints(isDark);
  }

  final Animation<double> progress;
  final bool isDark;
  final List<_DriftBlob> blobs;
  final List<_AmbientDot> dots;

  /// One Paint per blob, shader precomputed once. The shader is a unit circle
  /// at the origin — per frame the canvas is translated + scaled to place it,
  /// so gradients are never rebuilt and nothing is allocated in paint().
  /// In dark mode the same geometry renders in deeper tones at lower alpha.
  late final List<Paint> _blobPaints;

  /// Reused for every dot; only its colour is mutated per dot.
  final Paint _dotPaint = Paint();

  void _rebuildBlobPaints(bool dark) {
    final wash = SplashAmbient.blobWash(dark);
    _blobPaints = [
      for (var i = 0; i < blobs.length; i++)
        Paint()
          ..shader = RadialGradient(
            colors: [
              wash[i].color.withValues(alpha: wash[i].alpha),
              wash[i].color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final w = size.width;
    final h = size.height;
    final m = math.min(w, h);
    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final cx = w * SplashAmbient.loopOffset(b.bx, b.ax, b.px, t);
      final cy = h * SplashAmbient.loopOffset(b.by, b.ay, b.py, t);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(b.r * m);
      canvas.drawCircle(Offset.zero, 1, _blobPaints[i]);
      canvas.restore();
    }
    for (final d in dots) {
      final p = SplashAmbient.loopPhase(d.speed, d.phase, t);
      final envelope = math.sin(math.pi * p);
      if (envelope <= 0.01) continue;
      final x = w * SplashAmbient.loopOffset(d.x, d.sway, d.swayPhase, t);
      final y = h * (1.0 - 1.06 * p);
      canvas.drawCircle(
        Offset(x, y),
        d.radius,
        _dotPaint..color = d.color.withValues(alpha: d.alpha * envelope),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientScenePainter old) =>
      old.isDark != isDark || old.progress != progress;
}

class _BadgeMotesPainter extends CustomPainter {
  _BadgeMotesPainter({required this.progress, required this.isDark})
    : motes = List.generate(
        _moteCount,
        (i) => _BadgeMote(i, isDark),
        growable: false,
      ),
      super(repaint: progress);

  final Animation<double> progress;
  final bool isDark;
  final List<_BadgeMote> motes;

  final Paint _dotPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    // Square box, badge optically centred.
    final c = size.width / 2;
    for (final m in motes) {
      final p = SplashAmbient.loopPhase(1.0, m.phase, t);
      final envelope = math.sin(math.pi * p);
      if (envelope <= 0.01) continue;
      final x = c + math.cos(m.angle) * m.radius + m.drift * p;
      final y = c + math.sin(m.angle) * m.radius - m.rise * p;
      canvas.drawCircle(
        Offset(x, y),
        m.size,
        _dotPaint..color = m.color.withValues(alpha: m.alpha * envelope),
      );
    }
  }

  @override
  bool shouldRepaint(_BadgeMotesPainter old) =>
      old.isDark != isDark || old.progress != progress;
}
