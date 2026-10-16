import 'package:flutter/cupertino.dart';

import '../../app.dart' show LargeTitleBar;
import '../../design/theme.dart';

/// CHATS — the full clinic inbox across all customers (Task 5 builds it).
class VetChatsScreen extends StatelessWidget {
  const VetChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: const CustomScrollView(slivers: [LargeTitleBar(title: 'Chats')]),
    );
  }
}
