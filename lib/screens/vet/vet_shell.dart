import 'package:flutter/cupertino.dart';

import '../../design/icons.dart';
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
/// top of the same design tokens. Only this shell and the screens under
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

  void _select(int i) => setState(() => _index = i);

  static const _bodies = [
    QueueScreen(),
    ScheduleScreen(),
    VetChatsScreen(),
    VetPetsScreen(),
    VetMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Reserve room for the floating bar so a screen's last row stays
    // reachable; MediaQuery padding is left alone so SafeArea keeps behaving.
    final clearance = FloatingTabBar.clearanceFor(context);
    return RootBackGuard(
      child: CupertinoPageScaffold(
        backgroundColor: context.p.background,
        child: Stack(
          children: [
            Positioned.fill(
              child: TabBarClearance(
                height: clearance,
                child: IndexedStack(index: _index, children: _bodies),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingTabBar(
                index: _index,
                onSelect: _select,
                tabs: VetShell.tabs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
