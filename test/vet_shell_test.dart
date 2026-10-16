import 'package:carepaws/design/theme.dart';
import 'package:carepaws/flavor.dart';
import 'package:carepaws/screens/vet/comms_screen.dart';
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

  group('tab-bar depth hiding (Fix 3)', () {
    // The More tab's "AI comms composer" row pushes CommsScreen with no
    // seeding needed.
    Future<void> pushComms(WidgetTester tester) async {
      await pumpShell(tester);
      await tester.tap(tabLabel('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI comms composer'));
      await tester.pumpAndSettle();
      expect(find.byType(CommsScreen), findsOneWidget);
    }

    Finder barOpacity() => find
        .ancestor(
          of: find.byType(FloatingTabBar),
          matching: find.byType(AnimatedOpacity),
        )
        .first;

    Finder barPointer() => find
        .ancestor(
          of: find.byType(FloatingTabBar),
          matching: find.byType(IgnorePointer),
        )
        .first;

    testWidgets('pushing a detail screen hides the floating tab bar', (
      tester,
    ) async {
      await pushComms(tester);
      // Same mechanism as the customer RootShell: fade out and stop
      // hit-testing, so the bar never sits over the pushed screen's own
      // bottom furniture or swallows its taps.
      expect(tester.widget<AnimatedOpacity>(barOpacity()).opacity, 0.0);
      expect(tester.widget<IgnorePointer>(barPointer()).ignoring, isTrue);
      expect(find.byType(FloatingTabBar).hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('popping the detail screen brings the tab bar back', (
      tester,
    ) async {
      await pushComms(tester);
      expect(tester.widget<AnimatedOpacity>(barOpacity()).opacity, 0.0);
      Navigator.of(tester.element(find.byType(CommsScreen))).pop();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(barOpacity()).opacity, 1.0);
      expect(tester.widget<IgnorePointer>(barPointer()).ignoring, isFalse);
      expect(find.byType(FloatingTabBar).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each tab keeps its own navigation stack', (tester) async {
      await pushComms(tester);
      // Pop back to the More root, switch away and back: the More tab is
      // back at its root and the other tabs were never disturbed — the
      // push stayed inside its tab's Navigator.
      Navigator.of(tester.element(find.byType(CommsScreen))).pop();
      await tester.pumpAndSettle();
      await tester.tap(tabLabel('Queue'));
      await tester.pumpAndSettle();
      expect(find.byType(QueueScreen), findsOneWidget);
      await tester.tap(tabLabel('More'));
      await tester.pumpAndSettle();
      expect(find.byType(VetMoreScreen), findsOneWidget);
      expect(find.byType(CommsScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
