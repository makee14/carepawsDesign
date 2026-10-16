import 'package:carepaws/design/theme.dart';
import 'package:carepaws/flavor.dart';
import 'package:carepaws/screens/vet/queue_screen.dart';
import 'package:carepaws/screens/vet/schedule_screen.dart';
import 'package:carepaws/screens/vet/vet_chats_screen.dart';
import 'package:carepaws/screens/vet/vet_more_screen.dart';
import 'package:carepaws/screens/vet/vet_pets_screen.dart';
import 'package:carepaws/screens/vet/vet_shell.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task 1 (vet portal): flavor flag + vet shell skeleton.
///
/// The customer build must never import lib/screens/vet/ — that is verified
/// by grep (see the task), not here. These tests pin the Dart side: the
/// compile-time flavor flag and the five-tab vet shell.
void main() {
  test('kVetFlavor defaults to the customer flavor', () {
    expect(appFlavor, 'customer');
    expect(kVetFlavor, isFalse);
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        store: AppStore(),
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const VetShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tabLabel(String label) => find.descendant(
    of: find.byType(FloatingTabBar),
    matching: find.text(label),
  );

  testWidgets('vet shell shows all five tab labels, no overflow', (
    tester,
  ) async {
    await pumpShell(tester);
    for (final label in ['Queue', 'Schedule', 'Chats', 'Pets', 'More']) {
      expect(tabLabel(label), findsOneWidget, reason: 'tab $label');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting each tab shows its screen', (tester) async {
    await pumpShell(tester);
    final tabs = [
      ('Queue', QueueScreen),
      ('Schedule', ScheduleScreen),
      ('Chats', VetChatsScreen),
      ('Pets', VetPetsScreen),
      ('More', VetMoreScreen),
    ];
    for (final (label, type) in tabs) {
      await tester.tap(tabLabel(label));
      await tester.pumpAndSettle();
      // IndexedStack keeps all five screens in the tree; only the selected
      // one is onstage (finders skip offstage by default).
      expect(find.byType(type), findsOneWidget, reason: 'screen $label');
      // The screen's large title is visible onstage.
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
    expect(tester.takeException(), isNull);
  });
}
