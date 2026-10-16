import 'package:flutter/cupertino.dart';

import '../../app.dart' show LargeTitleBar;
import '../../design/theme.dart';

/// QUEUE — the triaged work queue (Task 3 builds the real screen).
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: const CustomScrollView(slivers: [LargeTitleBar(title: 'Queue')]),
    );
  }
}
