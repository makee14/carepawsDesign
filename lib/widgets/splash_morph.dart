import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/icons.dart';

/// The launch morph: the embrace assembles — the orange disc lands first,
/// then the cream emblem (dog + cat + heart) fades in, the eyes pop, and the
/// whole mark settles with a gentle heartbeat pulse — then the splash routes on.
///
/// Driven by ONE [AnimationController] owned by the splash screen, with eased
/// sub-intervals and zero timers — completion is observed through a status
/// listener, so the timeline is pumpAndSettle-safe and teardown-clean.
/// Under reduced motion this widget is not used at all: the splash renders
/// the static final emblem instead.
///
/// Keyframes — fractions of the 2000ms timeline:
///   0.00–0.30  disc scales 0.7→1.0 and fades in        (easeOutCubic)
///   0.25–0.60  emblem fades in, scale 0.92→1.0         (easeOutCubic)
///   0.55–0.75  eyes pop in, spring overshoot (1.15 peak)
///   0.75–1.00  heartbeat — scale 1.0→1.03→1.0          (easeInOutSine)
class SplashMorph extends AnimatedWidget {
  const SplashMorph({
    super.key,
    required Animation<double> progress,
    this.size = 160,
  }) : super(listenable: progress);

  /// Emblem size in pt.
  final double size;

  Animation<double> get _t => listenable as Animation<double>;

  /// Clamp the controller value into the [a, b] sub-interval.
  static double _slice(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = _t.value;
    final discT = Curves.easeOutCubic.transform(_slice(t, 0.00, 0.30));
    final emblemT = Curves.easeOutCubic.transform(_slice(t, 0.25, 0.60));
    const pop = _Pop();
    final eyesT = pop.transform(_slice(t, 0.55, 0.75));
    // Heartbeat: one gentle pulse over the final quarter.
    final beatT = _slice(t, 0.75, 1.00);
    final beat = 1.0 + 0.03 * (0.5 - 0.5 * math.cos(3.14159 * beatT) * (1 - beatT));
    return SizedBox.square(
      dimension: size,
      child: Transform.scale(
        scale: beat,
        alignment: Alignment.center,
        child: Stack(
          children: [
            Opacity(
              opacity: discT,
              child: Transform.scale(
                scale: 0.7 + 0.3 * discT,
                alignment: Alignment.center,
                child: _layer(Ic.splashLayerCircle),
              ),
            ),
            Opacity(
              opacity: emblemT,
              child: Transform.scale(
                scale: 0.92 + 0.08 * emblemT,
                alignment: Alignment.center,
                child: _layer(Ic.splashLayerEmblem),
              ),
            ),
            Opacity(
              opacity: eyesT.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: eyesT.clamp(0.0, 1.2),
                alignment: Alignment.center,
                child: _layer(Ic.splashLayerEyes),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layer(String svg) =>
      SvgPicture.string(svg, width: size, height: size);
}

/// easeOutBack tuned for a 1.15 peak — the eye pop.
class _Pop extends Curve {
  const _Pop();

  @override
  double transformInternal(double t) {
    const c1 = 2.1643; // peak lands at exactly 1.15
    const c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }
}
