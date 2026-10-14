import 'package:flutter/cupertino.dart';

import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Animated illustrations for the five onboarding pages.
///
/// Every scene runs on ONE [AnimationController] that plays exactly once and
/// then stops — nothing here loops, uses a [Timer], or schedules a delayed
/// future, so `pumpAndSettle()` always terminates and widget-test teardown
/// never sees a pending timer. Sequencing is done with eased sub-intervals
/// ([_seg]) of the single timeline, not with staggered controllers.
///
/// Reduced motion: the timeline is parked at 1.0 before the first frame, so
/// every element renders its final static state immediately. The page
/// indicator in the parent screen still works — just without animation.
///
/// Each scene is authored on a fixed 280x200 logical canvas. The parent wraps
/// it in a [FittedBox], so large Dynamic Type sizes scale the whole drawing
/// instead of overflowing it. All copy inside a scene uses the fixed type ramp
/// at its design size — illustration copy never reflows.
const introCanvas = Size(280, 200);

/// Eased 0→1 progress of a 0→1 timeline over [begin]→[end], clamped.
double _seg(double t, double begin, double end) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return Motion.enter.transform((t - begin) / (end - begin));
}

/// Base state for an intro scene: arms the single one-shot timeline on first
/// build. Subclasses read [progress] inside an [AnimatedBuilder].
abstract class _IntroState<W extends StatefulWidget> extends State<W>
    with SingleTickerProviderStateMixin {
  late final AnimationController timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _armed = false;

  /// 0→1 progress of the entrance timeline.
  double get progress => timeline.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    if (reduceMotionOf(context)) {
      // Stillness requested: park on the final frame before anything paints.
      timeline.value = 1;
    } else {
      timeline.forward();
    }
  }

  @override
  void dispose() {
    timeline.dispose();
    super.dispose();
  }
}

/// One-shot pop: fades in while scaling from [from] to 1. Settles exactly.
class _Pop extends StatelessWidget {
  const _Pop({
    super.key,
    required this.t,
    required this.child,
    this.from = 0.85,
  });

  /// Eased 0→1 segment progress.
  final double t;
  final Widget child;

  /// Starting scale.
  final double from;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: t,
    child: Transform.scale(scale: from + (1 - from) * t, child: child),
  );
}

/// One-shot rise: fades in while settling up [distance] points into place.
/// Used once (the booking time chip) where the arrival itself carries meaning
/// — the chip docking under the selected date.
class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: t,
    child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
  );
}

/// The one shadow language, matching SoftCard: flat on dark.
List<BoxShadow> _cardShadow(bool isDark) => isDark
    ? const []
    : const [
        BoxShadow(
          color: T.shadowLight,
          blurRadius: T.shadowBlur,
          offset: Offset(0, T.shadowDy),
        ),
      ];

BoxDecoration _card(AppPalette p, {double radius = T.rCard}) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: _cardShadow(p.isDark),
);

// ---------------------------------------------------------------------------
// 1. Welcome — the paw mark draws itself in, then settles with a soft pop.
// ---------------------------------------------------------------------------

/// Welcome illustration: a stroke-drawn paw on an amber disc.
class PawIntro extends StatefulWidget {
  const PawIntro({super.key});
  @override
  State<PawIntro> createState() => _PawIntroState();
}

class _PawIntroState extends _IntroState<PawIntro> {
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final t = progress;
        return Opacity(
          opacity: _seg(t, 0, 0.15),
          child: Transform.scale(
            scale: 0.96 + 0.04 * _seg(t, 0, 0.35),
            child: Stack(
              children: [
                CustomPaint(
                  size: introCanvas,
                  painter: _PawPainter(
                    progress: t,
                    backdrop: T.amber.withValues(alpha: p.isDark ? 0.16 : 0.22),
                    pad: T.terracotta,
                    toes: T.orange,
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    // Keyed so tests can assert the final state lands on the
                    // first frame under reduced motion.
                    key: const ValueKey('paw-dots'),
                    opacity: _seg(t, 0.8, 1.0),
                    child: const Stack(
                      children: [
                        Positioned(
                          left: 52,
                          top: 128,
                          child: _Dot(color: T.amber),
                        ),
                        Positioned(
                          left: 222,
                          top: 122,
                          child: _Dot(color: T.amber),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _PawPainter extends CustomPainter {
  _PawPainter({
    required this.progress,
    required this.backdrop,
    required this.pad,
    required this.toes,
  });

  final double progress;
  final Color backdrop;
  final Color pad;
  final Color toes;

  static const _toeCenters = [
    Offset(96, 70),
    Offset(124, 52),
    Offset(156, 52),
    Offset(184, 70),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(const Offset(140, 96), 76, Paint()..color = backdrop);
    _stroke(
      canvas,
      Path()..addOval(
        Rect.fromCenter(center: const Offset(140, 126), width: 68, height: 54),
      ),
      _seg(progress, 0.02, 0.45),
      pad,
    );
    for (var i = 0; i < _toeCenters.length; i++) {
      _stroke(
        canvas,
        Path()..addOval(Rect.fromCircle(center: _toeCenters[i], radius: 12.5)),
        _seg(progress, 0.28 + 0.1 * i, 0.58 + 0.1 * i),
        toes,
      );
    }
  }

  void _stroke(Canvas canvas, Path src, double f, Color color) {
    if (f <= 0) return;
    final Path drawn;
    if (f >= 1) {
      drawn = src;
    } else {
      drawn = Path();
      for (final m in src.computeMetrics()) {
        drawn.addPath(m.extractPath(0, m.length * f), Offset.zero);
      }
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PawPainter old) =>
      old.progress != progress ||
      old.backdrop != backdrop ||
      old.pad != pad ||
      old.toes != toes;
}

// ---------------------------------------------------------------------------
// 2. AI check — the orb wakes with expanding rings; a triage-style question
//    pops in on a chat bubble.
// ---------------------------------------------------------------------------

/// AI health-check illustration: pulsing orb + question bubble.
class AiOrbIntro extends StatefulWidget {
  const AiOrbIntro({super.key});
  @override
  State<AiOrbIntro> createState() => _AiOrbIntroState();
}

class _AiOrbIntroState extends _IntroState<AiOrbIntro> {
  static const _orbCenter = Offset(140, 78);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final t = progress;
        return Stack(
          children: [
            CustomPaint(
              size: introCanvas,
              painter: _RingsPainter(progress: t, color: T.terracotta),
            ),
            Positioned(
              left: _orbCenter.dx - 34,
              top: _orbCenter.dy - 34,
              child: Opacity(
                opacity: _seg(t, 0, 0.3),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: T.terracotta,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Ic.svg(
                      Ic.sparkle,
                      color: T.card,
                      size: 30,
                      stroke: 2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 84,
              top: 116,
              width: 180,
              child: _Pop(
                t: _seg(t, 0.55, 0.8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 26,
                      top: -6,
                      child: Transform.rotate(
                        angle: 0.785,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: _card(p, radius: 16),
                      child: Text(
                        'Biscuit\u2019s limping \u2014 is this urgent?',
                        style: Type.footnote(p),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Three rings expand and fade exactly once; a faint rest ring stays behind.
class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  static const _center = Offset(140, 78);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final f = _seg(progress, 0.06 + 0.16 * i, 0.5 + 0.16 * i);
      if (f <= 0) continue;
      canvas.drawCircle(
        _center,
        40 + 62 * f,
        Paint()
          ..color = color.withValues(alpha: 0.5 * (1 - f))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    // Rest state: one faint ring, always there once the pulse has passed.
    final rest = _seg(progress, 0.5, 0.7);
    if (rest > 0) {
      canvas.drawCircle(
        _center,
        104,
        Paint()
          ..color = color.withValues(alpha: 0.14 * rest)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// 3. Booking — a mini calendar: a date is picked, its time chip docks below.
// ---------------------------------------------------------------------------

/// Booking illustration: mini month card, date 14 selected, time chip arrives.
class BookIntro extends StatefulWidget {
  const BookIntro({super.key});
  @override
  State<BookIntro> createState() => _BookIntroState();
}

class _BookIntroState extends _IntroState<BookIntro> {
  /// October 2026, Sunday-first. The 14th is a Wednesday (the seeded "today").
  static const _weeks = [
    [0, 0, 0, 0, 1, 2, 3],
    [4, 5, 6, 7, 8, 9, 10],
    [11, 12, 13, 14, 15, 16, 17],
    [18, 19, 20, 21, 22, 23, 24],
    [25, 26, 27, 28, 29, 30, 31],
  ];
  static const _selected = 14;
  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _cellW = 31.4;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final t = progress;
        return Stack(
          children: [
            Positioned(
              left: 20,
              top: 4,
              width: 240,
              height: 150,
              child: Opacity(
                opacity: _seg(t, 0, 0.25),
                child: Container(
                  decoration: _card(p),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('October', style: Type.headline(p)),
                          const Spacer(),
                          Text(
                            '2026',
                            style: Type.caption(p)
                                .copyWith(color: p.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final d in _weekdays)
                            SizedBox(
                              width: _cellW,
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: Type.caption(p)
                                    .copyWith(color: p.textSecondary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      for (final week in _weeks)
                        Row(
                          children: [
                            for (final day in week)
                              SizedBox(
                                width: _cellW,
                                height: 16,
                                child: Center(
                                  child: day == 0
                                      ? const SizedBox.shrink()
                                      : day == _selected
                                      ? _Pop(
                                          key: const ValueKey('book-date'),
                                          t: _seg(t, 0.35, 0.55),
                                          from: 0.6,
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              color: T.terracotta,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$day',
                                                style: Type.caption(p).copyWith(
                                                  color: T.card,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text('$day', style: Type.caption(p)),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 160,
              left: 0,
              right: 0,
              child: Center(
                child: _Rise(
                  t: _seg(t, 0.6, 0.85),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: const BoxDecoration(
                      // Darkened terracotta: 5.84:1 with white text.
                      color: T.terracottaDeep,
                      borderRadius: BorderRadius.all(Radius.circular(T.rPill)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Ic.svg(Ic.clock, color: T.card, size: 13, stroke: 2.2),
                        const SizedBox(width: 6),
                        Text(
                          'Wed \u00b7 10:30 AM',
                          style: Type.caption(p).copyWith(
                            color: T.card,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Chat — owner bubble pops in, then typing dots resolve into the clinic's
//    reply. One pass: the dots never loop.
// ---------------------------------------------------------------------------

/// Chat illustration: two bubbles in sequence, dots resolve into text.
class ChatIntro extends StatefulWidget {
  const ChatIntro({super.key});
  @override
  State<ChatIntro> createState() => _ChatIntroState();
}

class _ChatIntroState extends _IntroState<ChatIntro> {
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final t = progress;
        final reveal = _seg(t, 0.68, 0.88);
        return Stack(
          children: [
            Positioned(
              right: 10,
              top: 16,
              child: _Pop(
                t: _seg(t, 0.1, 0.35),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: const BoxDecoration(
                      color: T.terracotta,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Text(
                      'Can Biscuit come in today?',
                      style: Type.footnote(p).copyWith(color: T.card),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 88,
              child: Opacity(
                opacity: _seg(t, 0.38, 0.5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: _card(p, radius: 18),
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: 1 - reveal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 5),
                                Opacity(
                                  opacity: _seg(
                                    t,
                                    0.42 + 0.09 * i,
                                    0.6 + 0.09 * i,
                                  ),
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: T.taupe,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Opacity(
                          key: const ValueKey('chat-text'),
                          opacity: reveal,
                          child: Text(
                            '2:30 PM works \u2014 see you then!',
                            style: Type.footnote(p),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Shop — a product card fades in; the cart badge pops to 1.
// ---------------------------------------------------------------------------

/// Shop illustration: product card arrives, badge pops on the cart.
class ShopIntro extends StatefulWidget {
  const ShopIntro({super.key});
  @override
  State<ShopIntro> createState() => _ShopIntroState();
}

class _ShopIntroState extends _IntroState<ShopIntro> {
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: timeline,
      builder: (context, _) {
        final t = progress;
        return Stack(
          children: [
            Positioned(
              left: 14,
              top: 48,
              width: 232,
              child: Opacity(
                opacity: _seg(t, 0, 0.3),
                child: Container(
                  decoration: _card(p),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: T.amber.withValues(
                            alpha: p.isDark ? 0.2 : 0.28,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Ic.svg(
                            Ic.bag,
                            color: T.terracotta,
                            size: 26,
                            stroke: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Salmon kibble \u00b7 2 kg',
                              style: Type.footnoteEmph(p),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\u20b11,250',
                              style: Type.footnote(p).copyWith(
                                color: p.accentText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 16,
              child: _Pop(
                t: _seg(t, 0.4, 0.6),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                    boxShadow: _cardShadow(p.isDark),
                  ),
                  child: Center(
                    child: Ic.svg(
                      Ic.bag,
                      color: T.terracotta,
                      size: 26,
                      stroke: 1.8,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 10,
              child: _Pop(
                key: const ValueKey('shop-badge'),
                t: _seg(t, 0.62, 0.85),
                from: 0.2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: T.terracottaDeep,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: Type.caption(p)
                          .copyWith(color: T.card, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
