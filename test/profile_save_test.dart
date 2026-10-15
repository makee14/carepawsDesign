import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/login_screen.dart';
import 'package:carepaws/screens/profile/settings_screens.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/state/profile_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Regression tests for the CarePaws bug-fix loop, worker B:
/// item #9 (profile save path + field mapping) and item #7 (login error
/// handling: inline field errors, toast on success).
///
/// Bug #9 root cause: EditProfileScreen's "Save changes" never wrote anything —
/// it dismissed a non-existent sheet and showed a fake "Profile saved." notice.
/// The contact field was seeded from the hardcoded `Seed.ownerContact`
/// ('phone · email' merged) instead of the account's own stored values.

DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

Future<void> pumpScreen(WidgetTester tester, AppStore store, Widget screen) {
  return tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: screen),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Owner profile save path', () {
    test('saveOwnerProfile writes name and phone to the store', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);

      final errors = await store.saveOwnerProfile(
        name: 'Mark Rivera',
        phone: '0917 555 0142',
      );

      expect(errors, isNull);
      expect(store.ownerName, 'Mark Rivera');
      expect(store.ownerPhone, '0917 555 0142');
    });

    test('saved profile survives a fresh store for the same account', () async {
      final first = AppStore(now: fixedNow());
      addTearDown(first.dispose);
      await first.register('Persist User', 'persist@example.com', 'secret123');
      expect(await first.signIn('persist@example.com', 'secret123'), isTrue);
      expect(
        await first.saveOwnerProfile(
          name: 'Persisted Name',
          phone: '+63 917 000 0000',
        ),
        isNull,
      );

      final second = AppStore(now: fixedNow());
      addTearDown(second.dispose);
      expect(await second.signIn('persist@example.com', 'secret123'), isTrue);
      expect(second.ownerName, 'Persisted Name');
      expect(second.ownerPhone, '+63 917 000 0000');
    });

    test('empty name is rejected and nothing is persisted', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.register('Keep Me', 'keepme@example.com', 'secret123');
      await store.signIn('keepme@example.com', 'secret123');

      final errors = await store.saveOwnerProfile(
        name: '   ',
        phone: '0917 555 0142',
      );

      expect(
        errors,
        containsPair(ProfileField.name, 'Please enter your name.'),
      );
      expect(store.ownerName, 'Keep Me');
      expect(store.ownerPhone, isEmpty);
    });

    test('a malformed phone number is rejected', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);

      final errors = await store.saveOwnerProfile(
        name: 'Mark Rivera',
        phone: 'not-a-phone',
      );

      expect(errors, containsPair(ProfileField.phone, isNotEmpty));
      expect(store.ownerPhone, isEmpty);
    });

    test('a successful save notifies listeners once', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
      var count = 0;
      store.addListener(() => count++);

      expect(
        await store.saveOwnerProfile(name: 'Listener Check', phone: ''),
        isNull,
      );
      expect(count, 1);
    });
  });

  group('Owner profile field mapping', () {
    test('email is bound to the signed-in account email', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
      expect(store.ownerEmail, AppStore.demoEmail);
    });

    test(
      'demo account falls back to the seeded name with an empty phone',
      () async {
        final store = AppStore(now: fixedNow());
        addTearDown(store.dispose);
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
        expect(store.ownerName, Seed.ownerName);
        expect(store.ownerPhone, isEmpty);
      },
    );

    test('registered account maps name and email from the account', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.register('Mark Rivera', 'mark@example.com', 'secret123');
      await store.signIn('mark@example.com', 'secret123');
      expect(store.ownerName, 'Mark Rivera');
      expect(store.ownerEmail, 'mark@example.com');
      expect(store.ownerPhone, isEmpty);
    });

    test('signOut clears the profile override', () async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
      await store.saveOwnerProfile(name: 'Changed', phone: '0917 111 2222');
      store.signOut();
      expect(store.ownerName, Seed.ownerName);
      expect(store.ownerPhone, isEmpty);
      expect(store.ownerEmail, isEmpty);
    });
  });

  group('Edit profile screen', () {
    testWidgets('prefills Full name, Phone and Email from the stored profile', (
      tester,
    ) async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      // runAsync: signIn's artificial pause needs the real clock.
      await tester.runAsync(() async {
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
        await store.saveOwnerProfile(
          name: 'Mark Rivera',
          phone: '0917 555 0142',
        );
      });

      await pumpScreen(tester, store, const EditProfileScreen());
      await tester.pumpAndSettle();

      final fields = tester.widgetList<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(fields.length, 3);
      expect(fields.elementAt(0).controller?.text, 'Mark Rivera');
      expect(fields.elementAt(1).controller?.text, '0917 555 0142');
      expect(fields.elementAt(2).controller?.text, AppStore.demoEmail);
    });

    testWidgets('empty name shows an inline error and does not save', (
      tester,
    ) async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await tester.runAsync(
        () => store.signIn(AppStore.demoEmail, AppStore.demoPassword),
      );

      await pumpScreen(tester, store, const EditProfileScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(CupertinoTextField).first, '');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name.'), findsOneWidget);
      expect(store.ownerName, Seed.ownerName);
    });

    testWidgets('a valid save shows a toast and pops back', (tester) async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);
      await tester.runAsync(
        () => store.signIn(AppStore.demoEmail, AppStore.demoPassword),
      );

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('open'),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Mark Rivera',
      );
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Profile saved.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(store.ownerName, 'Mark Rivera');
      // Let the toast's auto-dismiss timer fire so teardown stays clean.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Sign-in error handling', () {
    testWidgets('a wrong password shows one inline error under the field', (
      tester,
    ) async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);

      await pumpScreen(tester, store, LoginScreen(onSignedIn: () {}));
      await tester.pumpAndSettle();

      final fields = find.byType(CupertinoTextField);
      await tester.enterText(fields.at(0), 'someone@example.com');
      await tester.enterText(fields.at(1), 'wrongpass1');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.text("Email and password don't match. Try again."),
        findsOneWidget,
      );
    });

    testWidgets('registration success shows a toast, not a banner card', (
      tester,
    ) async {
      final store = AppStore(now: fixedNow());
      addTearDown(store.dispose);

      await pumpScreen(tester, store, LoginScreen(onSignedIn: () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Create one'));
      await tester.pumpAndSettle();

      final fields = find.byType(CupertinoTextField);
      await tester.enterText(fields.at(0), 'Mark Rivera');
      await tester.enterText(fields.at(1), 'newuser@example.com');
      await tester.enterText(fields.at(2), 'secret123');
      await tester.pumpAndSettle();
      // Consent gate (A1): registration requires the Terms/Privacy checkbox.
      await tester.tap(find.byKey(const Key('consent-checkbox')));
      await tester.pumpAndSettle();
      final createButton = find.widgetWithText(PrimaryButton, 'Create account');
      await tester.ensureVisible(createButton);
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.text('Account created — sign in with your new password.'),
        findsOneWidget,
      );
      // The form drops back to sign-in with the new email filled in.
      expect(
        tester.widget<CupertinoTextField>(fields.at(0)).controller?.text,
        'newuser@example.com',
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
