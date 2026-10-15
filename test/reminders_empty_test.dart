import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/reminders_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Reminders empty state (S12, gap #7): with zero pets and zero upcoming
/// appointments the Upcoming section renders the shared EmptyState with a
/// CTA to add a reminder — and it must not crash on the pet-derived lists.
Future<AppStore> pumpReminders(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(now: DateTime(2026, 10, 13, 15, 6));
  store.pets = [];
  store.appointments = [];
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const RemindersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('empty upcoming renders EmptyState with an add-reminder CTA', (
    tester,
  ) async {
    await pumpReminders(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
  });
}
