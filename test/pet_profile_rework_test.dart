import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/edit_pet_screen.dart';
import 'package:carepaws/screens/pets/pet_profile_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Pet profile rework: banner stats strip, deduped Details, Pet ID card,
/// optional height/length measurements on the model + edit screen.
AppStore seedStore() {
  SharedPreferences.setMockInitialValues({});
  return AppStore(now: DateTime(2026, 10, 13, 15, 6));
}

Future<void> pumpProfile(WidgetTester tester, AppStore store) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const PetProfileScreen(petId: 'p1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The field belonging to a `_Labeled` row: the CupertinoTextField inside
/// the label's nearest Column ancestor. Robust against the form ListView's
/// lazy building (no index hunting).
Finder fieldFor(String label) {
  final labeled = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first;
  return find.descendant(
    of: labeled,
    matching: find.byType(CupertinoTextField),
  );
}

Future<void> enterLabeled(
  WidgetTester tester,
  String label,
  String value,
) async {
  await tester.scrollUntilVisible(
    find.text(label),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.enterText(fieldFor(label), value);
  await tester.pumpAndSettle();
}

/// A Biscuit with the optional measurements filled in.
Pet measuredPet(Pet p) => Pet(
  id: p.id,
  name: p.name,
  species: p.species,
  breed: p.breed,
  sex: p.sex,
  birthDate: p.birthDate,
  weightKg: p.weightKg,
  heightCm: 25,
  lengthCm: 40,
  color: p.color,
  microchip: p.microchip,
  allergies: p.allergies,
  vitals: p.vitals,
  timeline: p.timeline,
  docs: p.docs,
);

/// A Biscuit with the optional measurements cleared (null = never recorded).
Pet unmeasuredPet(Pet p) => Pet(
  id: p.id,
  name: p.name,
  species: p.species,
  breed: p.breed,
  sex: p.sex,
  birthDate: p.birthDate,
  weightKg: p.weightKg,
  heightCm: null,
  lengthCm: null,
  color: p.color,
  microchip: p.microchip,
  allergies: p.allergies,
  vitals: p.vitals,
  timeline: p.timeline,
  docs: p.docs,
);

void main() {
  group('petCode', () {
    test('is a stable CP-XXXXXX code', () {
      final store = seedStore();
      final code = store.pet('p1')!.petCode;
      expect(code, matches(RegExp(r'^CP-[0-9A-Z]{6}$')));
      expect(store.pet('p1')!.petCode, code);
      expect(store.pet('p2')!.petCode, isNot(code));
    });
  });

  group('banner stats strip', () {
    testWidgets('weight tile always; height/length hidden when null', (
      tester,
    ) async {
      final store = seedStore();
      // Biscuit's seed data now includes measurements; use a cleared copy to
      // exercise the null-hiding behavior.
      store.pets = [unmeasuredPet(store.pet('p1')!)];
      await pumpProfile(tester, store);
      // Weight tile is in the banner (value also appears in the vitals
      // grid, so just require presence).
      expect(find.text('31.4 kg'), findsWidgets);
      expect(find.text('Weight'), findsWidgets);
      // Null measurements leave no tile and no invented data.
      expect(find.text('Height'), findsNothing);
      expect(find.text('Length'), findsNothing);
    });

    testWidgets('height/length tiles appear when set', (tester) async {
      final store = seedStore();
      store.pets = [measuredPet(store.pet('p1')!), store.pet('p2')!];
      await pumpProfile(tester, store);
      expect(find.text('25.0 cm'), findsOneWidget);
      expect(find.text('40.0 cm'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Length'), findsOneWidget);
    });
  });

  group('details dedupe', () {
    testWidgets('each fact appears once; Pet ID row replaces Microchip', (
      tester,
    ) async {
      final store = seedStore();
      final code = store.pet('p1')!.petCode;
      await pumpProfile(tester, store);
      // Scroll to the last Details row so the whole card is built.
      await tester.scrollUntilVisible(
        find.text('Allergies'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Breed'), findsNothing);
      expect(find.text('Sex'), findsNothing);
      expect(find.text('Microchip'), findsNothing);
      expect(find.text('Pet ID'), findsOneWidget);
      expect(find.text(code), findsOneWidget);
      expect(find.text('Born'), findsOneWidget);
      expect(find.text('Allergies'), findsOneWidget);
    });

    testWidgets('tapping Pet ID opens the ID card', (tester) async {
      final store = seedStore();
      final pet = store.pet('p1')!;
      await pumpProfile(tester, store);
      await tester.scrollUntilVisible(
        find.text('Pet ID'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pet ID'));
      await tester.pumpAndSettle();
      // The digital ID card: photo label, name, code, breed, sex.
      expect(find.text(pet.name), findsWidgets);
      expect(find.text(pet.petCode), findsWidgets);
      expect(find.text('${pet.breed} · ${pet.sex}'), findsOneWidget);
      // The sheet scrolls rather than overflowing — bring Done into view.
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text(pet.petCode), findsOneWidget); // card closed
    });
  });

  group('edit pet measurements', () {
    testWidgets('height/length fields save to the pet', (tester) async {
      final store = seedStore();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const EditPetScreen(petId: 'p1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterLabeled(tester, 'Height (cm)', '25');
      await enterLabeled(tester, 'Length (cm)', '40');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.pet('p1')!.heightCm, 25);
      expect(store.pet('p1')!.lengthCm, 40);
    });

    testWidgets('leaving them empty keeps null', (tester) async {
      final store = seedStore();
      // Seed Biscuit now carries measurements; clear them to test the
      // empty-means-null path.
      store.pets = [unmeasuredPet(store.pet('p1')!)];
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const EditPetScreen(petId: 'p1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.pet('p1')!.heightCm, isNull);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.pet('p1')!.heightCm, isNull);
      expect(store.pet('p1')!.lengthCm, isNull);
    });
  });

  group('edit screen AX5 (caught by the visual sweep)', () {
    Future<void> pumpEditAX5(WidgetTester tester) async {
      final store = seedStore();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const EditPetScreen(petId: 'p1'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(3.2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('save button grows instead of clipping its label', (
      tester,
    ) async {
      await pumpEditAX5(tester);
      // The two-line AX5 label must fit: the button grows past its 54pt 1x
      // height instead of ellipsizing "Save changes".
      final box = find
          .descendant(
            of: find.byType(PrimaryButton),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(box).height, greaterThan(54));
      expect(tester.takeException(), isNull);
    });

    testWidgets('field hint drops below the label, no mid-word wrap', (
      tester,
    ) async {
      await pumpEditAX5(tester);
      await tester.scrollUntilVisible(
        find.text('Breed'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // The hint wraps onto its own line under the label (Wrap) instead of
      // squeezing the label into "Bree/d".
      final labelDy = tester.getTopLeft(find.text('Breed')).dy;
      final hintDy = tester.getTopLeft(find.text('Type any breed')).dy;
      expect(hintDy, greaterThan(labelDy + 10));
      expect(tester.takeException(), isNull);
    });
  });
}
