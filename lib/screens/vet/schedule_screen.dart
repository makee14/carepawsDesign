import 'package:flutter/cupertino.dart';

import '../../app.dart' show LargeTitleBar;
import '../../design/theme.dart';

/// SCHEDULE — day view of appointments (Task 4 builds the real screen).
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: const CustomScrollView(
        slivers: [LargeTitleBar(title: 'Schedule')],
      ),
    );
  }
}
