import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/state/app_store.dart';

/// Task 2 — role gating. Written before the implementation (RED first).
///
/// Pins the two-role rule: exactly customer and vet, no staff sub-roles. The
/// demo account is always customer-side; a staff login selects the vet shell;
/// vet routes are guarded for everyone else — crafted navigation included,
/// not just hidden UI.
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

Future<void> _registerStaff() async {
  final err = await AuthStore.register(
    name: 'Dr. Vet',
    email: 'vet@carepaws.test',
    password: 'vetpass123',
    role: 'vet',
  );
  expect(err, isNull);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('role selection after auth', () {
    test('staff login selects the vet shell', () async {
      await _registerStaff();
      final store = _store();
      expect(await store.signIn('vet@carepaws.test', 'vetpass123'), isTrue);
      expect(store.shell, AppShell.vet);
    });

    test('demo account login selects the customer shell (pinned)', () async {
      // Standing rule: the demo account is customer-side. This must never
      // regress — a demo login must not land in the vet portal.
      final store = _store();
      expect(
        await store.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );
      expect(store.shell, AppShell.customer);
    });

    test('registered customer login selects the customer shell', () async {
      expect(
        await AuthStore.register(
          name: 'Customer',
          email: 'customer@carepaws.test',
          password: 'customer1',
        ),
        isNull,
      );
      final store = _store();
      expect(await store.signIn('customer@carepaws.test', 'customer1'), isTrue);
      expect(store.shell, AppShell.customer);
    });

    test('a fresh store defaults to the customer shell', () {
      expect(_store().shell, AppShell.customer);
    });

    test('sign out resets the shell to customer', () async {
      await _registerStaff();
      final store = _store();
      await store.signIn('vet@carepaws.test', 'vetpass123');
      expect(store.shell, AppShell.vet);
      store.signOut();
      expect(store.shell, AppShell.customer);
    });

    test('an unknown role value never selects the vet shell', () async {
      // Anything but 'vet' normalizes to customer: a crafted role string must
      // not escalate into the portal.
      expect(
        await AuthStore.register(
          name: 'Sneaky',
          email: 'sneaky@carepaws.test',
          password: 'sneaky123',
          role: 'admin',
        ),
        isNull,
      );
      final store = _store();
      await store.signIn('sneaky@carepaws.test', 'sneaky123');
      expect(store.shell, AppShell.customer);
    });
  });

  group('root router picks the shell', () {
    test('postAuthShell falls back to the customer shell when no vet factory '
        'is registered', () async {
      // The customer binary never registers the factory — app.dart must stay
      // vet-free so the portal tree-shakes out. A vet credential there still
      // signs in; there is simply no vet UI to show.
      await _registerStaff();
      final store = _store();
      await store.signIn('vet@carepaws.test', 'vetpass123');
      expect(vetShellFactory, isNull);
      expect(postAuthShell(store), isA<RootShell>());
    });

    test('postAuthShell returns the customer shell for customers', () async {
      final store = _store();
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
      expect(postAuthShell(store), isA<RootShell>());
    });
  });

  group('vet route guard', () {
    Future<void> pushGuardedVetRoute(
      WidgetTester tester,
      AppStore store,
    ) async {
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: Builder(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).push(
                      appRoute(guardVetRoute(store, const Text('VET ONLY'))),
                    ),
                    child: const Text('Go vet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go vet'));
      await tester.pumpAndSettle();
    }

    testWidgets('customer pushing a vet route lands on customer home', (
      tester,
    ) async {
      final store = _store();
      // signIn awaits a 420ms button-state delay: run it in the real async
      // zone, otherwise the fake test clock deadlocks the wait.
      await tester.runAsync(
        () => store.signIn(AppStore.demoEmail, AppStore.demoPassword),
      );
      expect(store.signedIn, isTrue);
      await pushGuardedVetRoute(tester, store);
      expect(find.text('VET ONLY'), findsNothing);
      expect(find.byType(RootShell), findsOneWidget);
    });

    testWidgets('vet pushing a vet route reaches the vet page', (tester) async {
      await _registerStaff();
      final store = _store();
      await tester.runAsync(
        () => store.signIn('vet@carepaws.test', 'vetpass123'),
      );
      expect(store.signedIn, isTrue);
      await pushGuardedVetRoute(tester, store);
      expect(find.text('VET ONLY'), findsOneWidget);
    });
  });
}
