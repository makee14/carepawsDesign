import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// HIG: every tappable control is at least 44x44pt. FilterPill is a shared
/// control used in Shop, Add pet, Book flow and Pet profile — one fix here
/// covers all four.
void main() {
  group('FilterPill tap target', () {
    testWidgets('selected and unselected pills are at least 44pt tall', (
      tester,
    ) async {
      for (final selected in [false, true]) {
        await tester.pumpWidget(
          CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: Center(
              child: FilterPill(
                label: 'Food',
                selected: selected,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(find.byType(FilterPill));
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'FilterPill(selected=$selected) is ${size.height}pt tall',
        );
      }
    });

    testWidgets('pill tap fires through the full 44pt target', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: Center(
            child: FilterPill(
              label: 'Food',
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilterPill));
      expect(tapped, isTrue);
    });
  });
}
