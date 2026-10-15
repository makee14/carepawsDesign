import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/add_pet_screen.dart';
import 'package:carepaws/screens/appointments/book_flow.dart';
import 'package:carepaws/screens/chat_thread_screen.dart';
import 'package:carepaws/screens/edit_pet_screen.dart';
import 'package:carepaws/screens/profile/settings_screens.dart';
import 'package:carepaws/screens/triage_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Flow guards + back-button (Worker B): PopScope-backed discard confirms on
/// every flow screen. Android system back = [systemBack] below.
///
/// SharedPreferences.setMockInitialValues({}) is mandatory: any widget test
/// touching prefs (auth/ai stores) hangs forever on the fake-async clock
/// without it.
DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

class _Launcher extends StatelessWidget {
  const _Launcher({required this.screen});
  final Widget screen;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Launcher')),
    child: Center(
      child: CupertinoButton(
        onPressed: () => Navigator.of(context).push(appRoute(screen)),
        child: const Text('Open'),
      ),
    ),
  );
}

/// Pumps a launcher page, taps "Open", and leaves [screen] on a real route
/// stack — so system back, nav back and PopScope behave like the app.
Future<AppStore> pumpPushable(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final store = AppStore(now: fixedNow());
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: _Launcher(screen: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return store;
}

/// Simulates the Android system back button. The framework fires
/// PopScope.onPopInvokedWithResult fire-and-forget, so awaiting this is safe:
/// the dialog flow continues on its own afterwards.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// The nav-bar back chevron inside [DetailNavBar]. The "Back" semantics
/// label is ambiguous (StickyCta's back button shares it), so tap the
/// widget instead — DetailNavBar's only CupertinoButton is its back button.
Finder navBack() => find.descendant(
  of: find.byType(DetailNavBar),
  matching: find.byType(CupertinoButton),
);

/// Taps a time-slot pill: the slot Wrap can extend below the fold (and under
/// the floating StickyCta), so scroll it into view first.
Future<void> tapSlot(WidgetTester tester, String label) async {
  final finder = find.bySemanticsLabel(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void expectOnLauncher(WidgetTester tester) {
  expect(find.text('Open'), findsOneWidget);
}

void main() {
  group('confirmDiscardIfDirty helper', () {
    testWidgets('clean input returns true with no dialog', (tester) async {
      bool? result;
      await pumpPushable(
        tester,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () async {
                  result = await confirmDiscardIfDirty(context, isDirty: false);
                },
                child: const Text('Ask'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('dirty: Keep editing cancels, Discard confirms', (
      tester,
    ) async {
      bool? result;
      await pumpPushable(
        tester,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () async {
                  result = await confirmDiscardIfDirty(context, isDirty: true);
                },
                child: const Text('Ask'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Ask'), findsOneWidget, reason: 'page must stay');

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('AddPet', () {
    testWidgets('clean form: system back pops silently', (tester) async {
      await pumpPushable(tester, const AddPetScreen());
      await systemBack(tester);
      expect(find.text('Discard this pet?'), findsNothing);
      expectOnLauncher(tester);
    });

    testWidgets('dirty form: system back asks; cancel stays, discard pops', (
      tester,
    ) async {
      await pumpPushable(tester, const AddPetScreen());
      await tester.enterText(find.byType(CupertinoTextField).first, 'Pepper');
      await tester.pump();

      await systemBack(tester);
      expect(find.text('Discard this pet?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this pet?'), findsNothing);
      expect(find.text('Add pet'), findsOneWidget, reason: 'flow must stay');

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });

    testWidgets('step 1: nav back and system back go to step 0, not out', (
      tester,
    ) async {
      await pumpPushable(tester, const AddPetScreen());
      await tester.enterText(find.byType(CupertinoTextField).first, 'Pepper');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Almost done'), findsOneWidget);

      // Nav-bar back at step 1 → step 0.
      await tester.tap(navBack());
      await tester.pumpAndSettle();
      expect(find.text('Add pet'), findsOneWidget);
      expect(find.text('Open'), findsNothing, reason: 'must not leave flow');

      // System back at step 1 → step 0 too (dirty, so no silent pop).
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      await systemBack(tester);
      expect(find.text('Add pet'), findsOneWidget);
      expect(find.text('Discard this pet?'), findsNothing);

      // System back at step 0, still dirty → the confirm.
      await systemBack(tester);
      expect(find.text('Discard this pet?'), findsOneWidget);
    });

    testWidgets('Cancel with a dirty form asks before discarding', (
      tester,
    ) async {
      await pumpPushable(tester, const AddPetScreen());
      await tester.enterText(find.byType(CupertinoTextField).first, 'Pepper');
      await tester.pump();
      await tester.tap(find.widgetWithText(SecondaryButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this pet?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });
  });

  group('EditPet', () {
    testWidgets('clean form: system back pops silently', (tester) async {
      final store = await pumpPushable(
        tester,
        EditPetScreen(petId: Seed.pets.first.id),
      );
      expect(store.pets, isNotEmpty);
      await systemBack(tester);
      expect(find.text('Discard changes?'), findsNothing);
      expectOnLauncher(tester);
    });

    testWidgets('dirty form: system back asks; discard pops', (tester) async {
      await pumpPushable(tester, EditPetScreen(petId: Seed.pets.first.id));
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Pepper II',
      );
      await tester.pump();

      await systemBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit pet'), findsOneWidget);

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });

    testWidgets('nav back on a dirty form asks too', (tester) async {
      await pumpPushable(tester, EditPetScreen(petId: Seed.pets.first.id));
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Pepper II',
      );
      await tester.pump();
      await tester.tap(navBack());
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('EditProfile', () {
    testWidgets('dirty form: system back asks; clean pops silently', (
      tester,
    ) async {
      await pumpPushable(tester, const EditProfileScreen());

      // Clean: pops with no dialog.
      await systemBack(tester);
      expect(find.text('Discard changes?'), findsNothing);
      expectOnLauncher(tester);
    });

    testWidgets('dirty: discard pops, cancel stays', (tester) async {
      await pumpPushable(tester, const EditProfileScreen());
      await tester.enterText(find.byType(CupertinoTextField).first, 'New Name');
      await tester.pump();

      await systemBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });
  });

  group('BookFlow', () {
    testWidgets('step 0 clean: system back pops silently', (tester) async {
      await pumpPushable(tester, const BookFlow());
      await systemBack(tester);
      expect(find.text('Leave booking?'), findsNothing);
      expectOnLauncher(tester);
    });

    testWidgets('nav back at step > 0 goes to the previous step', (
      tester,
    ) async {
      await pumpPushable(tester, const BookFlow());
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('AI health check'), findsOneWidget);

      // Nav-bar back (the StickyCta "Back" shares the label).
      await tester.tap(navBack());
      await tester.pumpAndSettle();
      expect(find.text('Who is this visit for?'), findsOneWidget);
      expect(find.text('Open'), findsNothing, reason: 'must not leave flow');
    });

    testWidgets('step 0 with progress: system back asks "Leave booking?"', (
      tester,
    ) async {
      await pumpPushable(tester, const BookFlow());
      // Progress at step 0 = picking a different pet than the pre-selected one.
      await tester.tap(find.text('Mochi'));
      await tester.pumpAndSettle();

      await systemBack(tester);
      expect(find.text('Leave booking?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Who is this visit for?'), findsOneWidget);

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });

    testWidgets('confirmed screen: system back is blocked', (tester) async {
      await pumpPushable(tester, const BookFlow());

      // Pet → triage → service: pet is pre-selected, triage is optional.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vet Consultation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      // Date & time: the calendar replaces the old day strip. Oct 16 2026 is
      // a Friday; seed a1 books Dr. Rafael 10:00–10:30, so 10:30 is free.
      expect(find.text('Oct 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Fri, 16 Oct'));
      await tester.pumpAndSettle();
      await tapSlot(tester, '10:30 AM');
      // Date & time → review → confirm.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Check the details, then confirm.'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Confirm booking'));
      await tester.pumpAndSettle();
      expect(find.text('You are booked'), findsOneWidget);

      // System back must not silently pop the confirmation.
      await systemBack(tester);
      expect(find.text('You are booked'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });
  });

  group('Triage', () {
    testWidgets('clean: system back pops silently', (tester) async {
      await pumpPushable(tester, const TriageScreen());
      await systemBack(tester);
      expect(find.text('Discard health check?'), findsNothing);
      expectOnLauncher(tester);
    });

    testWidgets('typed draft: system back asks; discard pops', (tester) async {
      await pumpPushable(tester, const TriageScreen());
      // Build a draft in the stepped flow: pick a pet, answer one question.
      await tester.tap(find.text('Biscuit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PressScale).first);
      await tester.pumpAndSettle();

      // Mid-flow back steps back inside the flow — the draft is kept, and
      // moving between steps never asks.
      await systemBack(tester);
      expect(find.text('Discard health check?'), findsNothing);
      expect(find.text('Which pet is this check for?'), findsOneWidget);

      // Back on the pet step with answers kept: leaving now would discard.
      await systemBack(tester);
      expect(find.text('Discard health check?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('AI Health Check'), findsOneWidget);

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });
  });

  group('ChatThread', () {
    testWidgets('clean: system back pops silently', (tester) async {
      await pumpPushable(tester, const ChatThreadScreen(threadId: 'th_clinic'));
      await systemBack(tester);
      expect(find.text('Discard message?'), findsNothing);
      expectOnLauncher(tester);
    });

    testWidgets('typed draft: system back asks; discard pops', (tester) async {
      await pumpPushable(tester, const ChatThreadScreen(threadId: 'th_clinic'));
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Is the clinic open today?',
      );
      await tester.pump();

      await systemBack(tester);
      expect(find.text('Discard message?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard message?'), findsNothing);

      await systemBack(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expectOnLauncher(tester);
    });
  });
}
