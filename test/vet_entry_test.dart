import 'dart:convert';

import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/main_vet.dart';
import 'package:carepaws/screens/login_screen.dart';
import 'package:carepaws/screens/vet/vet_shell.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Task 9a / Fix 2 — the vet entry point.
///
/// Pins the contract lib/main_vet.dart implements: the vet binary registers
/// [vetShellFactory], so a staff sign-in resolves to [VetShell] through the
/// shared [postAuthShell]; a customer credential in the vet binary still
/// signs in but lands on the customer [RootShell] — customer UI, zero vet
/// screens. And the launch shows the login screen when signed out: the vet
/// binary never boots straight into the portal.
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

/// Seeds a persisted session for [email] with [role], the way a real
/// sign-in would have left it (session email + stored account JSON).
void _seedSession({required String email, required String role}) {
  SharedPreferences.setMockInitialValues({
    'carepaws.settings.sessionEmail': email,
    'carepaws.auth.users': jsonEncode({
      email: {
        'name': role == 'vet' ? 'Dr. Vet' : 'Customer',
        'password': 'secret123',
        'createdAt': '2026-10-15T00:00:00.000',
        'role': role,
      },
    }),
  });
}

Future<void> _pumpLaunch(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: VetLaunch(store: store),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // main_vet.dart registers this at startup; tests do it by hand.
    vetShellFactory = () => const VetShell();
  });
  tearDown(() {
    // A global: never leak it into other test files.
    vetShellFactory = null;
  });

  group('factory + role select the shell', () {
    test('staff sign-in resolves to the vet shell', () async {
      expect(
        await AuthStore.register(
          name: 'Dr. Vet',
          email: 'vet@carepaws.test',
          password: 'vetpass123',
          role: 'vet',
        ),
        isNull,
      );
      final store = _store();
      expect(await store.signIn('vet@carepaws.test', 'vetpass123'), isTrue);
      expect(store.shell, AppShell.vet);
      expect(postAuthShell(store), isA<VetShell>());
    });

    test('customer credential in the vet binary lands on the customer shell '
        '(pinned)', () async {
      // The vet APK contains the customer shell as the fallback — a
      // customer who signs in there gets their own app, never vet UI.
      final store = _store();
      expect(
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );
      expect(store.shell, AppShell.customer);
      final shell = postAuthShell(store);
      expect(shell, isA<RootShell>());
      expect(shell, isNot(isA<VetShell>()));
    });

    test('without the factory even a vet lands on the customer shell', () {
      // The customer binary never registers the factory (app.dart stays
      // vet-free): the portal cannot render there by construction.
      vetShellFactory = null;
      final store = _store();
      expect(postAuthShell(store), isA<RootShell>());
    });
  });

  group('VetLaunch routing', () {
    testWidgets('signed out shows the login screen, not the portal', (
      tester,
    ) async {
      final store = _store();
      await store.loadSettings();
      expect(store.signedIn, isFalse);
      await _pumpLaunch(tester, store);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(VetShell), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restored vet session boots straight into the portal', (
      tester,
    ) async {
      _seedSession(email: 'vet@carepaws.test', role: 'vet');
      final store = _store();
      await store.loadSettings();
      expect(store.signedIn, isTrue);
      expect(store.shell, AppShell.vet);
      await _pumpLaunch(tester, store);
      expect(find.byType(VetShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('restored customer session lands on the customer shell', (
      tester,
    ) async {
      _seedSession(email: 'customer@carepaws.test', role: 'customer');
      final store = _store();
      await store.loadSettings();
      expect(store.signedIn, isTrue);
      expect(store.shell, AppShell.customer);
      await _pumpLaunch(tester, store);
      expect(find.byType(RootShell), findsOneWidget);
      expect(find.byType(VetShell), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
