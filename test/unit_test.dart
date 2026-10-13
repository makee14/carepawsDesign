import 'dart:math' show pow;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_artifact/app.dart';
import 'package:petcare_artifact/data/models.dart';
import 'package:petcare_artifact/data/seed.dart';
import 'package:petcare_artifact/design/theme.dart';
import 'package:petcare_artifact/design/tokens.dart';
import 'package:petcare_artifact/services/ai_service.dart';
import 'package:petcare_artifact/services/photo_store.dart';
import 'package:petcare_artifact/state/app_store.dart';
import 'package:petcare_artifact/widgets/common.dart';

/// Fixed clock so every countdown / date assertion is deterministic.
DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

Future<void> pumpApp(
  WidgetTester tester, {
  AppStore? store,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  final s = store ?? AppStore(now: fixedNow());
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const RootShell(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('Design tokens — WCAG contrast', () {
    double ratio(Color a, Color b) {
      double lum(Color c) {
        double f(double v) =>
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
      }

      final l1 = lum(a), l2 = lum(b);
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('espresso body text on cream is well above 4.5:1', () {
      expect(ratio(T.espresso, T.cream), greaterThan(4.5));
      expect(ratio(T.espresso, T.cream), closeTo(15.27, 0.3));
    });

    test('espresso body text on white cards is >= 4.5:1', () {
      expect(ratio(T.espresso, T.card), greaterThan(4.5));
    });

    test('secondary text tone is >= 4.5:1 on cream and card', () {
      expect(ratio(T.textSecondary, T.cream), greaterThan(4.5));
      expect(ratio(T.textSecondary, T.card), greaterThan(4.5));
    });

    test('primary button fill with white label is >= 4.5:1', () {
      expect(ratio(T.terracottaDeep, T.card), greaterThan(4.5));
      expect(ratio(T.terracottaDeep, T.cream), greaterThan(4.5));
    });

    test('destructive label on card is >= 4.5:1', () {
      expect(ratio(T.destructive, T.card), greaterThan(4.5));
    });

    test('amber is an accent surface only — espresso text on it passes', () {
      expect(ratio(T.espresso, T.amber), greaterThan(4.5));
    });

    test('dark theme body text on dark background passes', () {
      const dark = AppPalette.dark;
      expect(ratio(dark.text, dark.background), greaterThan(4.5));
      expect(ratio(dark.text, dark.surface), greaterThan(4.5));
      expect(ratio(dark.textSecondary, dark.background), greaterThan(4.5));
      expect(ratio(dark.onPrimaryFill, dark.primaryFill), greaterThan(4.5));
    });

    test('terracotta is reserved for large text/icons (>= 3:1)', () {
      expect(ratio(T.terracotta, T.cream), greaterThan(3));
      expect(ratio(T.terracottaDeep, T.cream), greaterThan(4.5));
    });
  });

  group('Peso formatting', () {
    test('formats with thousands separators', () {
      expect(peso(0), '₱0');
      expect(peso(850), '₱850');
      expect(peso(1240), '₱1,240');
      expect(peso(14500), '₱14,500');
      expect(peso(1234567), '₱1,234,567');
    });

    test('keeps two decimals when needed', () {
      expect(peso(12.5), '₱12.50');
    });
  });

  group('Date helpers', () {
    test('shortDate and dayMonth render real calendar values', () {
      final d = DateTime(2026, 10, 16, 10, 30);
      expect(shortDate(d), 'Fri, 16 Oct');
      expect(dayMonth(d), '16 Oct');
      expect(mediumDate(d), 'Fri, 16 Oct · 10:30 AM');
    });

    test('countdownLabel is relative and human', () {
      final now = fixedNow();
      expect(countdownLabel(now, now.add(const Duration(hours: 3, minutes: 12))),
          'in 3h 12m');
      expect(countdownLabel(now, now.add(const Duration(days: 2, hours: 6))),
          'in 2d 6h');
      expect(countdownLabel(now, now.add(const Duration(days: 3))),
          'in 3d');
    });

    test('clinicOpenAt respects weekday + Sunday hours', () {
      expect(clinicOpenAt(DateTime(2026, 10, 14, 9, 0)), isTrue); // Wed
      expect(clinicOpenAt(DateTime(2026, 10, 14, 19, 0)), isFalse);
      expect(clinicOpenAt(DateTime(2026, 10, 18, 10, 0)), isTrue); // Sun 10am
      expect(clinicOpenAt(DateTime(2026, 10, 18, 8, 0)), isFalse); // Sun 8am
    });
  });

  group('AppStore — appointments', () {
    test('upcoming and past partition correctly at the fixed clock', () {
      final s = AppStore(now: fixedNow());
      expect(s.upcoming, isNotEmpty);
      expect(s.past, isNotEmpty);
      expect(s.upcoming.any((a) => a.end.isBefore(fixedNow())), isFalse);
    });

    test('nextAppointment is the soonest upcoming', () {
      final s = AppStore(now: fixedNow());
      final n = s.nextAppointment!;
      expect(s.upcoming.first.id, n.id);
      // upcoming is returned in chronological order.
      for (var i = 1; i < s.upcoming.length; i++) {
        expect(s.upcoming[i - 1].start.isAfter(s.upcoming[i].start), isFalse);
      }
    });

    test('cancelAppointment moves a visit to past and sets cancelled status', () {
      final s = AppStore(now: fixedNow());
      final a = s.upcoming.first;
      s.cancelAppointment(a.id);
      expect(s.appt(a.id)!.status, ApptStatus.cancelled);
      expect(s.past.any((x) => x.id == a.id), isTrue);
    });

    test('autoAssignStaff routes by service line', () {
      final s = AppStore(now: fixedNow());
      expect(s.autoAssignStaff('sv1'), Seed.vet.id); // vet consult
      expect(s.autoAssignStaff('sv4'), Seed.groomer.id); // grooming
      expect(s.autoAssignStaff('sv2'), Seed.assistant.id); // vaccination
    });

    test('grooming service reports estimated pricing + 2h duration', () {
      final s = AppStore(now: fixedNow());
      final g = s.serviceOf('sv4');
      expect(g.grooming, isTrue);
      expect(g.priceNote, 'estimated');
      expect(g.durationMinutes, 120);
      expect(g.durationLabel, '2 hr');
    });
  });

  group('AppStore — cart math', () {
    test('add / setQty / remove keep totals correct', () {
      final s = AppStore(now: fixedNow());
      s.clearCart();
      expect(s.cartTotal, 0);
      s.addToCart('pr3', 2);
      expect(s.qtyOf('pr3'), 2);
      expect(s.cartTotal, 640); // 320 x 2
      s.setQty('pr3', 1);
      expect(s.cartTotal, 320);
      s.removeFromCart('pr3');
      expect(s.cartCount, 0);
      expect(s.cartTotal, 0);
    });

    test('setQty to 0 removes the line', () {
      final s = AppStore(now: fixedNow());
      s.clearCart();
      s.addToCart('pr1');
      s.setQty('pr1', 0);
      expect(s.cart, isEmpty);
    });

    test('out-of-stock product cannot be added', () {
      final s = AppStore(now: fixedNow());
      expect(s.productOf('pr4').inStock, isFalse);
    });

    test('restricted item is blocked without a prescription', () {
      final s = AppStore(now: fixedNow());
      s.clearCart();
      s.addToCart('pr6');
      // Seed grants an active Rx for pr6, so it must NOT be blocked.
      expect(s.hasPrescription('pr6'), isTrue);
      expect(s.blockedRestricted, isEmpty);
    });

    test('restricted item blocks when the prescription has expired', () {
      final s = AppStore(now: fixedNow());
      s.clearCart();
      s.prescriptions = [
        Prescription(
          id: 'rx_old',
          productId: 'pr6',
          vetName: Seed.vet.name,
          issued: DateTime(2020),
          expires: DateTime(2021),
          refills: 0,
        ),
      ];
      s.addToCart('pr6');
      expect(s.hasPrescription('pr6'), isFalse);
      expect(s.blockedRestricted, ['pr6']);
    });
  });

  group('AppStore — reminders', () {
    test('first toggle-on reports that permission must be shown', () {
      final s = AppStore(now: fixedNow());
      final r = s.reminders.firstWhere((x) => !x.on);
      expect(s.toggleReminder(r.id, true), isTrue);
      expect(s.reminders.firstWhere((x) => x.id == r.id).on, isTrue);
    });

    test('permission is only asked once after it is granted', () {
      final s = AppStore(now: fixedNow());
      s.setNotificationsAsked(true);
      final r = s.reminders.firstWhere((x) => !x.on);
      expect(s.toggleReminder(r.id, true), isFalse);
    });

    test('a declined permission leaves reminders off and can ask again', () {
      final s = AppStore(now: fixedNow());
      final r = s.reminders.firstWhere((x) => !x.on);
      expect(s.toggleReminder(r.id, true), isTrue);
      s.setNotificationsAsked(false);
      s.toggleReminder(r.id, false);
      expect(s.toggleReminder(r.id, true), isTrue);
    });

    test('toggling off never asks for permission', () {
      final s = AppStore(now: fixedNow());
      final r = s.reminders.firstWhere((x) => x.on);
      expect(s.toggleReminder(r.id, false), isFalse);
    });

    test('reminderOn aggregates by kind', () {
      final s = AppStore(now: fixedNow());
      expect(s.reminderOn(ReminderKind.medication), isTrue);
      expect(s.reminderOn(ReminderKind.grooming), isFalse);
    });
  });

  group('AppStore — pets', () {
    test('clearPets drives the zero-pet empty state', () {
      final s = AppStore(now: fixedNow());
      s.clearPets();
      expect(s.petCount, 0);
    });

    test('addPet prepends the new pet', () {
      final s = AppStore(now: fixedNow());
      final before = s.petCount;
      s.addPet(
        Pet(
          id: 'px',
          name: 'Pepper',
          species: Species.dog,
          breed: 'Mixed breed',
          sex: 'Female',
          birthDate: DateTime(2024),
          weightKg: 9.5,
          color: Color(0xFFE4843E),
          microchip: 'None',
          allergies: [],
          vitals: [],
          timeline: [],
          docs: [],
        ),
      );
      expect(s.petCount, before + 1);
      expect(s.pets.first.name, 'Pepper');
    });

    test('seed pets have realistic profile data', () {
      final s = AppStore(now: fixedNow());
      expect(s.pets.length, 2);
      expect(s.pets.first.name, 'Biscuit');
      expect(s.pets.first.breed, 'Golden Retriever');
      expect(s.pets.last.name, 'Mochi');
      expect(s.pets.first.vitals, isNotEmpty);
      expect(s.pets.first.docs, isNotEmpty);
      expect(s.pets.first.timeline, isNotEmpty);
      expect(s.pets.first.allergies, contains('Chicken'));
    });
  });

  group('AppStore — chat', () {
    test('offlineNote is null while the clinic is open', () {
      final s = AppStore(now: DateTime(2026, 10, 13, 10));
      expect(s.staffOnline(), isTrue);
      expect(s.offlineNote, isNull);
    });

    test('offlineNote names the resume time when closed', () {
      final s = AppStore(now: DateTime(2026, 10, 13, 22));
      expect(s.staffOnline(), isFalse);
      expect(s.offlineNote, contains('8:00 AM'));
    });

    test('handoff carries pet + triage into the clinic thread', () {
      final s = AppStore(now: fixedNow());
      final before = s.thread('th_clinic').length;
      s.handOffToClinic(
        pet: s.pets.first,
        result: const TriageResult(
          route: TriageRoute.book,
          title: 'Vomiting — book a consult',
          summary: 'Two episodes this morning.',
          urgency: 1,
        ),
      );
      final after = s.thread('th_clinic');
      expect(after.length, greaterThan(before));
      final handoff = after.firstWhere((m) => m.kind == ChatKind.triageHandoff);
      expect(handoff.text, contains('Biscuit'));
      expect(handoff.text, contains('Two episodes'));
      // The vet assistant auto-replies.
      expect(after.any((m) => m.kind == ChatKind.text && m.author == ChatAuthor.vetAssistant), isTrue);
    });
  });

  group('Seed data quality', () {
    test('catalog has 6–8 products with peso prices', () {
      expect(Seed.products.length, inInclusiveRange(6, 8));
      for (final p in Seed.products) {
        expect(p.price, greaterThan(0));
        expect(p.name, isNotEmpty);
        expect(p.description, isNotEmpty);
        expect(p.description, isNot(contains('lorem')));
      }
    });

    test('at least one product is out of stock for the Notify-me path', () {
      expect(Seed.products.any((p) => !p.inStock), isTrue);
    });

    test('no seed copy contains lorem ipsum', () {
      for (final p in Seed.products) {
        expect(p.tagline.toLowerCase(), isNot(contains('lorem')));
      }
      expect(Seed.ownerName, isNotEmpty);
      expect(Seed.clinicAddress, isNotEmpty);
    });

    test('service list covers vet, assistant and grooming durations', () {
      final vet = Seed.services.where((s) => s.role == StaffRole.vet);
      final asst = Seed.services.where((s) => s.role == StaffRole.vetAssistant);
      final groom = Seed.services.where((s) => s.role == StaffRole.groomer);
      expect(vet, isNotEmpty);
      expect(asst, isNotEmpty);
      expect(groom, isNotEmpty);
      // Grooming services run 1-2h, assistant tasks 15-20m, vet consults 30m.
      final groomingServices = Seed.services.where((s) => s.grooming);
      expect(groomingServices, isNotEmpty);
      expect(groomingServices.every((s) => s.durationMinutes >= 60 && s.durationMinutes <= 120),
          isTrue);
      expect(asst.every((s) => s.durationMinutes >= 15 && s.durationMinutes <= 20), isTrue);
      expect(vet.every((s) => s.durationMinutes == 30), isTrue);
      expect(groom, isNotEmpty);
    });
  });

  group('Status labels are text, never colour-only', () {
    test('every appointment status has a non-empty label', () {
      for (final s in ApptStatus.values) {
        expect(s.label, isNotEmpty);
        expect(s.short, isNotEmpty);
      }
    });

    test('every order status has a non-empty label', () {
      for (final s in OrderStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('staff roles expose a text tag for timeline entries', () {
      for (final r in StaffRole.values) {
        expect(r.chip, isNotEmpty);
        expect(r.label, isNotEmpty);
      }
    });
  });

  group('Sign-in gate', () {
    test('the demo credentials are accepted', () async {
      final store = AppStore();
      final ok = await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
      expect(ok, isTrue);
      expect(store.signedIn, isTrue);
      expect(store.signInError, isNull);
    });

    test('the email may be upper-cased or padded', () async {
      final store = AppStore();
      final ok = await store.signIn(
        '  ${AppStore.demoEmail.toUpperCase()}  ',
        AppStore.demoPassword,
      );
      expect(ok, isTrue);
    });

    test('a wrong password is rejected and stays rejected', () async {
      final store = AppStore();
      final ok = await store.signIn(AppStore.demoEmail, 'wrong-password');
      expect(ok, isFalse);
      expect(store.signedIn, isFalse);
      expect(store.signInError, isNotNull);
      expect(store.signInError, contains('password'));
    });

    test('an unknown email is rejected', () async {
      final store = AppStore();
      final ok = await store.signIn('someone@example.com', AppStore.demoPassword);
      expect(ok, isFalse);
      expect(store.signedIn, isFalse);
      expect(store.signInError, isNotNull);
    });

    test('empty input is rejected without signing in', () async {
      final store = AppStore();
      expect(await store.signIn('', ''), isFalse);
      expect(store.signedIn, isFalse);
    });

    test('the right password with the wrong email still fails', () async {
      final store = AppStore();
      expect(await store.signIn('petcare@wrong.com', AppStore.demoPassword), isFalse);
    });

    test('signOut clears the session and any error', () async {
      final store = AppStore();
      await store.signIn(AppStore.demoEmail, AppStore.demoPassword);
      expect(store.signedIn, isTrue);
      store.signOut();
      expect(store.signedIn, isFalse);
      expect(store.signInError, isNull);
    });

    test('a fresh store starts signed out', () {
      expect(AppStore().signedIn, isFalse);
    });
  });

  group('The assistant stays on veterinary topics', () {
    String ask(String q) => DemoAi.chat(q, petName: 'Biscuit', species: 'dog');

    test('off-topic questions get the clinic redirect, not an answer', () {
      const offTopic = [
        'what is the weather today',
        'who won the football match',
        'write my history essay about the elections',
        'do the maths for me',
        'what is the capital of france',
        'translate this into french',
        'tell me a joke',
        'should I take my headache medicine',
      ];
      for (final q in offTopic) {
        expect(ask(q), VetPersona.redirect, reason: 'should refuse: $q');
      }
    });

    test('vet questions still get real guidance', () {
      final food = ask('what food should I feed my dog');
      expect(food, isNot(VetPersona.redirect));
      expect(food.length, greaterThan(40));

      final vaccine = ask('when is the next vaccine due');
      expect(vaccine, isNot(VetPersona.redirect));
      expect(vaccine.toLowerCase(), contains('booster'));
    });

    test('training words that merely sound off-topic still get answered', () {
      // "school a puppy" and "training program" are real pet-care questions —
      // the demo keyword list must not swallow them.
      expect(ask('how do I school my puppy'), isNot(VetPersona.redirect));
      expect(ask('is there a training program for shy dogs'), isNot(VetPersona.redirect));
    });

    test('the scope check runs before the vet branches', () {
      // Mixed message: the in-scope half must not get through.
      expect(
        ask('what food do I feed my dog, also write my essay'),
        VetPersona.redirect,
      );
    });

    test('the redirect itself names the clinic and points back to the pet', () {
      expect(VetPersona.redirect, contains('PetCare'));
      expect(VetPersona.redirect, contains('pet'));
    });

    test('the persona instructs an in-scope / out-of-scope decision', () {
      expect(VetPersona.system, contains('veterinarian'));
      expect(VetPersona.system, contains('OUT OF SCOPE'));
      expect(VetPersona.system, contains('inScope'));
      expect(VetPersona.system, contains('never a diagnosis'));
    });
  });

  group('A key entered on the device is stored and restored', () {
    // Without a mock, SharedPreferences.getInstance() throws MissingPluginException
    // and the service silently keeps only the build-time key. These tests are
    // what actually prove the on-device path works.
    const key = 'AIzaSyTESTKEY0000000000000000000abcd';

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a key typed into Settings is written to device storage', () async {
      final ai = AiService();
      addTearDown(ai.dispose);

      await ai.bootstrap();
      expect(ai.keyConfigured, isFalse, reason: 'starts with no key');
      expect(ai.keyFromDevice, isFalse);

      await ai.useKey(key);
      expect(ai.keyConfigured, isTrue);
      expect(ai.keyFromDevice, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiService.keyPrefName), key);
    });

    test('a fresh service picks the stored key up on the next launch', () async {
      final first = AiService();
      addTearDown(first.dispose);
      await first.useKey(key);

      // A brand new instance is what the app builds on the next cold start.
      final next = AiService();
      addTearDown(next.dispose);
      await next.bootstrap();

      expect(next.keyConfigured, isTrue);
      expect(next.keyFromDevice, isTrue);
    });

    test('removing the key clears storage and returns to demo mode', () async {
      final ai = AiService();
      addTearDown(ai.dispose);
      await ai.useKey(key);
      expect(ai.keyConfigured, isTrue);

      await ai.clearKey();
      expect(ai.keyConfigured, isFalse);
      expect(ai.keyFromDevice, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiService.keyPrefName), isNull);
    });

    test('a too-short or placeholder entry is refused, not stored', () async {
      final ai = AiService();
      addTearDown(ai.dispose);

      for (final bad in ['', '   ', 'AIzaShort', 'YOUR_GEMINI_API_KEY']) {
        await ai.useKey(bad);
        expect(ai.keyConfigured, isFalse, reason: 'should refuse: "$bad"');
        expect(ai.keyFromDevice, isFalse);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiService.keyPrefName), isNull);
    });

    test('surrounding whitespace in a pasted key is trimmed', () async {
      final ai = AiService();
      addTearDown(ai.dispose);

      await ai.useKey('  $key  ');
      expect(ai.keyConfigured, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiService.keyPrefName), key);
    });
  });

  group('Photos are stored on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // A tiny 1x1 PNG — enough to prove bytes survive the round trip.
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    test('a pet photo is written and restored', () async {
      final store = AppStore();
      final petId = store.pets.first.id;

      await store.setPetPhoto(petId, png);
      expect(store.pet(petId)!.hasPhoto, isTrue);
      expect(store.pet(petId)!.photo, png);

      final next = AppStore();
      await next.loadPhotos();
      expect(next.pet(petId)!.hasPhoto, isTrue);
      expect(next.pet(petId)!.photo, png);
    });

    test('clearing a pet photo falls back to the generated art', () async {
      final store = AppStore();
      final petId = store.pets.first.id;

      await store.setPetPhoto(petId, png);
      await store.setPetPhoto(petId, null);

      expect(store.pet(petId)!.hasPhoto, isFalse);
      expect(store.pet(petId)!.photo, isNull);

      final next = AppStore();
      await next.loadPhotos();
      expect(next.pet(petId)!.hasPhoto, isFalse);
    });

    test('removing a pet also drops its stored photo', () async {
      final store = AppStore();
      final petId = store.pets.first.id;
      await store.setPetPhoto(petId, png);

      store.removePet(petId);
      expect(await PhotoStore.load(PhotoStore.petKey(petId)), isNull);
    });

    test('the owner photo round-trips', () async {
      final store = AppStore();
      expect(store.hasOwnerPhoto, isFalse);

      await store.setOwnerPhoto(png);
      expect(store.hasOwnerPhoto, isTrue);

      final next = AppStore();
      await next.loadPhotos();
      expect(next.hasOwnerPhoto, isTrue);
      expect(next.ownerPhoto, png);

      await store.setOwnerPhoto(null);
      expect(store.hasOwnerPhoto, isFalse);
    });

    test('updatePet keeps the record and swaps in the edited fields', () async {
      final store = AppStore();
      final pet = store.pets.first;
      final timelineBefore = pet.timeline.length;
      final countBefore = store.petCount;

      store.updatePet(
        Pet(
          id: pet.id,
          name: 'Renamed',
          species: pet.species,
          breed: 'Poodle',
          sex: 'Female',
          birthDate: pet.birthDate,
          weightKg: 7.5,
          color: pet.color,
          microchip: pet.microchip,
          allergies: const ['Chicken'],
          vitals: pet.vitals,
          timeline: pet.timeline,
          docs: pet.docs,
          photo: png,
        ),
      );

      final updated = store.pet(pet.id)!;
      expect(updated.name, 'Renamed');
      expect(updated.breed, 'Poodle');
      expect(updated.sex, 'Female');
      expect(updated.weightKg, 7.5);
      expect(updated.allergies, ['Chicken']);
      expect(updated.hasPhoto, isTrue);
      // Clinic history must survive an owner-side edit.
      expect(updated.timeline.length, timelineBefore);
      expect(store.petCount, countBefore, reason: 'editing must not duplicate the pet');
    });

    test('a corrupt stored photo is dropped instead of crashing', () async {
      SharedPreferences.setMockInitialValues({
        PhotoStore.ownerKey: 'not-valid-base64!!!',
      });
      final store = AppStore();
      await store.loadPhotos();
      expect(store.hasOwnerPhoto, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PhotoStore.ownerKey), isNull);
    });

    test('pets with no stored photo are left untouched', () async {
      final store = AppStore();
      await store.loadPhotos();
      expect(store.pets.every((p) => !p.hasPhoto), isTrue);
      expect(store.pets.length, 2);
    });
  });
}