import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/screens/onboarding_illustrations.dart';
import 'package:carepaws/screens/onboarding_screen.dart';
import 'package:carepaws/screens/profile/settings_screens.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding flow tests.
///
/// `completeFirstLaunch()` writes to SharedPreferences, whose async getter
/// never resolves under the fake test clock — mock values are mandatory.
Future<void> pumpOnboarding(
  WidgetTester t, {
  AppStore? store,
  bool reduceMotion = false,
  VoidCallback? onDone,
}) async {
  SharedPreferences.setMockInitialValues({});
  final s = store ?? AppStore();
  if (reduceMotion) s.reduceMotionOverride = true;
  await t.binding.setSurfaceSize(const Size(390, 844));
  await t.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(home: OnboardingScreen(onDone: onDone ?? () {})),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> pumpIllustration(
  WidgetTester t,
  Widget illustration, {
  bool reduceMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore();
  if (reduceMotion) s.reduceMotionOverride = true;
  await t.binding.setSurfaceSize(const Size(390, 844));
  await t.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(home: Center(child: illustration)),
    ),
  );
}

void main() {
  testWidgets(
    'completing the tour calls onDone (flag is set at Home, not here)',
    (t) async {
      var done = false;
      final store = AppStore();
      await pumpOnboarding(t, store: store, onDone: () => done = true);

      for (var i = 0; i < 4; i++) {
        await t.tap(find.text('Continue'));
        await t.pumpAndSettle();
      }
      expect(find.text('Get started'), findsOneWidget);
      await t.tap(find.text('Get started'));
      await t.pumpAndSettle();

      expect(done, isTrue);
      // Finishing the tour does not complete the first-launch flow —
      // registration is still pending, so the flag stays unset.
      expect(store.onboardingCompleted, isFalse);
    },
  );

  testWidgets('Skip ends the tour immediately', (t) async {
    var done = false;
    final store = AppStore();
    await pumpOnboarding(t, store: store, onDone: () => done = true);

    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();

    expect(done, isTrue);
    expect(store.onboardingCompleted, isFalse);
  });

  testWidgets('swiping re-triggers the entering page entrance', (t) async {
    await pumpOnboarding(t);
    // Page 2's illustration is built lazily; swipe to it and it must animate
    // to its settled state (badge '1' visible on the shop page).
    for (var i = 0; i < 4; i++) {
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
    }
    expect(find.byType(ShopIntro), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('replay from Help opens the tour', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(
      AppScope(
        store: AppStore(),
        child: const CupertinoApp(home: HelpScreen()),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Take the tour again'));
    await t.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(PawIntro), findsOneWidget);
  });

  group('reduced motion renders the final state on the first frame', () {
    testWidgets('paw sparkles', (t) async {
      await pumpIllustration(t, const PawIntro(), reduceMotion: true);
      // One frame only — no pumpAndSettle.
      await t.pump();
      final dots = t.widget<Opacity>(find.byKey(const ValueKey('paw-dots')));
      expect(dots.opacity, 1.0);
    });

    testWidgets('AI orb question bubble', (t) async {
      await pumpIllustration(t, const AiOrbIntro(), reduceMotion: true);
      await t.pump();
      expect(
        find.text('Biscuit\u2019s limping \u2014 is this urgent?'),
        findsOneWidget,
      );
    });

    testWidgets('booking date + time chip', (t) async {
      await pumpIllustration(t, const BookIntro(), reduceMotion: true);
      await t.pump();
      final date = t.widget<Opacity>(
        find.descendant(
          of: find.byKey(const ValueKey('book-date')),
          matching: find.byType(Opacity),
        ),
      );
      expect(date.opacity, 1.0);
      expect(find.text('Wed \u00b7 10:30 AM'), findsOneWidget);
    });

    testWidgets('chat reply text resolved', (t) async {
      await pumpIllustration(t, const ChatIntro(), reduceMotion: true);
      await t.pump();
      final reply = t.widget<Opacity>(find.byKey(const ValueKey('chat-text')));
      expect(reply.opacity, 1.0);
      expect(find.text('2:30 PM works \u2014 see you then!'), findsOneWidget);
    });

    testWidgets('shop badge', (t) async {
      await pumpIllustration(t, const ShopIntro(), reduceMotion: true);
      await t.pump();
      final badge = t.widget<Opacity>(
        find.descendant(
          of: find.byKey(const ValueKey('shop-badge')),
          matching: find.byType(Opacity),
        ),
      );
      expect(badge.opacity, 1.0);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('full tour settles with no pending timers', (t) async {
      await pumpOnboarding(t, reduceMotion: true);
      for (var i = 0; i < 4; i++) {
        await t.tap(find.text('Continue'));
        await t.pumpAndSettle();
      }
      // Tear-down asserts zero pending timers; reaching here green means the
      // one-shot timelines left nothing behind.
      expect(find.byType(ShopIntro), findsOneWidget);
    });
  });
}
