import 'package:flutter/cupertino.dart';

import '../../design/icons.dart';
import '../../design/motion.dart';
import '../../design/theme.dart';
import '../../widgets/back_guard.dart';
import '../../widgets/common.dart';
import 'queue_screen.dart';
import 'schedule_screen.dart';
import 'vet_chats_screen.dart';
import 'vet_more_screen.dart';
import 'vet_pets_screen.dart';

/// Vet portal shell: QUEUE · SCHEDULE · CHATS · PETS · MORE.
///
/// Mirrors the customer [RootShell] rhythm — the same floating pill tab bar
/// ([FloatingTabBar], shared, not copied), the same large-title screens — on
/// top of the same design tokens. Each tab owns a [CupertinoTabView]
/// Navigator, so a pushed detail screen stays inside its tab: switching tabs
/// with a detail open keeps the detail where it was, and the shared
/// [TabDepthObserver] hides the floating bar at depth — the same mechanism
/// the customer shell uses. Only this shell and the screens under
/// lib/screens/vet/ are vet-only; the customer build never imports them (the
/// vet entry point lib/main_vet.dart is the only file outside this folder
/// that references them), so the portal is tree-shaken out of the customer
/// APK/IPA.
class VetShell extends StatefulWidget {
  const VetShell({super.key});

  static const tabs = [
    (label: 'Queue', icon: Ic.clipboard),
    (label: 'Schedule', icon: Ic.calendar),
    (label: 'Chats', icon: Ic.chat),
    (label: 'Pets', icon: Ic.paw),
    (label: 'More', icon: Ic.settings),
  ];

  @override
  State<VetShell> createState() => _VetShellState();
}

class _VetShellState extends State<VetShell> {
  int _index = 0;

  /// How deep each tab's own Navigator is. Zero means the tab's own root.
  ///
  /// The floating bar is only shown on a root route: on a pushed screen it
  /// would sit over the screen's own bottom furniture (chat composer, sticky
  /// CTA) and swallow taps.
  final _depths = List<int>.filled(VetShell.tabs.length, 0);

  /// Created once. Handing CupertinoTabView fresh observers on every build
  /// would re-register them against each Navigator.
  final _observers = <NavigatorObserver>[];

  bool get _barVisible => _depths[_index] == 0;

  void _select(int i) => setState(() => _index = i);

  List<NavigatorObserver> _observersFor(int i) {
    if (_observers.isEmpty) {
      for (var t = 0; t < _bodies.length; t++) {
        _observers.add(TabDepthObserver(_onDepthChanged, _depths, t));
      }
    }
    return [_observers[i]];
  }

  /// Navigator observers fire while the Navigator is building, so the shell
  /// cannot be marked dirty straight away — that would be a setState during
  /// build. Defer to after the frame.
  void _onDepthChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  static const _bodies = [
    QueueScreen(),
    ScheduleScreen(),
    VetChatsScreen(),
    VetPetsScreen(),
    VetMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _barVisible;
    // Only reserve room while the bar is actually on screen, so pushed screens
    // get their full height back.
    final clearance = visible ? FloatingTabBar.clearanceFor(context) : 0.0;

    // RootBackGuard: the system back button at the tab roots (nothing left to
    // pop) asks "Exit CarePaws Vet?" instead of closing the app silently.
    // Pushed screens are unaffected — their tab's own Navigator pops first.
    return RootBackGuard(
      child: CupertinoPageScaffold(
        backgroundColor: context.p.background,
        child: Stack(
          children: [
            Positioned.fill(
              // Lists reserve room for the floating bar via [TabBarClearance].
              // MediaQuery padding is left alone so SafeArea keeps behaving.
              child: TabBarClearance(
                height: clearance,
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < _bodies.length; i++)
                      CupertinoTabView(
                        navigatorObservers: _observersFor(i),
                        builder: (_) => _bodies[i],
                      ),
                  ],
                ),
              ),
            ),
            // Fades rather than sliding. The bar is a large element sitting at
            // the edge of the field of view, and HIG ▸ Motion asks that
            // movement there be avoided: travelling a whole bar-width downward
            // communicates nothing the fade does not already say. Same object
            // leaving, no second motion competing with the page push behind it.
            //
            // IgnorePointer matters as much as the fade: an AnimatedOpacity at
            // zero is still hit-testable, so an invisible bar kept swallowing
            // taps meant for the pushed screen underneath it — chat composer,
            // sticky CTAs, Done/Cancel buttons. Hidden means untouchable.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: Motion.fast,
                  curve: Motion.enter,
                  child: FloatingTabBar(
                    index: _index,
                    onSelect: _select,
                    tabs: VetShell.tabs,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
