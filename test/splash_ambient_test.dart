import 'dart:math' as math;

import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/splash_ambient.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Splash v2 ambient scene tests (2026-10-14).
///
/// The aurora + sheen + motes loops all repeat forever, so `pumpAndSettle`
/// would hang unless the store's reduce-motion override is on. The first test
/// opts into stillness for that reason — completing the settle *is* the proof
/// that every controller parks under reduced motion.
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

Future<AppStore> pumpSplashStill(WidgetTester tester) async {
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

double _ratio(Color a, Color b) {
  double lum(Color c) {
    double f(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets(
    'ambient renders behind splash content; reduced motion parks every loop',
    (tester) async {
      await pumpSplashStill(tester);

      expect(find.byType(SplashAmbient), findsOneWidget);
      expect(find.byType(BadgeHero), findsOneWidget);
      // The badge artwork still renders exactly once in the semantics tree
      // (the sheen's mask copy is excluded).
      expect(find.byType(LogoMark), findsOneWidget);
      expect(find.text('CAREPAWS'), findsOneWidget);
      expect(find.text('Veterinary Clinic'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final ambient = tester.state<SplashAmbientState>(
        find.byType(SplashAmbient),
      );
      expect(ambient.debugAmbientRepeating, isFalse);
      final hero = tester.state<BadgeHeroState>(find.byType(BadgeHero));
      expect(hero.debugSheenRepeating, isFalse);
    },
  );

  testWidgets('loops run when motion is not reduced', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: SplashAmbient()));
    final ambient = tester.state<SplashAmbientState>(
      find.byType(SplashAmbient),
    );
    expect(ambient.debugAmbientRepeating, isTrue);

    await tester.pumpWidget(
      CupertinoApp(
        home: BadgeHero(
          loop: const AlwaysStoppedAnimation<double>(0.25),
          size: 120,
          child: const SizedBox.square(dimension: 120),
        ),
      ),
    );
    final hero = tester.state<BadgeHeroState>(find.byType(BadgeHero));
    expect(hero.debugSheenRepeating, isTrue);

    // Full aurora cycle plus a sheen loop: no exceptions, no missed frames.
    await tester.pump(const Duration(seconds: 16));
    expect(tester.takeException(), isNull);
  });

  test('aurora loop math is seamless at the wrap', () {
    // Blob drift: identical position at t=0 and t=1 for every blob's params.
    for (final (base, amp, phase) in [
      (0.30, 0.07, 0.00),
      (0.22, 0.05, 0.13),
      (0.82, 0.06, 0.33),
      (0.40, 0.07, 0.47),
      (0.12, 0.05, 0.66),
      (0.64, 0.05, 0.71),
    ]) {
      final a = SplashAmbient.loopOffset(base, amp, phase, 0.0);
      final b = SplashAmbient.loopOffset(base, amp, phase, 1.0);
      expect((a - b).abs(), lessThan(1e-9));
    }
    // Mote cycle position: identical at t=0 and t=1. Speeds are integers by
    // construction (see _AmbientDot), so every mote lands where it started.
    for (final (speed, phase) in [
      (1.0, 0.2),
      (2.0, 0.9),
      (1.0, 0.05),
      (2.0, 0.0),
    ]) {
      final a = SplashAmbient.loopPhase(speed, phase, 0.0);
      final b = SplashAmbient.loopPhase(speed, phase, 1.0);
      expect((a - b).abs(), lessThan(1e-9));
    }
  });

  test('sheen is invisible at both ends of its loop', () {
    // The sweep never flashes at the wrap: alpha is exactly zero there, so
    // the band position at the ends is irrelevant.
    expect(BadgeHero.sheenAlpha(0.0), 0.0);
    expect(BadgeHero.sheenAlpha(1.0), 0.0);
    // …and the sweep is genuinely interior, not degenerate.
    expect(BadgeHero.sheenAlpha(0.23), greaterThan(0.0));
    expect(BadgeHero.sheenAlpha(0.23), lessThanOrEqualTo(0.18));
  });

  test('tagline and version stay >= 4.5:1 over the brightest blob wash', () {
    for (final isDark in [false, true]) {
      final p = isDark ? AppPalette.dark : AppPalette.light;
      for (final wash in SplashAmbient.blobWash(isDark)) {
        final washed = Color.alphaBlend(
          wash.color.withValues(alpha: wash.alpha),
          p.background,
        );
        // Conservative bound: the full blob peak alpha over the background,
        // exactly where the text sits.
        expect(
          _ratio(p.accentText, washed),
          greaterThan(4.5),
          reason: 'tagline on ${isDark ? 'dark' : 'light'} wash ${wash.color}',
        );
        expect(
          _ratio(p.textSecondary, washed),
          greaterThan(4.5),
          reason: 'caption on ${isDark ? 'dark' : 'light'} wash ${wash.color}',
        );
      }
    }
  });
}
