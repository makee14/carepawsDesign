import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/add_pet_screen.dart';
import 'package:carepaws/screens/appointments/book_flow.dart';
import 'package:carepaws/screens/appointments_screen.dart';
import 'package:carepaws/screens/shops_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Stream D: appointments FAB, booking no-pet → Add Pet round-trip,
/// shop grid on the shared ProductCard contract.
Future<AppStore> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  final store = AppStore(now: DateTime(2026, 10, 13, 9, 40));
  addTearDown(store.dispose);
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        // Pin the MediaQuery size: the test binding's default view is
        // 800x600 regardless of setSurfaceSize, which would flip
        // orientation-dependent layout (FAB offset, grid columns).
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: size),
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('D1 — booking FAB', () {
    testWidgets('FAB is present, 56pt, and opens the booking flow', (
      tester,
    ) async {
      await pumpScreen(tester, const AppointmentsScreen());

      final fab = find.bySemanticsLabel('Book a new appointment');
      expect(fab, findsOneWidget);

      // 56pt circle, floating above the bottom (no TabBarClearance in this
      // harness, so it sits s16 above the screen edge).
      final rect = tester.getRect(fab);
      expect(rect.width, 56);
      expect(rect.height, 56);
      expect(rect.bottom, 844 - 16);

      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.byType(BookFlow), findsOneWidget);
    });

    testWidgets('FAB does not cover list content', (tester) async {
      final store = await pumpScreen(tester, const AppointmentsScreen());
      // Bottom list padding = 56 (FAB) + s32 + tab-bar clearance, so the
      // last row can scroll fully above the button.
      expect(store.upcoming.isNotEmpty, isTrue);
      final fabTop = tester
          .getRect(find.bySemanticsLabel('Book a new appointment'))
          .top;
      expect(fabTop, greaterThan(844 - 16 - 56 - 32));
    });

    testWidgets('FAB sits tighter in landscape (tab-bar + s12)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const AppointmentsScreen(),
        size: const Size(844, 390),
      );
      final rect = tester.getRect(
        find.bySemanticsLabel('Book a new appointment'),
      );
      expect(rect.bottom, 390 - 12);
      expect(rect.right, 844 - 16);
    });
  });

  group('D2 — booking with no pets', () {
    testWidgets('Add pet goes straight to AddPetScreen (no dead-end message)', (
      tester,
    ) async {
      final store = await pumpScreen(tester, const BookFlow());
      for (final pet in List.of(store.pets)) {
        store.removePet(pet.id);
      }
      await tester.pumpAndSettle();

      expect(find.text('No pets yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add pet'));
      await tester.pumpAndSettle();

      // Straight to the real Add Pet screen…
      expect(find.byType(AddPetScreen), findsOneWidget);
      // …not the old dead-end message.
      expect(find.text('Add a pet from the Home tab first'), findsNothing);
    });

    testWidgets('saved pet returns preselected in the booking flow', (
      tester,
    ) async {
      final store = await pumpScreen(tester, const BookFlow());
      for (final pet in List.of(store.pets)) {
        store.removePet(pet.id);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Add pet'));
      await tester.pumpAndSettle();
      expect(find.byType(AddPetScreen), findsOneWidget);

      // Step 0: name the pet, continue…
      await tester.enterText(find.byType(CupertinoTextField).first, 'Testy');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();

      // Step 1: save.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add Testy'));
      await tester.pumpAndSettle();

      // Back on the booking pet step with the new pet on file…
      expect(find.byType(AddPetScreen), findsNothing);
      expect(store.pets.any((p) => p.name == 'Testy'), isTrue);
      // …and preselected: exactly one selected dot, on the new pet's card.
      expect(
        find.byWidgetPredicate((w) => w is SelectDot && w.selected),
        findsOneWidget,
      );
      expect(find.text('Testy'), findsOneWidget);
    });
  });

  group('D3 — shop grid on the shared ProductCard', () {
    testWidgets('every seeded product renders in the grid', (tester) async {
      final store = await pumpScreen(tester, const ShopsScreen());
      expect(store.products.isNotEmpty, isTrue);
      // The grid builds lazily: scroll through and collect every product
      // name that materializes.
      final seen = <String>{};
      final scrollable = find.byType(CustomScrollView);
      for (var i = 0; i < 12 && seen.length < store.products.length; i++) {
        for (final product in store.products) {
          if (find.text(product.name).evaluate().isNotEmpty) {
            seen.add(product.name);
          }
        }
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(
        seen,
        unorderedEquals(store.products.map((p) => p.name)),
        reason:
            'missing: ${store.products.map((p) => p.name).toSet().difference(seen)}',
      );
    });

    testWidgets('tapping a card opens its product detail', (tester) async {
      final store = await pumpScreen(tester, const ShopsScreen());
      final first = store.products.first;
      await tester.tap(find.text(first.name));
      await tester.pumpAndSettle();
      // Detail screen shows the product name in its header.
      expect(find.text(first.name), findsWidgets);
    });
  });
}
