import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/appointments_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HIG: the Upcoming/Past segmented control cells are tappable controls and
/// must be at least 44pt tall.
void main() {
  testWidgets('segmented control cells are at least 44pt tall', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(now: DateTime(2026, 10, 13, 15, 6));
    addTearDown(store.dispose);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const AppointmentsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Upcoming', 'Past']) {
      final cell = find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      );
      expect(cell, findsOneWidget, reason: 'segment cell "$label"');
      final size = tester.getSize(cell);
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'segment cell "$label" is ${size.height}pt tall',
      );
    }
  });
}
