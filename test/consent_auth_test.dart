import 'dart:convert';

import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/login_screen.dart';
import 'package:carepaws/screens/profile/privacy_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/services/settings_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Worker A (consent + auth integrity): the registration consent gate, the
/// real logout path, and the real delete-account path.
///
/// Every widget test re-seeds the mock preferences (SharedPreferences without
/// mock values hangs the fake-async clock forever).
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

AppStore _store() {
  final s = AppStore(ai: AiService(client: _FailFast()));
  // The splash loop animation repeats forever; stillness keeps pumpAndSettle
  // (and teardown) from hanging.
  s.reduceMotionOverride = true;
  addTearDown(s.dispose);
  return s;
}

/// Registers + signs in through real async: [AppStore.register]/[signIn]
/// contain short real-time delays for button affordance, which never elapse
/// under testWidgets' fake clock — [WidgetTester.runAsync] runs them in real
/// time instead.
Future<void> _registerAndSignIn(WidgetTester tester, AppStore store) async {
  await tester.runAsync(() async {
    expect(
      await store.register('Mark Rivera', 'mark@example.com', 'secret123'),
      isTrue,
    );
    expect(await store.signIn('mark@example.com', 'secret123'), isTrue);
  });
}

Future<void> _pumpLogin(WidgetTester tester, AppStore store) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: LoginScreen(onSignedIn: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _switchToRegister(WidgetTester tester) async {
  await tester.tap(find.textContaining('Create one', findRichText: true));
  await tester.pumpAndSettle();
}

Future<void> _fillRegisterForm(WidgetTester tester) async {
  final fields = find.byType(CupertinoTextField);
  expect(fields, findsNWidgets(3));
  await tester.enterText(fields.at(0), 'Sweep Tester');
  await tester.enterText(fields.at(1), 'consent@example.com');
  await tester.enterText(fields.at(2), 'password123');
  await tester.pump();
}

VoidCallback? _createAccountOnPressed(WidgetTester tester) => tester
    .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Create account'))
    .onPressed;

/// Taps a [TapGestureRecognizer] span inside a rich-text paragraph: the
/// finder's center can land on a neighbouring span, so resolve the span's
/// laid-out box and tap its middle instead.
Future<void> _tapSpan(
  WidgetTester tester,
  String paragraphText,
  String spanText,
) async {
  final para = tester.renderObject<RenderParagraph>(
    find.textContaining(paragraphText, findRichText: true),
  );
  final plain = para.text.toPlainText();
  final start = plain.indexOf(spanText);
  expect(start, isNot(-1), reason: 'span "$spanText" not in paragraph');
  final boxes = para.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + spanText.length),
  );
  expect(boxes, isNotEmpty);
  await tester.tapAt(para.localToGlobal(boxes.first.toRect().center));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('A1 — registration consent gate', () {
    testWidgets('Create account stays disabled until consent is checked', (
      tester,
    ) async {
      final store = _store();
      await _pumpLogin(tester, store);
      await _switchToRegister(tester);
      await _fillRegisterForm(tester);

      // Fields valid, consent unchecked → blocked, with a visible reason.
      expect(_createAccountOnPressed(tester), isNull);
      expect(
        find.textContaining('I agree to the', findRichText: true),
        findsOneWidget,
      );

      // Check the box → enabled.
      await tester.tap(find.byKey(const Key('consent-checkbox')));
      await tester.pump();
      expect(_createAccountOnPressed(tester), isNotNull);
    });

    testWidgets('terms link opens the real copy in a sheet; input survives', (
      tester,
    ) async {
      final store = _store();
      await _pumpLogin(tester, store);
      await _switchToRegister(tester);
      await _fillRegisterForm(tester);

      await _tapSpan(tester, 'I agree to the', 'Terms of Service');

      // The sheet shows the existing LegalScreen copy.
      expect(find.text('Terms of service'), findsWidgets);
      expect(find.text('Using CarePaws'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The form is untouched: values are still in the fields.
      final fields = find.byType(CupertinoTextField);
      expect(
        tester.widget<CupertinoTextField>(fields.at(0)).controller!.text,
        'Sweep Tester',
      );
      expect(
        tester.widget<CupertinoTextField>(fields.at(1)).controller!.text,
        'consent@example.com',
      );
    });

    testWidgets('privacy link opens the privacy copy in a sheet', (
      tester,
    ) async {
      final store = _store();
      await _pumpLogin(tester, store);
      await _switchToRegister(tester);

      await _tapSpan(tester, 'I agree to the', 'Privacy Policy');

      expect(find.text('Privacy policy'), findsWidgets);
      expect(find.text('What we collect'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('What we collect'), findsNothing);
    });

    testWidgets(
      'checking consent records agreedToTermsAt in the account JSON',
      (tester) async {
        final store = _store();
        await _pumpLogin(tester, store);
        await _switchToRegister(tester);
        await _fillRegisterForm(tester);

        await tester.tap(find.byKey(const Key('consent-checkbox')));
        await tester.pump();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Create account'));
        await tester.pumpAndSettle();
        // Let the "Account created" toast's self-dismiss timer fire so
        // teardown sees no pending timers.
        await tester.pump(const Duration(milliseconds: 2500));

        final p = await SharedPreferences.getInstance();
        final raw = p.getString('carepaws.auth.users')!;
        final users = jsonDecode(raw) as Map<String, dynamic>;
        final agreed =
            (users['consent@example.com'] as Map)['agreedToTermsAt'] as String?;
        expect(agreed, isNotNull);
        expect(() => DateTime.parse(agreed!), returnsNormally);
      },
    );

    test('AuthStore.register persists agreedToTermsAt when given', () async {
      final at = DateTime.utc(2026, 10, 15, 9);
      expect(
        await AuthStore.register(
          name: 'T',
          email: 'ts@example.com',
          password: 'secret123',
          agreedToTermsAt: at,
        ),
        isNull,
      );
      final p = await SharedPreferences.getInstance();
      final users = jsonDecode(
        p.getString('carepaws.auth.users')!,
      ) as Map<String, dynamic>;
      expect(
        (users['ts@example.com'] as Map)['agreedToTermsAt'],
        at.toIso8601String(),
      );
    });

    test('AuthStore.deleteCredentials removes only that account', () async {
      expect(
        await AuthStore.register(
          name: 'A',
          email: 'a@example.com',
          password: 'secret123',
        ),
        isNull,
      );
      expect(
        await AuthStore.register(
          name: 'B',
          email: 'b@example.com',
          password: 'secret123',
        ),
        isNull,
      );
      await AuthStore.deleteCredentials('a@example.com');
      expect(await AuthStore.exists('a@example.com'), isFalse);
      expect(await AuthStore.exists('b@example.com'), isTrue);
    });
  });

  group('A2 — real logout everywhere', () {
    testWidgets('signOutAndExit clears the session and lands on the splash', (
      tester,
    ) async {
      final store = _store();
      await _registerAndSignIn(tester, store);
      expect(await SettingsStore.readSessionEmail(), 'mark@example.com');

      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: Builder(
              builder: (ctx) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    onPressed: () => signOutAndExit(ctx),
                    child: const Text('Trigger'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Log out of CarePaws?'), findsOneWidget);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(store.signedIn, isFalse);
      expect(store.accountEmail, isNull);
      expect(await SettingsStore.readSessionEmail(), isNull);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A3 — real delete account', () {
    testWidgets(
      'delete account removes credentials, clears data, signs out, lands on splash',
      (tester) async {
        final store = _store();
        await _registerAndSignIn(tester, store);

        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpWidget(
          AppScope(
            store: store,
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const PrivacyScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(RowTile, 'Delete account'));
        await tester.pumpAndSettle();
        expect(find.text('Delete account?'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(await AuthStore.exists('mark@example.com'), isFalse);
        expect(store.signedIn, isFalse);
        expect(await SettingsStore.readSessionEmail(), isNull);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
