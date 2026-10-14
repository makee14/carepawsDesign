import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/login_screen.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B15 UI path: the "Create one" switch reveals the registration form, and
/// submitting it registers the account (store-level register + signIn is
/// covered in auth_session_test.dart).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Create one switches to register mode and creates the account', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    var signedIn = false;
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: LoginScreen(onSignedIn: () => signedIn = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to register mode.
    await tester.tap(find.textContaining('Create one', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Your first name'), findsOneWidget);

    // Fill the three fields (Name, Email, Password order).
    final fields = find.byType(CupertinoTextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Sweep Tester');
    await tester.enterText(fields.at(1), 'sweep@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.pump();

    // Submit.
    final btn = find.widgetWithText(PrimaryButton, 'Create account');
    await tester.tap(btn);
    await tester.pumpAndSettle();
    // Let the "Account created" toast's self-dismiss timer fire so teardown
    // sees no pending timers.
    await tester.pump(const Duration(milliseconds: 2500));

    // Account exists; the form drops back to sign-in with the email filled.
    expect(await AuthStore.displayName('sweep@example.com'), 'Sweep Tester');
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('sweep@example.com'), findsOneWidget);
    expect(signedIn, isFalse);

    // And the new account can sign in to a zero-pet home.
    await tester.enterText(
      find.byType(CupertinoTextField).at(1),
      'password123',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(signedIn, isTrue);
    expect(store.signedIn, isTrue);
    expect(store.pets, isEmpty);
    expect(store.reminders, isEmpty);
    expect(store.notifications, isEmpty);
  });
}
