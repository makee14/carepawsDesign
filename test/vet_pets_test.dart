import 'package:carepaws/data/models.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/vet/medical_entry_screen.dart';
import 'package:carepaws/screens/vet/vet_pets_screen.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 6 — vet pets screen (search + medical write). Written before the
/// implementation (RED first).
///
/// Pins the spec: the vet searches customers and pets (case-insensitive,
/// partial), opens a pet's full history (timeline, vitals, documents,
/// prescriptions), and writes new medical records. Every write carries an
/// audit trail — staff_id + timestamp, stamped by the store method itself
/// (never by the caller) — so a write without an audit entry is a failure.
DateTime _now() => DateTime(2026, 10, 17, 9, 30);

AppStore _store() {
  final s = AppStore(now: _now());
  addTearDown(s.dispose);
  return s;
}

Future<void> _signInVet(AppStore s) async {
  final err = await AuthStore.register(
    name: 'Dr. Rafael Alvarez',
    email: 'vet@carepaws.test',
    password: 'vetpass123',
    role: 'vet',
  );
  assert(err == null, err);
  expect(await s.signIn('vet@carepaws.test', 'vetpass123'), isTrue);
  // A registered account starts with a clean slate (B15); reseed the
  // patient roster so the vet has records to work with in tests.
  s.pets = Seed.pets;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('vet patient search', () {
    test('finds pets by name, case-insensitive and partial', () {
      final s = _store();
      final entries = buildVetPatients(s);
      expect(filterVetPatients(entries, 'bis').map((e) => e.pet.name), [
        'Biscuit',
      ]);
      expect(filterVetPatients(entries, 'MOCHI'), hasLength(1));
      expect(filterVetPatients(entries, 'och').map((e) => e.pet.name), [
        'Mochi',
      ]);
    });

    test('finds pets by customer name, case-insensitive and partial', () {
      final s = _store();
      // Seed owner: 'Marco Dela Cruz'.
      final hits = filterVetPatients(buildVetPatients(s), 'marco');
      expect(hits, hasLength(s.pets.length));
      expect(
        filterVetPatients(buildVetPatients(s), 'DELA'),
        hasLength(s.pets.length),
      );
    });

    test('empty query returns every patient; no match returns none', () {
      final s = _store();
      final entries = buildVetPatients(s);
      expect(filterVetPatients(entries, ''), hasLength(entries.length));
      expect(filterVetPatients(entries, '   '), hasLength(entries.length));
      expect(filterVetPatients(entries, 'zzz-no-such-patient'), isEmpty);
    });

    test('patient entries carry the customer name and the pet', () {
      final s = _store();
      final entries = buildVetPatients(s);
      expect(entries, hasLength(s.pets.length));
      for (final e in entries) {
        expect(e.customerName, isNotEmpty);
        expect(e.pet.id, isNotEmpty);
      }
    });
  });

  group('medical writes', () {
    test('vet can add a timeline entry to a pet\'s history', () async {
      final s = _store();
      await _signInVet(s);
      final before = s.pet('p1')!.timeline.length;
      expect(
        s.addTimelineEntry(
          petId: 'p1',
          title: 'Annual vaccination',
          detail: 'Rabies + DHPP boosters given.',
        ),
        isTrue,
      );
      final timeline = s.pet('p1')!.timeline;
      expect(timeline.length, before + 1);
      expect(timeline.first.title, 'Annual vaccination');
    });

    test('timeline write on an unknown pet fails and changes nothing', () {
      final s = _store();
      final before = s.pet('p1')!.timeline.length;
      expect(
        s.addTimelineEntry(petId: 'nope', title: 'x', detail: 'y'),
        isFalse,
      );
      expect(s.pet('p1')!.timeline.length, before);
    });

    test('vet can record vitals', () async {
      final s = _store();
      await _signInVet(s);
      expect(
        s.recordVitals(
          petId: 'p1',
          vitals: const [
            Vital(label: 'Weight', value: '32.0', unit: 'kg', icon: 'scale'),
            Vital(
              label: 'Temperature',
              value: '38.6',
              unit: '°C',
              icon: 'fire',
            ),
          ],
        ),
        isTrue,
      );
      final vitals = s.pet('p1')!.vitals;
      expect(vitals.firstWhere((v) => v.label == 'Weight').value, '32.0');
      // A partial update keeps the untouched readings.
      expect(vitals.any((v) => v.label == 'Heart rate'), isTrue);
      // A brand-new label is appended.
      expect(
        s.recordVitals(
          petId: 'p1',
          vitals: const [
            Vital(
              label: 'Respiratory rate',
              value: '24',
              unit: 'breaths/min',
              icon: 'lungs',
            ),
          ],
        ),
        isTrue,
      );
      expect(
        s
            .pet('p1')!
            .vitals
            .any((v) => v.label == 'Respiratory rate' && v.value == '24'),
        isTrue,
      );
    });

    test('vitals write on an unknown pet fails and changes nothing', () {
      final s = _store();
      final before = s.pet('p1')!.vitals.length;
      expect(
        s.recordVitals(
          petId: 'nope',
          vitals: const [
            Vital(label: 'Weight', value: '1', unit: 'kg', icon: 'scale'),
          ],
        ),
        isFalse,
      );
      expect(s.pet('p1')!.vitals.length, before);
    });

    test(
      'vet can issue a prescription — it lands in the customer\'s record',
      () async {
        final s = _store();
        await _signInVet(s);
        final before = s.prescriptions.length;
        expect(
          s.issuePrescription(
            productId: 'pr6',
            refills: 2,
            validFor: const Duration(days: 365),
          ),
          isTrue,
        );
        // The customer reads this exact list at Profile → Prescriptions, so
        // the new script flows straight into the customer's record.
        expect(s.prescriptions.length, before + 1);
        final rx = s.prescriptions.last;
        expect(rx.productId, 'pr6');
        expect(rx.vetName, 'Dr. Rafael Alvarez');
        expect(rx.refills, 2);
        expect(s.productOf(rx.productId).name, isNotEmpty);
        expect(rx.activeAt(_now()), isTrue);
      },
    );

    test(
      'issuing a prescription for a non-restricted product fails and changes nothing',
      () async {
        final s = _store();
        await _signInVet(s);
        final before = s.prescriptions.length;
        expect(
          s.issuePrescription(
            productId: 'pr1', // Grass-fed Lamb — not a restricted product.
            refills: 1,
            validFor: const Duration(days: 90),
          ),
          isFalse,
        );
        expect(s.prescriptions.length, before);
      },
    );

    test(
      'issuing a prescription for an unknown product fails and changes nothing',
      () {
        final s = _store();
        final before = s.prescriptions.length;
        expect(
          s.issuePrescription(
            productId: 'nope',
            refills: 1,
            validFor: const Duration(days: 90),
          ),
          isFalse,
        );
        expect(s.prescriptions.length, before);
      },
    );

    test('vet can attach a document reference', () async {
      final s = _store();
      await _signInVet(s);
      final before = s.pet('p2')!.docs.length;
      expect(
        s.addDocument(
          petId: 'p2',
          name: 'Blood panel 2026.pdf',
          kind: 'Lab result',
          size: 184320,
        ),
        isTrue,
      );
      final docs = s.pet('p2')!.docs;
      expect(docs.length, before + 1);
      expect(
        docs.firstWhere((d) => d.name == 'Blood panel 2026.pdf').kind,
        'Lab result',
      );
    });

    test('document write on an unknown pet fails and changes nothing', () {
      final s = _store();
      final before = s.pet('p2')!.docs.length;
      expect(
        s.addDocument(petId: 'nope', name: 'x.pdf', kind: 'Lab result'),
        isFalse,
      );
      expect(s.pet('p2')!.docs.length, before);
    });
  });

  group('audit trail — every write stamps staff_id + timestamp', () {
    test('timeline entry stamps the signed-in vet\'s staff_id', () async {
      final s = _store();
      await _signInVet(s);
      s.addTimelineEntry(petId: 'p1', title: 'Checkup', detail: 'All clear.');
      final e = s.pet('p1')!.timeline.first;
      expect(e.staffId, 'vet@carepaws.test');
      expect(e.staffName, 'Dr. Rafael Alvarez');
      expect(e.recordedAt, isNotNull);
      expect(e.recordedAt!.difference(_now()).inSeconds.abs(), lessThan(10));
    });

    test('vitals write stamps every recorded reading', () async {
      final s = _store();
      await _signInVet(s);
      s.recordVitals(
        petId: 'p1',
        vitals: const [
          Vital(label: 'Weight', value: '32.0', unit: 'kg', icon: 'scale'),
        ],
      );
      final w = s.pet('p1')!.vitals.firstWhere((v) => v.label == 'Weight');
      expect(w.staffId, 'vet@carepaws.test');
      expect(w.recordedAt, isNotNull);
      expect(w.recordedAt!.difference(_now()).inSeconds.abs(), lessThan(10));
    });

    test(
      'prescription stamps staff_id; issued is the audit timestamp',
      () async {
        final s = _store();
        await _signInVet(s);
        s.issuePrescription(
          productId: 'pr6',
          refills: 1,
          validFor: const Duration(days: 90),
        );
        final rx = s.prescriptions.last;
        expect(rx.staffId, 'vet@carepaws.test');
        expect(rx.issued, _now());
      },
    );

    test('document write stamps the signed-in vet\'s staff_id', () async {
      final s = _store();
      await _signInVet(s);
      s.addDocument(
        petId: 'p2',
        name: 'X-ray report.pdf',
        kind: 'X-ray',
        size: 92160,
      );
      final d = s
          .pet('p2')!
          .docs
          .firstWhere((x) => x.name == 'X-ray report.pdf');
      expect(d.staffId, 'vet@carepaws.test');
      expect(d.recordedAt, isNotNull);
      expect(d.recordedAt!.difference(_now()).inSeconds.abs(), lessThan(10));
    });

    test('a write with nobody signed in still stamps an audit entry', () {
      // The audit trail is unconditional: a write without an audit entry is
      // a failure, even in a dev session with no login.
      final s = _store();
      expect(s.signedIn, isFalse);
      s.addTimelineEntry(petId: 'p1', title: 'Checkup', detail: 'All clear.');
      final e = s.pet('p1')!.timeline.first;
      expect(e.staffId, isNotNull);
      expect(e.staffId, isNotEmpty);
      expect(e.recordedAt, isNotNull);
    });
  });

  group('pets screen', () {
    Future<void> pumpPets(WidgetTester tester, AppStore s) async {
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const VetPetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the search field and one row per patient', (
      tester,
    ) async {
      final s = _store();
      await pumpPets(tester, s);
      expect(find.text('Search customers or pets'), findsOneWidget);
      for (final p in s.pets) {
        expect(find.text(p.name, skipOffstage: false), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('search narrows the list, case-insensitive', (tester) async {
      final s = _store();
      await pumpPets(tester, s);
      await tester.enterText(find.byType(CupertinoSearchTextField), 'MOCHI');
      await tester.pumpAndSettle();
      expect(find.text('Mochi'), findsOneWidget);
      expect(find.text('Biscuit'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a patient opens its full history with audit info', (
      tester,
    ) async {
      final s = _store();
      // Seed history predates the audit trail; add one vet-written entry so
      // the audit line has something to show.
      s.addTimelineEntry(petId: 'p1', title: 'Checkup', detail: 'All clear.');
      await pumpPets(tester, s);
      await tester.tap(find.text('Biscuit'));
      await tester.pumpAndSettle();
      // Still near the top: the Add record action and the audit line on the
      // newest (just-written) timeline entry.
      expect(find.text('Add record'), findsOneWidget);
      expect(
        find.textContaining('Recorded by', skipOffstage: false),
        findsWidgets,
      );
      // The detail's SliverList builds lazily and garbage-collects
      // scrolled-off children — scroll to each section and assert it there.
      for (final section in [
        'Timeline',
        'Vitals',
        'Documents',
        'Prescriptions',
      ]) {
        await tester.scrollUntilVisible(
          find.text(section, skipOffstage: false),
          600,
        );
        await tester.pumpAndSettle();
        expect(find.text(section, skipOffstage: false), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('AX5: the pets list lays out without overflow', (tester) async {
      final s = _store();
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const VetPetsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('AX5: the pet detail lays out without overflow', (
      tester,
    ) async {
      // The banner's pet-code + weight row used to push the weight text off
      // the screen edge at 3.2x (caught on a Playwright screenshot). It now
      // wraps instead — a RenderFlex overflow surfaces as a FlutterError,
      // caught below.
      final s = _store();
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const VetPetDetailScreen(petId: 'p1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tapping Add record opens the kind sheet; picking a kind opens its form',
      (tester) async {
        // The write flow has no dead ends: detail → kind sheet → the kind's
        // own form, each step reachable and the sheet dismissible.
        final s = _store();
        await tester.pumpWidget(
          AppScope(
            store: s,
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const VetPetDetailScreen(petId: 'p1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add record'));
        await tester.pumpAndSettle();
        expect(
          find.text('Timeline entry', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Document', skipOffstage: false), findsOneWidget);
        await tester.tap(find.text('Timeline entry'));
        await tester.pumpAndSettle();
        expect(find.byType(MedicalEntryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('medical entry screen', () {
    Future<void> pumpEntry(
      WidgetTester tester,
      AppStore s,
      MedicalEntryKind kind,
    ) async {
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: MedicalEntryScreen(petId: 'p1', kind: kind),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> signInVet(WidgetTester tester, AppStore s) =>
        tester.runAsync(() => _signInVet(s));

    testWidgets('an empty title blocks the timeline write', (tester) async {
      final s = _store();
      await signInVet(tester, s);
      final before = s.pet('p1')!.timeline.length;
      await pumpEntry(tester, s, MedicalEntryKind.timeline);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(s.pet('p1')!.timeline.length, before);
      expect(find.text('Please enter a title.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'submitting the timeline form writes to the pet history with an audit entry',
      (tester) async {
        final s = _store();
        await signInVet(tester, s);
        await pumpEntry(tester, s, MedicalEntryKind.timeline);
        await tester.enterText(
          find.bySemanticsLabel('Entry title'),
          'Dental cleaning',
        );
        await tester.enterText(
          find.bySemanticsLabel('Entry details'),
          'Full scaling under sedation.',
        );
        await tester.tap(find.text('Save record'));
        await tester.pumpAndSettle();
        final e = s.pet('p1')!.timeline.first;
        expect(e.title, 'Dental cleaning');
        expect(e.staffId, 'vet@carepaws.test');
        expect(e.recordedAt, isNotNull);
        // Saved → back to the pet's own section, not dumped on Home.
        expect(find.byType(MedicalEntryScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('submitting the vitals form records stamped readings', (
      tester,
    ) async {
      final s = _store();
      await signInVet(tester, s);
      await pumpEntry(tester, s, MedicalEntryKind.vitals);
      await tester.enterText(find.bySemanticsLabel('Reading value'), '39.1');
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final v = s.pet('p1')!.vitals.firstWhere((x) => x.label == 'Temperature');
      expect(v.value, '39.1');
      expect(v.staffId, 'vet@carepaws.test');
      expect(tester.takeException(), isNull);
    });

    testWidgets('issuing a prescription from the form stamps the vet', (
      tester,
    ) async {
      final s = _store();
      await signInVet(tester, s);
      final before = s.prescriptions.length;
      await pumpEntry(tester, s, MedicalEntryKind.prescription);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(s.prescriptions.length, before + 1);
      final rx = s.prescriptions.last;
      expect(rx.staffId, 'vet@carepaws.test');
      expect(rx.vetName, 'Dr. Rafael Alvarez');
      expect(tester.takeException(), isNull);
    });

    testWidgets('prescription picker lists only restricted products', (
      tester,
    ) async {
      final s = _store();
      await signInVet(tester, s);
      await pumpEntry(tester, s, MedicalEntryKind.prescription);
      expect(
        find.text('Flea & Tick Spot-On (3 doses)', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Grass-fed Lamb & Oat Adult Dog Food', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text('Salmon & Sweet Potato Kitten Food', skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('attaching a document from the form stamps the vet', (
      tester,
    ) async {
      final s = _store();
      await signInVet(tester, s);
      await pumpEntry(tester, s, MedicalEntryKind.document);
      await tester.enterText(
        find.bySemanticsLabel('Document name'),
        'Post-op notes.pdf',
      );
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final d = s
          .pet('p1')!
          .docs
          .firstWhere((x) => x.name == 'Post-op notes.pdf');
      expect(d.staffId, 'vet@carepaws.test');
      expect(d.recordedAt, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
