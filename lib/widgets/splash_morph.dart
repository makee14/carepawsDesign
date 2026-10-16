import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/icons.dart';

/// The launch morph: the paw assembles — the pad lands first, then the four
/// toe beans pop in one by one — then the splash routes on.
///
/// Driven by ONE [AnimationController] owned by the splash screen, with eased
/// sub-intervals and zero timers — completion is observed through a status
/// listener, so the timeline is pumpAndSettle-safe and teardown-clean.
/// Under reduced motion this widget is not used at all: the splash renders
/// the static final emblem instead.
///
/// Keyframes — fractions of the 2000ms timeline:
///   0.00–0.25  pad scales 0.6→1.0 and fades in       (easeOutCubic)
///   0.20–0.575 toes pop in staggered, spring overshoot (1.15 peak)
///     toe1: 0.200–0.350, toe2: 0.275–0.425,
///     toe3: 0.350–0.500, toe4: 0.425–0.575
///   0.60–1.00  settle — every interval is already at 1, so the hold is free.
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
    final padT = Curves.easeOutCubic.transform(_slice(t, 0.00, 0.25));
    const pop = _Pop();
    final toeT = [
      pop.transform(_slice(t, 0.200, 0.350)),
      pop.transform(_slice(t, 0.275, 0.425)),
      pop.transform(_slice(t, 0.350, 0.500)),
      pop.transform(_slice(t, 0.425, 0.575)),
    ];
    final toeLayers = [
      Ic.splashLayerToe1,
      Ic.splashLayerToe2,
      Ic.splashLayerToe3,
      Ic.splashLayerToe4,
    ];
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Opacity(
            opacity: padT,
            child: Transform.scale(
              scale: 0.6 + 0.4 * padT,
              alignment: Alignment.center,
              child: _layer(Ic.splashLayerPad),
            ),
          ),
          for (var i = 0; i < 4; i++)
            Opacity(
              opacity: toeT[i].clamp(0.0, 1.0),
              child: Transform.scale(
                scale: toeT[i].clamp(0.0, 1.2),
                alignment: Alignment.center,
                child: _layer(toeLayers[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _layer(String svg) =>
      SvgPicture.string(svg, width: size, height: size);
}

/// easeOutBack tuned for a 1.15 peak — the toe pop.
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
