import 'package:flutter/cupertino.dart';

import '../../app.dart' show LargeTitleBar;
import '../../design/theme.dart';

/// MORE — AI comms composer, inventory, clinic + staff settings (Task 7).
class VetMoreScreen extends StatelessWidget {
  const VetMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: const CustomScrollView(slivers: [LargeTitleBar(title: 'More')]),
    );
  }
}
