@Tags(['screenshots'])
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/appointments/book_flow.dart';
import 'package:carepaws/screens/chat_thread_screen.dart';
import 'package:carepaws/screens/onboarding_screen.dart';
import 'package:carepaws/screens/pets/pet_profile_screen.dart';
import 'package:carepaws/screens/profile/about_screen.dart';
import 'package:carepaws/screens/profile/privacy_screen.dart';
import 'package:carepaws/screens/profile/settings_screens.dart';
import 'package:carepaws/screens/shop/cart_screen.dart';
import 'package:carepaws/screens/shop/checkout_screen.dart';
import 'package:carepaws/screens/shop/order_success_screen.dart';
import 'package:carepaws/screens/shop/orders_screen.dart';
import 'package:carepaws/screens/shop/product_detail_screen.dart';
import 'package:carepaws/screens/triage_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Visual regression pass. Run with:
///
///   flutter test test/screens_test.dart --update-goldens
///
/// to (re)generate `test/goldens/*.png`, which is how every screen was visually
/// reviewed at iPhone dimensions.
Future<void> shot(
  WidgetTester tester,
  Widget screen,
  String name, {
  AppStore? store,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  final s = store ?? AppStore(now: DateTime(2026, 10, 13, 15, 6));
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: screen,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(CupertinoApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

AppStore seeded() => AppStore(now: DateTime(2026, 10, 13, 15, 6));

/// Fake AI backend for the health-check goldens — screenshots never depend
/// on the network or an API key.
class _ShotAi extends AiService {
  _ShotAi(this.canned) {
    status = AiStatus.live;
  }
  final TriageResult canned;

  @override
  Future<TriageResult> triage({
    required String petName,
    required String species,
    required String text,
    Uint8List? photo,
    String? photoMime,
    String ownerFirstName = '',
  }) async => canned;
}

/// Number of question steps in the health-check flow (mirrors the private
/// `_questions` list in triage_screen.dart).
const _healthQuestionCount = 4;

TriageResult _shotTriage() => const TriageResult(
  route: TriageRoute.homeCare,
  title: 'Mild stomach upset',
  summary: 'This looks like a mild, short-lived stomach upset.',
  urgency: 0,
  bullets: ['Ate something unusual'],
  redFlags: ['Repeated vomiting'],
  homeCare: ['Offer small sips of water'],
);

TriageResult _shotTriageUrgent() => const TriageResult(
  route: TriageRoute.emergency,
  title: 'Possible emergency — see Biscuit now',
  summary: 'What you described can be life-threatening within hours.',
  urgency: 2,
  bullets: ['Difficulty breathing needs hands-on assessment'],
  redFlags: ['Laboured breathing or blue/pale gums'],
);

/// Walks the stepped health-check flow: picks Biscuit at step 0, answers
/// [answerSteps] questions with the first option each, and optionally runs
/// the check to land on the results screen.
Future<void> _pumpHealthFlow(
  WidgetTester t,
  TriageResult canned, {
  int answerSteps = 0,
  bool run = false,
  bool dark = false,
}) async {
  await t.binding.setSurfaceSize(const Size(390, 844));
  final s = AppStore(ai: _ShotAi(canned), now: DateTime(2026, 10, 13, 15, 6));
  await t.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(dark ? AppPalette.dark : AppPalette.light),
        home: const TriageScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Biscuit'));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(PrimaryButton, 'Continue'));
  await t.pumpAndSettle();
  final steps = run ? _healthQuestionCount : answerSteps;
  for (var i = 0; i < steps; i++) {
    await t.tap(find.byType(PressScale).first);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await t.pumpAndSettle();
  }
  if (run) {
    await t.tap(find.widgetWithText(PrimaryButton, 'Run health check'));
    await t.pumpAndSettle();
  }
}

void main() {
  testWidgets('01 home', (t) => shot(t, const RootShell(), '01_home'));
  testWidgets('02 home scrolled', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -520));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/02_home_scrolled.png'),
    );
  });
  testWidgets('03 chats', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Chats').last);
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/03_chats.png'),
    );
  });
  testWidgets('04 appointments', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Appointments').last);
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/04_appointments.png'),
    );
  });
  testWidgets('05 shop', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Shop').last);
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/05_shop.png'),
    );
  });
  testWidgets('06 profile', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/06_profile.png'),
    );
  });
  testWidgets(
    '07 pet profile',
    (t) => shot(t, const PetProfileScreen(petId: 'p1'), '07_pet_profile'),
  );
  testWidgets(
    '08 health check pet step',
    (t) => shot(t, const TriageScreen(), '08_health_pet_step'),
  );

  /// Fake AI backend so the golden never depends on the network or an API
  /// key. Defined here (not imported) because test files stay self-contained.
  testWidgets('08b health check question step', (t) async {
    await _pumpHealthFlow(t, _shotTriage(), answerSteps: 1);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/08b_health_question.png'),
    );
  });
  testWidgets('09 health check results urgent', (t) async {
    await _pumpHealthFlow(t, _shotTriageUrgent(), run: true);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/09_health_results_urgent.png'),
    );
  });
  testWidgets('09b health check results low', (t) async {
    await _pumpHealthFlow(t, _shotTriage(), run: true);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/09b_health_results_low.png'),
    );
  });
  testWidgets('09c health check results expanded', (t) async {
    await _pumpHealthFlow(t, _shotTriage(), run: true);
    await t.tap(find.text('Possible causes'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/09c_health_results_expanded.png'),
    );
  });
  testWidgets('09d health check results dark', (t) async {
    await _pumpHealthFlow(t, _shotTriageUrgent(), run: true, dark: true);
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/09d_health_results_dark.png'),
    );
  });
  testWidgets(
    '10 book flow step1',
    (t) => shot(t, const BookFlow(), '10_book_step1'),
  );
  testWidgets('11 book review', (t) async {
    final s = seeded();
    await shot(t, const BookFlow(), '11_book_review', store: s);
  });
  testWidgets(
    '12 product detail',
    (t) => shot(
      t,
      const ProductDetailScreen(productId: 'pr1'),
      '12_product_detail',
    ),
  );
  testWidgets('13 cart', (t) {
    final s = seeded()
      ..addToCart('pr1')
      ..addToCart('pr3', 2);
    return shot(t, const CartScreen(), '13_cart', store: s);
  });
  testWidgets('14 checkout', (t) {
    final s = seeded()
      ..addToCart('pr1')
      ..addToCart('pr3', 2);
    return shot(t, const CheckoutScreen(), '14_checkout', store: s);
  });
  testWidgets(
    '15 order success',
    (t) => shot(t, const OrderSuccessScreen(orderId: 'o1'), '15_order_success'),
  );
  testWidgets('16 orders', (t) => shot(t, const OrdersScreen(), '16_orders'));
  testWidgets(
    '17 ai thread',
    (t) => shot(t, const ChatThreadScreen(threadId: 'th_ai'), '17_ai_thread'),
  );
  testWidgets(
    '18 clinic thread',
    (t) => shot(
      t,
      const ChatThreadScreen(threadId: 'th_clinic'),
      '18_clinic_thread',
    ),
  );
  testWidgets(
    '19 privacy',
    (t) => shot(t, const PrivacyScreen(), '19_privacy'),
  );
  testWidgets('20 about', (t) => shot(t, const AboutScreen(), '20_about'));
  testWidgets(
    '21 settings',
    (t) => shot(t, const SettingsScreen(), '21_settings'),
  );
  testWidgets('22 faq', (t) => shot(t, const FaqScreen(), '22_faq'));
  testWidgets('23 AX5 home', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/23_home_ax5.png'),
    );
  });
  testWidgets('24 landscape home', (t) async {
    await t.binding.setSurfaceSize(const Size(844, 390));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/24_landscape_home.png'),
    );
  });

  // The floating tab bar and the sticky CTA are both glass, so the dark
  // palette needs its own reference — a tint that reads well on cream can be
  // invisible on espresso.
  testWidgets('25 dark home', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    s.darkMode = true;
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.dark),
          home: const RootShell(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/25_dark_home.png'),
    );
  });

  // Onboarding illustrations are all custom painting/animation, so each of the
  // five settled pages gets a reference, plus dark / AX5 / landscape variants
  // of the most layout-sensitive pages.
  testWidgets(
    '26 onboarding welcome',
    (t) => onboardingShot(t, '26_onboarding_welcome', 0),
  );
  testWidgets(
    '27 onboarding ai check',
    (t) => onboardingShot(t, '27_onboarding_ai', 1),
  );
  testWidgets(
    '28 onboarding booking',
    (t) => onboardingShot(t, '28_onboarding_booking', 2),
  );
  testWidgets(
    '29 onboarding chat',
    (t) => onboardingShot(t, '29_onboarding_chat', 3),
  );
  testWidgets(
    '30 onboarding shop',
    (t) => onboardingShot(t, '30_onboarding_shop', 4),
  );
  testWidgets('31 dark onboarding welcome', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    s.darkMode = true;
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.dark),
          home: OnboardingScreen(onDone: () {}),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/31_onboarding_dark.png'),
    );
  });
  testWidgets('32 onboarding welcome ax5', (t) async {
    // 3.2 is the app's real maximum: main.dart clamps the text scaler there,
    // so this is the true AX worst case, not the abstract 5.0.
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: OnboardingScreen(onDone: () {}),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/32_onboarding_ax5.png'),
    );
  });
  testWidgets('33 landscape onboarding booking', (t) async {
    await t.binding.setSurfaceSize(const Size(844, 390));
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: OnboardingScreen(onDone: () {}),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/33_onboarding_landscape.png'),
    );
  });
}

/// Pumps the onboarding flow and advances [pages] pages via Continue, then
/// captures the settled illustration.
Future<void> onboardingShot(WidgetTester tester, String name, int pages) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: seeded(),
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: OnboardingScreen(onDone: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (var i = 0; i < pages; i++) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
  await expectLater(
    find.byType(CupertinoApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}
