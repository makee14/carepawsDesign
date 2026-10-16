import 'package:flutter/cupertino.dart';

import '../../app.dart' show LargeTitleBar;
import '../../design/theme.dart';

/// PETS — customer + pet search, full history, medical write (Task 6).
class VetPetsScreen extends StatelessWidget {
  const VetPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: const CustomScrollView(slivers: [LargeTitleBar(title: 'Pets')]),
    );
  }
}
