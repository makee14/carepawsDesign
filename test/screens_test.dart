@Tags(['screenshots'])
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_artifact/app.dart';
import 'package:petcare_artifact/data/models.dart';
import 'package:petcare_artifact/design/theme.dart';
import 'package:petcare_artifact/screens/appointments/book_flow.dart';
import 'package:petcare_artifact/screens/chat_thread_screen.dart';
import 'package:petcare_artifact/screens/pets/pet_profile_screen.dart';
import 'package:petcare_artifact/screens/profile/about_screen.dart';
import 'package:petcare_artifact/screens/profile/privacy_screen.dart';
import 'package:petcare_artifact/screens/profile/settings_screens.dart';
import 'package:petcare_artifact/screens/shop/cart_screen.dart';
import 'package:petcare_artifact/screens/shop/checkout_screen.dart';
import 'package:petcare_artifact/screens/shop/order_success_screen.dart';
import 'package:petcare_artifact/screens/shop/orders_screen.dart';
import 'package:petcare_artifact/screens/shop/product_detail_screen.dart';
import 'package:petcare_artifact/screens/triage_screen.dart';
import 'package:petcare_artifact/services/ai_service.dart';
import 'package:petcare_artifact/state/app_store.dart';

/// Visual regression pass. Run with:
///
///   flutter test test/screens_test.dart --update-goldens
///
/// to (re)generate `test/goldens/*.png`, which is how every screen was visually
/// reviewed at iPhone dimensions.
Future<void> shot(WidgetTester tester, Widget screen, String name,
    {AppStore? store, Size size = const Size(390, 844), double scale = 1}) async {
  await tester.binding.setSurfaceSize(size);
  final s = store ?? AppStore(now: DateTime(2026, 10, 13, 15, 6));
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: screen,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
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

void main() {
  testWidgets('01 home', (t) => shot(t, const RootShell(), '01_home'));
  testWidgets('02 home scrolled', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -520));
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/02_home_scrolled.png'));
  });
  testWidgets('03 chats', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Chats').last);
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/03_chats.png'));
  });
  testWidgets('04 appointments', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Appointments').last);
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/04_appointments.png'));
  });
  testWidgets('05 shop', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Shop').last);
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/05_shop.png'));
  });
  testWidgets('06 profile', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/06_profile.png'));
  });
  testWidgets('07 pet profile', (t) => shot(t, const PetProfileScreen(petId: 'p1'), '07_pet_profile'));
  testWidgets('08 triage input', (t) => shot(t, const TriageScreen(), '08_triage_input'));
  testWidgets('09 emergency outcome', (t) async {
    // Drive the shared triage engine through the built-in responder so the
    // screenshot never depends on the network.
    final r = DemoAi.triage(
      'He collapsed and cannot breathe',
      petName: 'Biscuit',
      species: 'Golden Retriever',
      hasPhoto: false,
    );
    expect(r.route, TriageRoute.emergency);
    final s = seeded();
    await t.pumpWidget(
      AppScope(
        store: s,
        child: CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: EmergencyTriageView(result: r, pet: s.pets.first, entry: TriageEntry.home),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/09_triage_emergency.png'));
  });
  testWidgets('10 book flow step1', (t) => shot(t, const BookFlow(), '10_book_step1'));
  testWidgets('11 book review', (t) async {
    final s = seeded();
    await shot(t, const BookFlow(), '11_book_review', store: s);
  });
  testWidgets('12 product detail', (t) => shot(t, const ProductDetailScreen(productId: 'pr1'), '12_product_detail'));
  testWidgets('13 cart', (t) {
    final s = seeded()..addToCart('pr1')..addToCart('pr3', 2);
    return shot(t, const CartScreen(), '13_cart', store: s);
  });
  testWidgets('14 checkout', (t) {
    final s = seeded()..addToCart('pr1')..addToCart('pr3', 2);
    return shot(t, const CheckoutScreen(), '14_checkout', store: s);
  });
  testWidgets('15 order success', (t) => shot(t, const OrderSuccessScreen(orderId: 'o1'), '15_order_success'));
  testWidgets('16 orders', (t) => shot(t, const OrdersScreen(), '16_orders'));
  testWidgets('17 ai thread', (t) => shot(t, const ChatThreadScreen(threadId: 'th_ai'), '17_ai_thread'));
  testWidgets('18 clinic thread', (t) => shot(t, const ChatThreadScreen(threadId: 'th_clinic'), '18_clinic_thread'));
  testWidgets('19 privacy', (t) => shot(t, const PrivacyScreen(), '19_privacy'));
  testWidgets('20 about', (t) => shot(t, const AboutScreen(), '20_about'));
  testWidgets('21 settings', (t) => shot(t, const SettingsScreen(), '21_settings'));
  testWidgets('22 faq', (t) => shot(t, const FaqScreen(), '22_faq'));
  testWidgets('23 AX5 home', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const RootShell(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
      ),
    ));
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/23_home_ax5.png'));
  });
  testWidgets('24 landscape home', (t) async {
    await t.binding.setSurfaceSize(const Size(844, 390));
    final s = seeded();
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.light), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/24_landscape_home.png'));
  });

  // The floating tab bar and the sticky CTA are both glass, so the dark
  // palette needs its own reference — a tint that reads well on cream can be
  // invisible on espresso.
  testWidgets('25 dark home', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    final s = seeded();
    s.darkMode = true;
    await t.pumpWidget(AppScope(
      store: s,
      child: CupertinoApp(theme: themeFor(AppPalette.dark), home: const RootShell()),
    ));
    await t.pumpAndSettle();
    await expectLater(find.byType(CupertinoApp), matchesGoldenFile('goldens/25_dark_home.png'));
  });
}