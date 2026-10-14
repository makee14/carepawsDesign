import 'package:flutter/cupertino.dart';

import '../state/app_store.dart';

/// ---------------------------------------------------------------------------
/// The app's whole motion vocabulary: three durations, one curve, one stagger
/// step. Keeping it in one place is what stops motion drifting screen to screen.
///
/// Three rules, deliberately simple:
///   1. Every animation here is one-shot and finite. Nothing loops — that keeps
///      `pumpAndSettle()` in the golden tests from ever timing out.
///   2. Every animation checks [reduceMotionOf] and renders the final state
///      immediately when stillness is requested.
///   3. Nothing translates. HIG ▸ Motion: "Consider using fades when you need to
///      relocate an object... If such movement doesn't communicate anything
///      useful to people, fade the object out before moving it and fade it back
///      in after it is in the new location." A card arriving 10pt below its
///      final spot communicates nothing, so the app now only fades.
///
///      One deliberate exception: the splash welcome text uses [FadeIn] with
///      a small [FadeIn.rise] (Mark's explicit request 2026-10-14 — Apple-style
///      entrances pair the fade with a slight upward rise). It stays one-shot,
///      subtle (≤12pt), eased with the house curve, and parks at the final
///      state under reduced motion like everything else.
/// ---------------------------------------------------------------------------
class Motion {
  const Motion._();

  /// Press feedback, chips.
  static const fast = Duration(milliseconds: 150);

  /// Default for an element entering the screen.
  static const base = Duration(milliseconds: 240);

  /// Splash entrance and larger groups.
  static const slow = Duration(milliseconds: 420);

  /// The house curve. easeOutCubic was reading as floaty — it decelerates too
  /// gradually — so this settles sooner without the snap of easeOutExpo.
  static const enter = Curves.easeOutQuart;

  /// Delay added per item in a staggered group, plus a ceiling so a long list
  /// finishes arriving quickly instead of crawling. Kept small on purpose: a
  /// long stagger makes a screen feel like it is loading rather than arriving.
  static const step = Duration(milliseconds: 38);
  static const maxStagger = Duration(milliseconds: 170);

  /// Stagger delay for the item at [index], capped.
  static Duration stagger(int index) {
    if (index <= 0) return Duration.zero;
    final d = step * index;
    return d > maxStagger ? maxStagger : d;
  }
}

/// True when stillness is requested — either by the OS
/// (`MediaQuery.disableAnimations`, which mirrors the Reduce Motion switch in
/// iOS Settings ▸ Accessibility) or by the in-app toggle in Settings ▸ Account.
///
/// The in-app override used to be written to the store and never read back,
/// which is why flipping it did nothing. Both sources are honoured now, and
/// either one alone is enough to switch animations off.
bool reduceMotionOf(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
  return AppScope.maybeOf(context)?.reduceMotionOverride ?? false;
}

/// One-shot fade, optionally with a slight upward rise or a gentle scale
/// settle.
///
/// Wrap a card, a section or a list row and pass its [index] to stagger a group
/// in left to right, top to bottom. With motion reduced it paints the final
/// state on the first frame — no fade at all.
///
/// [rise] is 0 by default: a pure opacity change, nothing is translated or
/// scaled, so an element never travels across the screen to arrive. A nonzero
/// rise starts the child [rise]pt below its final spot and eases it up while
/// fading in — the splash welcome text uses this (see the motion-vocabulary
/// header for why it is the one exception).
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = Motion.base,
    this.rise = 0,
    this.settleFrom = 1.0,
  });

  final Widget child;

  /// Position in a staggered group. Drives the delay only.
  final int index;

  final Duration duration;

  /// Upward travel in logical pixels during the entrance. 0 = opacity only.
  final double rise;

  /// Gentle scale settle paired with the fade: the child starts at
  /// [settleFrom]× and eases to 1× on the house curve — a soft settle, never
  /// a spring. 1.0 (the default) keeps the pure-fade behaviour everywhere
  /// else.
  final double settleFrom;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Inherited data can only be read from here, not from initState.
    if (reduceMotionOf(context)) {
      _c.value = 1;
      return;
    }
    final delay = Motion.stagger(widget.index);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final eased = Motion.enter.transform(_c.value);
        Widget out = Opacity(opacity: eased, child: child);
        if (widget.rise != 0) {
          out = Transform.translate(
            offset: Offset(0, (1 - eased) * widget.rise),
            child: out,
          );
        }
        if (widget.settleFrom != 1.0) {
          final s = widget.settleFrom + (1.0 - widget.settleFrom) * eased;
          out = Transform.scale(scale: s, child: out);
        }
        return out;
      },
    );
  }
}
