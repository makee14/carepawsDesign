import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/icons.dart';

/// The launch morph: the four logo groups (circle, dog, cat, heart) assemble
/// into the final emblem, then the splash routes on.
///
/// Driven by ONE [AnimationController] owned by the splash screen, with eased
/// sub-intervals and zero timers — completion is observed through a status
/// listener, so the timeline is pumpAndSettle-safe and teardown-clean.
/// Under reduced motion this widget is not used at all: the splash renders
/// the static final emblem instead.
///
/// Keyframes (design contracts, Stream E) — fractions of the 2000ms timeline:
///   0.00–0.15  circle scales 0.6→1.0 and fades in      (easeOutCubic)
///   0.125–0.45 dog/cat slide in from ∓24pt and fade in (easeInOutCubic)
///   0.40–0.65  heart pops 0→1                          (spring, overshoot 1.15)
///   0.65–1.00  settle — every interval is already at 1, so the hold is free.
class SplashMorph extends AnimatedWidget {
  const SplashMorph({
    super.key,
    required Animation<double> progress,
    this.size = 160,
  }) : super(listenable: progress);

  /// Emblem size in pt; the ±24pt slides scale with it.
  final double size;

  Animation<double> get _t => listenable as Animation<double>;

  /// Clamp the controller value into the [a, b] sub-interval.
  static double _slice(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = _t.value;
    final circleT = Curves.easeOutCubic.transform(_slice(t, 0.00, 0.15));
    final petsT = Curves.easeInOutCubic.transform(_slice(t, 0.125, 0.45));
    final heartT = const _HeartPop().transform(_slice(t, 0.40, 0.65));
    final slide = 24 * size / 160;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Opacity(
            opacity: circleT,
            child: Transform.scale(
              scale: 0.6 + 0.4 * circleT,
              alignment: Alignment.center,
              child: _layer(Ic.splashLayerCircle),
            ),
          ),
          Opacity(
            opacity: petsT,
            child: Transform.translate(
              offset: Offset(-slide * (1 - petsT), 0),
              child: _layer(Ic.splashLayerDog),
            ),
          ),
          Opacity(
            opacity: petsT,
            child: Transform.translate(
              offset: Offset(slide * (1 - petsT), 0),
              child: _layer(Ic.splashLayerCat),
            ),
          ),
          Transform.scale(
            scale: heartT.clamp(0.0, 1.2),
            alignment: Alignment.center,
            child: _layer(Ic.splashLayerHeart),
          ),
        ],
      ),
    );
  }

  Widget _layer(String svg) =>
      SvgPicture.string(svg, width: size, height: size);
}

/// easeOutBack tuned for a 1.15 peak — the heart pop.
class _HeartPop extends Curve {
  const _HeartPop();

  @override
  double transformInternal(double t) {
    const c1 = 2.1643; // peak lands at exactly 1.15
    const c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }
}
