import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/login_screen.dart';
import 'package:carepaws/screens/onboarding_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/settings_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:carepaws/widgets/splash_morph.dart';

/// Splash morph + launch routing (mark v5, Stream E).
///
/// The morph is a single finite controller; its completion routes through a
/// status listener — zero timers, so pumpAndSettle drives the whole timeline.
/// Reduced motion parks it: static emblem, 600ms, then route.
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

Future<AppStore> pumpSplash(
  WidgetTester tester, {
  bool reduceMotion = true,
  bool? onboardingCompleted,
  bool legacyOnboarded = false,
  bool signedIn = false,
}) async {
  final seed = <String, Object>{};
  if (onboardingCompleted != null) {
    seed['carepaws.onboarding.completed'] = onboardingCompleted;
  }
  if (legacyOnboarded) seed['carepaws.settings.onboarded'] = true;
  SharedPreferences.setMockInitialValues(seed);
  final s = AppStore(ai: AiService(client: _FailFast()));
  await s.loadSettings();
  // loadSettings restores the persisted override (false in tests) — the
  // test's choice wins and is applied after.
  s.reduceMotionOverride = reduceMotion;
  s.signedIn = signedIn;
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const SplashScreen(),
      ),
    ),
  );
  await tester.pump(); // first frame: the morph starts
  return s;
}

Future<void> finishTour(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
}

void main() {
  group('splash morph', () {
    testWidgets('mid-morph: 160pt emblem, centered, no text or CTA', (
      tester,
    ) async {
      await pumpSplash(tester, reduceMotion: false);

      expect(find.byType(SplashMorph), findsOneWidget);
      expect(find.byType(LogoMark), findsNothing);
      expect(find.text('CAREPAWS'), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);

      final box = tester.getRect(find.byType(SplashMorph));
      expect(box.width, 160);
      expect(box.height, 160);
      expect(box.center.dx, 390 / 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders the static emblem', (tester) async {
      await pumpSplash(tester, reduceMotion: true);

      expect(find.byType(LogoMark), findsOneWidget);
      expect(find.byType(SplashMorph), findsNothing);
    });

    testWidgets('morph keyframes follow the design contracts', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 2000),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(home: SplashMorph(progress: controller, size: 160)),
      );

      List<Opacity> opacities() =>
          tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      double toeScale(int i) => tester
          .widgetList<Transform>(find.byType(Transform))
          .elementAt(i + 1) // [0] is the pad
          .transform
          .entry(0, 0);

      // 200ms: pad mid-fade (0–0.5s); toes not started.
      controller.value = 0.1;
      await tester.pump();
      expect(opacities()[0].opacity, greaterThan(0.5)); // pad
      for (var i = 1; i <= 4; i++) {
        expect(opacities()[i].opacity, 0.0); // toes
      }

      // 600ms: pad done; toe1 mid-pop overshooting, toe4 not started.
      controller.value = 0.3;
      await tester.pump();
      expect(opacities()[0].opacity, 1.0);
      expect(toeScale(0), greaterThan(1.0)); // toe1 spring overshoot
      expect(opacities()[4].opacity, 0.0); // toe4

      // End of timeline: everything at rest.
      controller.value = 1.0;
      await tester.pump();
      for (final o in opacities()) {
        expect(o.opacity, 1.0);
      }
      for (var i = 0; i < 4; i++) {
        expect(toeScale(i), 1.0);
      }
    });
  });

  group('launch routing', () {
    testWidgets('first launch: morph completes → onboarding', (tester) async {
      final s = await pumpSplash(tester);
      expect(s.onboardingCompleted, isFalse);

      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      // The splash leaves the stack: Back exits instead of landing on a
      // dead, non-interactive splash.
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('returning launch, signed out: morph → login (sign-in mode)', (
      tester,
    ) async {
      await pumpSplash(tester, onboardingCompleted: true);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      // Sign-in mode, not register.
      expect(find.textContaining("Don't have an account?"), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('signed-in session: morph → tab shell directly', (
      tester,
    ) async {
      await pumpSplash(tester, onboardingCompleted: true, signedIn: true);
      await tester.pumpAndSettle();

      expect(find.byType(RootShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      'full first launch: onboarding → register → Home sets the flag',
      (tester) async {
        final s = await pumpSplash(tester);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);

        await finishTour(tester);

        // Register mode: the first-launch flow opens create-account.
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.widgetWithText(PrimaryButton, 'Create account'),
          findsOneWidget,
        );

        // Fill the form, consent, create the account.
        final fields = find.byType(CupertinoTextField);
        expect(fields, findsNWidgets(3));
        await tester.enterText(fields.at(0), 'Launch Tester');
        await tester.enterText(fields.at(1), 'launch@example.com');
        await tester.enterText(fields.at(2), 'password123');
        await tester.pump();
        await tester.tap(find.byKey(const Key('consent-checkbox')));
        await tester.pump();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Create account'));
        await tester.pumpAndSettle();
        // Let the "Account created" toast self-dismiss so teardown is clean.
        await tester.pump(const Duration(milliseconds: 2500));

        // Registration drops back to sign-in with the email filled in.
        expect(find.widgetWithText(PrimaryButton, 'Sign in'), findsOneWidget);
        final signInFields = find.byType(CupertinoTextField);
        expect(signInFields, findsNWidgets(2));
        await tester.enterText(signInFields.at(1), 'password123');
        await tester.pump();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Sign in'));
        await tester.pumpAndSettle();

        // Home reached: the completed flag is written and the next launch
        // skips the first-launch flow.
        expect(find.byType(RootShell), findsOneWidget);
        expect(s.onboardingCompleted, isTrue);
        expect(await SettingsStore.readOnboardingCompleted(), isTrue);
      },
    );

    testWidgets('legacy onboarded users never see the first-launch flow', (
      tester,
    ) async {
      final s = await pumpSplash(tester, legacyOnboarded: true);

      // Migrated on load: the new key is written, the old one retired.
      expect(s.onboardingCompleted, isTrue);
      expect(await SettingsStore.readOnboardingCompleted(), isTrue);

      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  group('completeFirstLaunch', () {
    test('writes the flag once and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(ai: AiService(client: _FailFast()));
      await s.loadSettings();
      expect(s.onboardingCompleted, isFalse);

      s.completeFirstLaunch();
      expect(s.onboardingCompleted, isTrue);
      expect(await SettingsStore.readOnboardingCompleted(), isTrue);

      // Second call is a no-op.
      s.completeFirstLaunch();
      expect(s.onboardingCompleted, isTrue);
    });
  });
}
