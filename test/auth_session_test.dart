import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/login_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/services/settings_store.dart';
import 'package:carepaws/state/app_store.dart';

/// B15 + B16: fresh accounts start with zero demo data, and the auth session
/// survives process death via the persisted session email.
///
/// Every test re-seeds the mock preferences so the "process restart" cases
/// (fresh store, same prefs) are hermetic.
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

AppStore _store() {
  final s = AppStore(ai: AiService(client: _FailFast()));
  addTearDown(s.dispose);
  return s;
}

Future<void> _registerAndSignIn(AppStore store) async {
  expect(
    await store.register('Mark Rivera', 'mark@example.com', 'secret123'),
    isTrue,
  );
  expect(await store.signIn('mark@example.com', 'secret123'), isTrue);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('B15 — seeds are demo-only', () {
    test('fresh registered account starts with zero pets/appointments/orders/messages', () async {
      final store = _store();
      await _registerAndSignIn(store);

      expect(store.signedIn, isTrue);
      expect(store.accountName, 'Mark Rivera');
      expect(store.pets, isEmpty);
      expect(store.appointments, isEmpty);
      expect(store.orders, isEmpty);
      expect(store.messages, isEmpty);
    });

    test('fresh registered account has no seed reminders/notifications/prescriptions', () async {
      final store = _store();
      await _registerAndSignIn(store);

      expect(store.signedIn, isTrue);
      expect(store.reminders, isEmpty);
      expect(store.notifications, isEmpty);
      expect(store.prescriptions, isEmpty);
    });

    test('demo sign-in still loads the seed dataset', () async {
      final store = _store();
      expect(
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );

      expect(store.pets, isNotEmpty);
      expect(store.appointments, isNotEmpty);
      expect(store.orders, isNotEmpty);
      expect(store.messages, isNotEmpty);
    });

    test(
      'demo sign-in after a registered session restores the seeds',
      () async {
        final store = _store();
        await _registerAndSignIn(store);
        expect(store.pets, isEmpty);

        store.signOut();
        expect(
          await store.signIn(AppStore.demoEmail, AppStore.demoPassword),
          isTrue,
        );
        expect(store.pets, isNotEmpty);
      },
    );

    test('reset() on a registered account does not resurrect seeds', () async {
      final store = _store();
      await _registerAndSignIn(store);
      store.reset();

      expect(store.pets, isEmpty);
      expect(store.appointments, isEmpty);
      expect(store.orders, isEmpty);
      expect(store.messages, isEmpty);
    });

    test('reset() on the demo account restores the seeds', () async {
      final store = _store();
      expect(
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );
      store.reset();

      expect(store.pets, isNotEmpty);
      expect(store.messages, isNotEmpty);
    });
  });

  group('B16 — auth session persists', () {
    test('signIn persists the session email', () async {
      final store = _store();
      await _registerAndSignIn(store);

      expect(await SettingsStore.readSessionEmail(), 'mark@example.com');
    });

    test('demo signIn persists the demo email', () async {
      final store = _store();
      expect(
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );

      expect(await SettingsStore.readSessionEmail(), AppStore.demoEmail);
    });

    test('signOut clears the persisted session email', () async {
      final store = _store();
      await _registerAndSignIn(store);
      expect(await SettingsStore.readSessionEmail(), isNotNull);

      store.signOut();
      // signOut clears asynchronously; give the write a chance to land.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await SettingsStore.readSessionEmail(), isNull);
    });

    test(
      'fresh store + loadSettings() with a saved session restores sign-in',
      () async {
        final first = _store();
        await _registerAndSignIn(first);

        // Simulated process restart: a brand-new store over the same prefs.
        final restarted = _store();
        await restarted.loadSettings();

        expect(restarted.signedIn, isTrue);
        expect(restarted.accountEmail, 'mark@example.com');
        expect(restarted.accountName, 'Mark Rivera');
        expect(restarted.pets, isEmpty);
      },
    );

    test('restored demo session reloads the seed dataset', () async {
      final first = _store();
      expect(
        await first.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );

      final restarted = _store();
      await restarted.loadSettings();

      expect(restarted.signedIn, isTrue);
      expect(restarted.accountName, isNull);
      expect(restarted.pets, isNotEmpty);
    });

    test('no saved session stays signed out', () async {
      final store = _store();
      await store.loadSettings();
      expect(store.signedIn, isFalse);
    });

    test('AuthStore.displayName resolves without re-authenticating', () async {
      final store = _store();
      await store.register('Mark Rivera', 'mark@example.com', 'secret123');

      expect(await AuthStore.displayName('mark@example.com'), 'Mark Rivera');
      expect(await AuthStore.displayName('MARK@EXAMPLE.COM'), 'Mark Rivera');
      expect(await AuthStore.displayName('nobody@example.com'), isNull);
      expect(await AuthStore.displayName(AppStore.demoEmail), isNull);
    });
  });

  group('B16 — splash routes a restored session straight to the shell', () {
    // Widget tests run on a fake clock, so register()/signIn() (420ms of
    // artificial delay each) would never complete here. Seed the persisted
    // session directly instead — loadSettings() only does prefs reads.
    void seedSession() {
      SharedPreferences.setMockInitialValues({
        'carepaws.settings.sessionEmail': 'mark@example.com',
        'carepaws.auth.users': jsonEncode({
          'mark@example.com': {
            'name': 'Mark Rivera',
            'password': 'secret123',
            'createdAt': '2026-10-15T00:00:00.000',
          },
        }),
      });
    }

    Future<AppStore> signedInStore(WidgetTester tester) async {
      seedSession();
      final store = _store();
      await store.loadSettings();
      expect(store.signedIn, isTrue);
      store.reduceMotionOverride = true;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      return store;
    }

    testWidgets('saved session auto-advances without showing login', (
      tester,
    ) async {
      final store = await signedInStore(tester);

      var advanced = false;
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: SplashScreen(onDone: () => advanced = true),
          ),
        ),
      );
      // Bounded pumps, not pumpAndSettle: the signed-in splash keeps its
      // (now unreachable) CTA in the busy state, whose activity indicator
      // never settles. In production the route is removed by
      // pushAndRemoveUntil the moment onDone fires.
      for (var i = 0; i < 50 && !advanced; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The splash handed off to the shell on its own — no login shown.
      expect(advanced, isTrue);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no session still shows the Get started CTA', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = _store();
      await store.loadSettings();
      store.reduceMotionOverride = true;

      var advanced = false;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: SplashScreen(onDone: () => advanced = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(advanced, isFalse);
      expect(find.text('Get started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
