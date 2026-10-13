import 'package:flutter/cupertino.dart';

import '../design/tokens.dart';

/// Right-aligned header action row.
///
/// Cupertino navigation bars clamp their trailing slot to 44pt, which is below
/// the 48pt HIG minimum touch target, so icon-only actions live in the page
/// content instead — where they keep the full 48x48 hit area.
class NavActions extends StatelessWidget {
  const NavActions({super.key, required this.actions, this.padding});

  final List<Widget> actions;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: T.tap,
      child: Padding(
        padding: padding ?? const EdgeInsets.only(right: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}
