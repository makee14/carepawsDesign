import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/motion.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/screens/onboarding_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Splash screen tests — composition redo + icon-self loop (2026-10-14).
///
/// The loop controller repeats forever, so `pumpAndSettle` would hang unless
/// the store's reduce-motion override is on. Every test here opts into
/// stillness for that reason; the loop itself is verified visually.
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

Future<AppStore> pumpSplash(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore(ai: AiService(client: _FailFast()));
  s.reduceMotionOverride = true;
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
  await tester.pumpAndSettle();
  return s;
}

FadeIn fadeInOf(WidgetTester tester, String text) => tester.widget<FadeIn>(
  find.ancestor(of: find.text(text), matching: find.byType(FadeIn)),
);

void main() {
  testWidgets('splash renders badge, wordmark, tagline, CTA and version', (
    tester,
  ) async {
    await pumpSplash(tester);

    expect(find.byType(LogoMark), findsOneWidget);
    expect(find.text('CAREPAWS'), findsOneWidget);
    expect(find.text('Veterinary Clinic'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Get started'), findsOneWidget);
    expect(find.text(Seed.appVersion), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Get started is a proper full-width 54pt CTA', (tester) async {
    await pumpSplash(tester);

    final size = tester.getSize(find.byType(PrimaryButton));
    // 390pt screen minus the 24pt side padding: a real CTA, not a 200pt stub.
    expect(size.width, 390 - 2 * 24);
    expect(size.height, 54);
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('no halo ring around the mark — the icon itself is the loop', (
    tester,
  ) async {
    await pumpSplash(tester);

    final rings = find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.border != null;
      }),
    );
    expect(rings, findsNothing);
  });

  testWidgets('wordmark and tagline use fade + gentle rise', (tester) async {
    await pumpSplash(tester);

    expect(fadeInOf(tester, 'CAREPAWS').rise, 12);
    expect(fadeInOf(tester, 'Veterinary Clinic').rise, 12);
  });

  testWidgets('AX5 text scale: no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpSplash(tester);

    expect(find.text('CAREPAWS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Get started advances to onboarding', (tester) async {
    final s = await pumpSplash(tester);
    expect(s.onboardingSeen, isFalse);

    await tester.tap(find.widgetWithText(PrimaryButton, 'Get started'));
    await tester.pumpAndSettle();

    // The splash stays underneath; the onboarding tour is now on top.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
