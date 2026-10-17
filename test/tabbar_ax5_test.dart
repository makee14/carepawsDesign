import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/common.dart';

/// Leftover: FloatingTabBar slot overflow at textScale 3.2 (was 4px).
void main() {
  testWidgets('tab bar slots do not overflow at AX5 (3.2)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FloatingTabBar(
                index: 0,
                onSelect: (_) {},
                tabs: const [
                  (label: 'Home', icon: Ic.home),
                  (label: 'Chats', icon: Ic.chat),
                  (label: 'Appointments', icon: Ic.calendar),
                  (label: 'Shop', icon: Ic.bag),
                  (label: 'Profile', icon: Ic.person),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab labels shrink instead of truncating at AX5 (3.2)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FloatingTabBar(
                index: 0,
                onSelect: (_) {},
                tabs: const [
                  (label: 'Home', icon: Ic.home),
                  (label: 'Chats', icon: Ic.chat),
                  (label: 'Appointments', icon: Ic.calendar),
                  (label: 'Shop', icon: Ic.bag),
                  (label: 'Profile', icon: Ic.person),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // didExceedMaxLines is true when the label hit the ellipsis (truncated).
    for (final label in const [
      'Home',
      'Chats',
      'Appointments',
      'Shop',
      'Profile',
    ]) {
      final para = tester.renderObject<RenderParagraph>(find.text(label));
      expect(para.didExceedMaxLines, isFalse, reason: '$label truncates');
    }
    expect(tester.takeException(), isNull);
  });
}
