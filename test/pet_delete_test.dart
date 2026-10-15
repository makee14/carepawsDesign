import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/pets/pet_profile_screen.dart';
import 'package:carepaws/state/app_store.dart';

/// Delete-pet flow (S5, gap #6): danger-zone row on the pet profile,
/// confirmDestructive stating the blast radius (incl. upcoming appointments),
/// cancel of the pet's active appointments via the existing cancel path,
/// then store.removePet, then pop back — never a dead end.
Future<AppStore> pumpProfile(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(now: DateTime(2026, 10, 13, 15, 6));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open profile'),
                onPressed: () =>
                    Navigator.of(context)
                        .push(appRoute(const PetProfileScreen(petId: 'p1'))),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open profile'));
  await tester.pumpAndSettle();
  expect(find.byType(PetProfileScreen), findsOneWidget);
  return store;
}

/// Scrolls the profile list until the delete row is built and visible, then
/// taps it. (ListView builds children lazily, so the below-fold row needs an
/// explicit scroll before it exists in the tree.)
Future<void> openDeleteConfirm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Delete Biscuit'),
    600,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete Biscuit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('delete row shows a confirm stating the blast radius', (
    tester,
  ) async {
    final store = await pumpProfile(tester);
    await openDeleteConfirm(tester);

    // The action sheet states what goes away, including the appointment.
    expect(find.text('Delete Biscuit?'), findsOneWidget);
    expect(
      find.textContaining('upcoming appointment', findRichText: true),
      findsWidgets,
    );
    expect(store.pet('p1'), isNotNull);
  });

  testWidgets('confirm deletes the pet and cancels its appointments', (
    tester,
  ) async {
    final store = await pumpProfile(tester);
    expect(store.pet('p1'), isNotNull);
    final appt = store.appointments.firstWhere((a) => a.id == 'a1');
    expect(appt.status, ApptStatus.confirmed);

    await openDeleteConfirm(tester);
    // The destructive action in the sheet shares its label with the row;
    // the sheet's copy is the last one in the tree.
    await tester.tap(find.text('Delete Biscuit').last);
    await tester.pumpAndSettle();

    expect(store.pet('p1'), isNull);
    expect(
      store.appointments.firstWhere((a) => a.id == 'a1').status,
      ApptStatus.cancelled,
    );
    // The other pet and its appointment are untouched.
    expect(store.pet('p2'), isNotNull);
    expect(
      store.appointments.firstWhere((a) => a.id == 'a2').status,
      ApptStatus.booked,
    );
    // Popped back — never a dead end.
    expect(find.byType(PetProfileScreen), findsNothing);
  });

  testWidgets('cancel keeps the pet and its appointments', (tester) async {
    final store = await pumpProfile(tester);
    await openDeleteConfirm(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(store.pet('p1'), isNotNull);
    expect(
      store.appointments.firstWhere((a) => a.id == 'a1').status,
      ApptStatus.confirmed,
    );
    expect(find.byType(PetProfileScreen), findsOneWidget);
  });
}
