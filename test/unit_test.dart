import 'dart:convert';
import 'dart:math' show pow;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/data/clinic.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/design/tokens.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/services/photo_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/ai_unavailable.dart';
import 'package:carepaws/widgets/common.dart';

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
      expect(
        countdownLabel(now, now.add(const Duration(hours: 3, minutes: 12))),
        'in 3h 12m',
      );
      expect(
        countdownLabel(now, now.add(const Duration(days: 2, hours: 6))),
        'in 2d 6h',
      );
      expect(countdownLabel(now, now.add(const Duration(days: 3))), 'in 3d');
    });

    test('clinicOpenAt respects weekday hours and closed Sundays', () {
      expect(clinicOpenAt(DateTime(2026, 10, 14, 9, 0)), isTrue); // Wed 9am
      expect(clinicOpenAt(DateTime(2026, 10, 14, 17, 59)), isTrue); // Wed
      expect(clinicOpenAt(DateTime(2026, 10, 14, 8, 59)), isFalse); // Wed early
      expect(clinicOpenAt(DateTime(2026, 10, 14, 18, 0)), isFalse); // Wed 6pm
      expect(clinicOpenAt(DateTime(2026, 10, 18, 10, 0)), isFalse); // Sun 10am
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

    test('upcomingAppointments is the sorted source; upcoming aliases it', () {
      final s = AppStore(now: fixedNow());
      final list = s.upcomingAppointments;
      expect(list, isNotEmpty);
      expect(
        list.map((a) => a.id).toList(),
        s.upcoming.map((a) => a.id).toList(),
      );
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].start.isAfter(list[i].start), isFalse);
      }
      expect(s.nextAppointment!.id, list.first.id);
    });

    test('upcomingAppointments drops finished visits as the clock moves', () {
      final s = AppStore(now: fixedNow());
      final first = s.upcomingAppointments.first;
      // Jump past the first visit's end: it leaves the upcoming list.
      s.advanceClock(
        first.end.difference(fixedNow()) + const Duration(minutes: 1),
      );
      expect(s.upcomingAppointments.any((a) => a.id == first.id), isFalse);
    });

    test('startClock is idempotent; stopClock and dispose are safe', () {
      final s = AppStore(now: fixedNow());
      s.startClock();
      s.startClock();
      s.stopClock();
      s.stopClock();
      s.dispose();
    });

    test(
      'cancelAppointment moves a visit to past and sets cancelled status',
      () {
        final s = AppStore(now: fixedNow());
        final a = s.upcoming.first;
        s.cancelAppointment(a.id);
        expect(s.appt(a.id)!.status, ApptStatus.cancelled);
        expect(s.past.any((x) => x.id == a.id), isTrue);
      },
    );

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
      expect(s.offlineNote, contains('9:00 AM'));
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
      expect(
        after.any(
          (m) => m.kind == ChatKind.text && m.author == ChatAuthor.vetAssistant,
        ),
        isTrue,
      );
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
      expect(
        groomingServices.every(
          (s) => s.durationMinutes >= 60 && s.durationMinutes <= 120,
        ),
        isTrue,
      );
      expect(
        asst.every((s) => s.durationMinutes >= 15 && s.durationMinutes <= 20),
        isTrue,
      );
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
      final ok = await store.signIn(
        'someone@example.com',
        AppStore.demoPassword,
      );
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
      expect(
        await store.signIn('carepaws@wrong.com', AppStore.demoPassword),
        isFalse,
      );
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

    test('sign-in failure is one neutral message either way', () async {
      const neutral = "Email and password don't match. Try again.";
      final store = AppStore();
      addTearDown(store.dispose);
      // Unknown email and wrong password produce the identical message, so
      // neither confirms whether the email exists on this device.
      expect(await store.signIn('nobody@example.com', 'whatever123'), isFalse);
      expect(store.signInError, neutral);
      await store.register('Mark', 'mark@example.com', 'secret123');
      expect(await store.signIn('mark@example.com', 'wrongpass1'), isFalse);
      expect(store.signInError, neutral);
    });
  });

  group('Password rules', () {
    test('at least 8 characters with a letter and a number', () {
      expect(AuthStore.validatePassword('secret123'), isNull);
      expect(AuthStore.validatePassword('a1b2c3d4'), isNull);
      expect(AuthStore.validatePassword('short1'), contains('8 characters'));
      expect(
        AuthStore.validatePassword('abcdefgh'),
        contains('letters and numbers'),
      );
      expect(
        AuthStore.validatePassword('12345678'),
        contains('letters and numbers'),
      );
      expect(AuthStore.validatePassword(''), contains('8 characters'));
    });
  });

  group('Owner initials', () {
    test('first letters of the first two name parts', () {
      expect(initialsOf('Marco Dela Cruz'), 'MD');
      expect(initialsOf('Mark'), 'M');
      expect(initialsOf('  ana   reyes  '), 'AR');
      expect(initialsOf(''), '?');
    });
  });

  group('Local registration', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a new account registers without signing in', () async {
      final store = AppStore();
      addTearDown(store.dispose);
      final ok = await store.register('Mark', 'mark@example.com', 'secret123');
      expect(ok, isTrue);
      // Registration never signs in: the login screen takes the user back
      // to sign-in so the new credentials are entered deliberately.
      expect(store.signedIn, isFalse);
      expect(store.accountName, isNull);
      expect(store.signInError, isNull);

      final signedIn = await store.signIn('mark@example.com', 'secret123');
      expect(signedIn, isTrue);
      expect(store.accountName, 'Mark');
      expect(store.accountEmail, 'mark@example.com');
    });

    test('the registered account can sign in again after sign-out', () async {
      final store = AppStore();
      addTearDown(store.dispose);
      await store.register('Mark', 'mark@example.com', 'secret123');
      store.signOut();
      expect(store.signedIn, isFalse);

      final ok = await store.signIn('mark@example.com', 'secret123');
      expect(ok, isTrue);
      expect(store.signedIn, isTrue);
      expect(store.accountName, 'Mark');
    });

    test('duplicate email is rejected', () async {
      final store = AppStore();
      addTearDown(store.dispose);
      expect(
        await store.register('Mark', 'mark@example.com', 'secret123'),
        isTrue,
      );
      expect(
        await store.register('Other', 'mark@example.com', 'other123'),
        isFalse,
      );
      expect(store.signInError, contains('already exists'));
    });

    test('bad input is rejected with a useful message', () async {
      final store = AppStore();
      addTearDown(store.dispose);
      expect(
        await store.register('', 'mark@example.com', 'secret123'),
        isFalse,
      );
      expect(store.signInError, contains('name'));
      expect(
        await store.register('Mark', 'not-an-email', 'secret123'),
        isFalse,
      );
      expect(store.signInError, contains('email'));
      expect(await store.register('Mark', 'mark@example.com', '123'), isFalse);
      expect(store.signInError, contains('8 characters'));
      expect(
        await store.register('Mark', 'mark@example.com', 'abcdefgh'),
        isFalse,
      );
      expect(store.signInError, contains('letters and numbers'));
      expect(
        await store.register('Mark', 'mark@example.com', '12345678'),
        isFalse,
      );
      expect(store.signInError, contains('letters and numbers'));
    });

    test('wrong password for a registered account is rejected', () async {
      final store = AppStore();
      addTearDown(store.dispose);
      await store.register('Mark', 'mark@example.com', 'secret123');
      store.signOut();
      expect(await store.signIn('mark@example.com', 'wrong'), isFalse);
      expect(store.signInError, contains('password'));
    });

    test('registered accounts take precedence over demo', () async {
      final store = AppStore();
      addTearDown(store.dispose);
      // Register with the demo email (edge case): the registered name wins.
      await store.register('Local User', AppStore.demoEmail, 'localpass123');
      store.signOut();
      final ok = await store.signIn(AppStore.demoEmail, 'localpass123');
      expect(ok, isTrue);
      expect(store.accountName, 'Local User');
    });
  });

  group('The assistant prompt is honest and injects live clinic context', () {
    String prompt({required DateTime now, String name = 'Marco'}) =>
        VetPersona.systemFor(now: now, ownerFirstName: name);

    test('it never claims to be a vet and never offers a diagnosis', () {
      final p = prompt(now: DateTime(2026, 10, 13, 10));
      expect(p, contains("I'm an AI assistant, not a vet"));
      expect(p, contains("this isn't a diagnosis"));
      expect(p, contains('Never guess'));
      expect(p, isNot(contains('You are Dr. Alvarez')));
    });

    test('it never claims the owner is at the clinic', () {
      final p = prompt(now: DateTime(2026, 10, 13, 10));
      expect(p, isNot(contains('at the clinic')));
      expect(p, contains('at home'));
    });

    test('it injects the current time, the hours and the open state', () {
      final open = prompt(now: DateTime(2026, 10, 13, 10)); // Tue 10:00 AM
      expect(open, contains('Tuesday'));
      expect(open, contains('Mon–Sat 9:00 AM – 6:00 PM · Closed Sundays'));
      expect(open, contains('open right now'));

      final closed = prompt(now: DateTime(2026, 10, 11, 10)); // Sunday
      expect(closed, contains('closed right now'));
      expect(closed, contains('Animal Emergency Center — Mandaluyong'));
      expect(closed, contains('+63 2 8556 0190'));
    });

    test('it addresses the owner by first name, with a no-name fallback', () {
      expect(
        prompt(now: DateTime(2026, 10, 13, 10), name: 'Marco'),
        contains('Marco'),
      );
      final anon = prompt(now: DateTime(2026, 10, 13, 10), name: '');
      expect(anon, contains('never invent one'));
      expect(anon, isNot(contains('Marco')));
    });

    test('the redirect names the clinic and points back to the pet', () {
      expect(VetPersona.redirect, contains('CarePaws'));
      expect(VetPersona.redirect, contains('pet'));
      expect(VetPersona.redirect, contains('not a vet'));
    });

    test('the persona instructs an in-scope / out-of-scope decision', () {
      final p = prompt(now: DateTime(2026, 10, 13, 10));
      expect(p, contains('OUT OF SCOPE'));
      expect(p, contains('inScope'));
      expect(p, contains('never a diagnosis'));
    });
  });

  group('Clinic hours are one config', () {
    test('Mon–Sat 9:00–18:00 is open, Sundays are closed', () {
      expect(Clinic.isOpenNow(DateTime(2026, 10, 12, 9)), isTrue); // Mon 9:00
      expect(Clinic.isOpenNow(DateTime(2026, 10, 17, 17, 59)), isTrue); // Sat
      expect(
        Clinic.isOpenNow(DateTime(2026, 10, 12, 8, 59)),
        isFalse,
      ); // Mon early
      expect(
        Clinic.isOpenNow(DateTime(2026, 10, 17, 18)),
        isFalse,
      ); // Sat evening
      expect(Clinic.isOpenNow(DateTime(2026, 10, 11, 12)), isFalse); // Sunday
    });

    test('nextOpening skips Sunday', () {
      expect(
        Clinic.nextOpening(DateTime(2026, 10, 17, 20)),
        DateTime(2026, 10, 19, 9),
      ); // Sat night -> Mon 9:00
      expect(
        Clinic.nextOpening(DateTime(2026, 10, 11, 12)),
        DateTime(2026, 10, 12, 9),
      ); // Sunday -> Mon 9:00
      expect(
        Clinic.nextOpening(DateTime(2026, 10, 12, 7)),
        DateTime(2026, 10, 12, 9),
      ); // Mon early -> Mon 9:00
    });

    test('the seed aliases match the config', () {
      expect(Seed.clinicName, Clinic.name);
      expect(Seed.clinicAddress, Clinic.address);
      expect(Seed.clinicPhone, Clinic.phone);
      expect(Seed.afterHoursPhone, Clinic.afterHoursPhone);
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
      expect(ai.statusFor(AiProvider.gemini).keyFromDevice, isFalse);

      await ai.useKeyFor(AiProvider.gemini, key);
      expect(ai.keyConfigured, isTrue);
      expect(ai.statusFor(AiProvider.gemini).keyFromDevice, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiProvider.gemini.keysPref), '["$key"]');
    });

    test(
      'a fresh service picks the stored key up on the next launch',
      () async {
        final first = AiService();
        addTearDown(first.dispose);
        await first.useKeyFor(AiProvider.gemini, key);

        // A brand new instance is what the app builds on the next cold start.
        final next = AiService();
        addTearDown(next.dispose);
        await next.bootstrap();

        expect(next.keyConfigured, isTrue);
        expect(next.statusFor(AiProvider.gemini).keyFromDevice, isTrue);
      },
    );

    test(
      'removing the key clears storage and returns to unavailable',
      () async {
        final ai = AiService();
        addTearDown(ai.dispose);
        await ai.useKeyFor(AiProvider.gemini, key);
        expect(ai.keyConfigured, isTrue);

        await ai.clearKeyFor(AiProvider.gemini);
        expect(ai.keyConfigured, isFalse);
        expect(ai.statusFor(AiProvider.gemini).keyFromDevice, isFalse);
        expect(ai.status, AiStatus.unavailable);
        expect(ai.failure, AiFailure.noKey);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AiProvider.gemini.keysPref), isNull);
      },
    );

    test('a too-short or placeholder entry is refused, not stored', () async {
      final ai = AiService();
      addTearDown(ai.dispose);

      for (final bad in ['', '   ', 'AIzaShort', 'YOUR_GEMINI_API_KEY']) {
        await ai.useKeyFor(AiProvider.gemini, bad);
        expect(ai.keyConfigured, isFalse, reason: 'should refuse: "$bad"');
        expect(ai.statusFor(AiProvider.gemini).keyFromDevice, isFalse);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiProvider.gemini.keysPref), isNull);
    });

    test('surrounding whitespace in a pasted key is trimmed', () async {
      final ai = AiService();
      addTearDown(ai.dispose);

      await ai.useKeyFor(AiProvider.gemini, '  $key  ');
      expect(ai.keyConfigured, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AiProvider.gemini.keysPref), '["$key"]');
    });
  });

  group('Multiple AI providers route with failover', () {
    const triageJson =
        '{"route":"book","urgency":1,"title":"Test","summary":"s",'
        '"bullets":[],"redFlags":[],"homeCare":[],"nextStep":"n"}';

    /// Gemini answers the models list and the probe, but fails real
    /// requests; OpenAI answers everything. Drives request-time failover.
    AiService failoverService() {
      SharedPreferences.setMockInitialValues({});
      final ai = AiService(client: _FailoverFake(triageJson));
      addTearDown(ai.dispose);
      return ai;
    }

    test('keys are stored per provider, independently', () async {
      final ai = failoverService();
      await ai.useKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      await ai.useKeyFor(AiProvider.openai, 'openai-key-00000000000000001');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AiProvider.gemini.keysPref),
        '["gemini-key-00000000000000001"]',
      );
      expect(
        prefs.getString(AiProvider.openai.keysPref),
        '["openai-key-00000000000000001"]',
      );
      expect(prefs.getString(AiProvider.openrouter.keysPref), isNull);

      expect(ai.statusFor(AiProvider.gemini).keyFromDevice, isTrue);
      expect(ai.statusFor(AiProvider.openai).keyFromDevice, isTrue);
      expect(ai.statusFor(AiProvider.openrouter).keyFromDevice, isFalse);
    });

    test('a failing provider fails over to the next one mid-request', () async {
      final ai = failoverService();
      await ai.useKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      await ai.useKeyFor(AiProvider.openai, 'openai-key-00000000000000001');

      // Gemini wins bootstrap (priority order) and goes live on the probe.
      expect(ai.isLive, isTrue);
      expect(ai.modelLabel, startsWith('Gemini'));

      // The real request fails on Gemini and is retried on OpenAI.
      final result = await ai.triage(
        petName: 'Biscuit',
        species: 'dog',
        text: 'coughing',
      );
      expect(result.title, 'Test');
      expect(ai.modelLabel, startsWith('OpenAI'));
      expect(ai.isLive, isTrue);
    });

    test('a rejected key falls over to the next key in the pool', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = AiService(client: _KeyRotationFake(triageJson));
      addTearDown(ai.dispose);
      // Two keys: the first is rejected (401), the second answers.
      await ai.setKeysFor(AiProvider.gemini, [
        'gemini-key-00000000000000001',
        'gemini-key-00000000000000002',
      ]);
      expect(ai.keyConfigured, isTrue);

      final result = await ai.triage(
        petName: 'Biscuit',
        species: 'dog',
        text: 'coughing',
      );
      expect(result.title, 'Test');
      // The second key answered, so it is the active one.
      expect(ai.statusFor(AiProvider.gemini).activeKeyLabel, isNotNull);
    });

    test('a failing model falls back to the next model', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = AiService(client: _ModelFallbackFake(triageJson));
      addTearDown(ai.dispose);
      await ai.useKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');

      final result = await ai.triage(
        petName: 'Biscuit',
        species: 'dog',
        text: 'coughing',
      );
      expect(result.title, 'Test');
    });

    test('key pool add/remove persists and re-probes', () async {
      final ai = failoverService();
      await ai.addKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      await ai.addKeyFor(AiProvider.gemini, 'gemini-key-00000000000000002');
      // Dupes are ignored.
      await ai.addKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');

      var pool = ai.statusFor(AiProvider.gemini).keyPool;
      expect(pool.length, 2);

      await ai.removeKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      pool = ai.statusFor(AiProvider.gemini).keyPool;
      expect(pool.length, 1);

      // The pool survives a restart.
      final next = AiService(client: _FailoverFake(triageJson));
      addTearDown(next.dispose);
      await next.bootstrap();
      expect(next.statusFor(AiProvider.gemini).keyPool.length, 1);
    });

    test('a disabled provider is skipped by routing', () async {
      final ai = failoverService();
      await ai.useKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      await ai.useKeyFor(AiProvider.openai, 'openai-key-00000000000000001');
      await ai.setProviderEnabled(AiProvider.gemini, false);

      expect(ai.isLive, isTrue);
      expect(ai.modelLabel, startsWith('OpenAI'));
      expect(ai.statusFor(AiProvider.gemini).enabled, isFalse);

      // And the switch persists across restarts.
      final next = AiService(client: _FailoverFake(triageJson));
      addTearDown(next.dispose);
      await next.bootstrap();
      expect(next.modelLabel, startsWith('OpenAI'));
    });

    test('all providers failing surfaces the last error, honestly', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = AiService(client: _FailoverFake(triageJson, openaiDown: true));
      addTearDown(ai.dispose);
      await ai.useKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      await ai.useKeyFor(AiProvider.openai, 'openai-key-00000000000000001');

      await expectLater(
        ai.triage(petName: 'Biscuit', species: 'dog', text: 'coughing'),
        throwsA(isA<AiException>()),
      );
      expect(ai.isLive, isFalse);
      expect(ai.status, AiStatus.unavailable);
      expect(ai.failure, isNotNull);
    });

    test('a garbled reply fails over to the next provider', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = AiService(
        client: _FailoverFake(triageJson, geminiGarbled: true),
      );
      addTearDown(ai.dispose);
      await ai.useKeyFor(AiProvider.gemini, 'gemini-key-00000000000000001');
      await ai.useKeyFor(AiProvider.openai, 'openai-key-00000000000000001');

      // Gemini answers 200 but with non-JSON; the parse failure must route
      // to OpenAI rather than surfacing as an unparseable-reply error.
      final result = await ai.triage(
        petName: 'Biscuit',
        species: 'dog',
        text: 'coughing',
      );
      expect(result.title, 'Test');
      expect(ai.modelLabel, startsWith('OpenAI'));
    });

    test('useKeyFor is honest: only true when the provider answers', () async {
      SharedPreferences.setMockInitialValues({});
      final ai = AiService(client: _FailoverFake(triageJson, openaiDown: true));
      addTearDown(ai.dispose);

      // OpenAI's bootstrap probe fails here, so the key saves but the
      // provider never goes live: the return must not claim "ready".
      final ok = await ai.useKeyFor(
        AiProvider.openai,
        'openai-key-00000000000000001',
      );
      expect(ok, isFalse);
      expect(
        ai.statusFor(AiProvider.openai).keyConfigured,
        isTrue,
        reason: 'the key itself was saved',
      );
      expect(ai.statusFor(AiProvider.openai).isLive, isFalse);

      // Gemini's probe succeeds: honest true.
      final okGemini = await ai.useKeyFor(
        AiProvider.gemini,
        'gemini-key-00000000000000001',
      );
      expect(okGemini, isTrue);
    });

    test(
      'a legacy single-provider Gemini key migrates on first launch',
      () async {
        const legacyKey = 'carepaws.gemini_api_key';
        const migrated = 'AIza-legacy-key-00000000000000000001';
        SharedPreferences.setMockInitialValues({legacyKey: migrated});

        final ai = AiService(client: _FailoverFake(triageJson));
        addTearDown(ai.dispose);
        await ai.bootstrap();

        // The key is picked up under the new per-provider name...
        expect(ai.statusFor(AiProvider.gemini).keyFromDevice, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AiProvider.gemini.keysPref), '["$migrated"]');
        // ...and the legacy entry is gone so the migration runs once.
        expect(prefs.getString(legacyKey), isNull);
      },
    );

    test('migration never overwrites a key saved under the new name', () async {
      const legacyKey = 'carepaws.gemini_api_key';
      SharedPreferences.setMockInitialValues({
        legacyKey: 'AIza-legacy-key-00000000000000000001',
        AiProvider.gemini.keysPref: '["AIza-new-key-0000000000000000000001"]',
      });

      final ai = AiService(client: _FailoverFake(triageJson));
      addTearDown(ai.dispose);
      await ai.bootstrap();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AiProvider.gemini.keysPref),
        '["AIza-new-key-0000000000000000000001"]',
      );
      expect(prefs.getString(legacyKey), isNull);
    });
  });

  group('Without a key the assistant is honestly unavailable', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('bootstrap lands on unavailable with the no-key reason', () async {
      final ai = AiService();
      addTearDown(ai.dispose);
      await ai.bootstrap();
      expect(ai.status, AiStatus.unavailable);
      expect(ai.failure, AiFailure.noKey);
      expect(ai.isLive, isFalse);
      expect(ai.modelId, isNull);
    });

    test('triage throws noKey instead of a canned answer', () async {
      final ai = AiService();
      addTearDown(ai.dispose);
      await ai.bootstrap();
      await expectLater(
        ai.triage(petName: 'Biscuit', species: 'dog', text: 'he is limping'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.noKey,
          ),
        ),
      );
    });

    test('chat throws noKey instead of a canned answer', () async {
      final ai = AiService();
      addTearDown(ai.dispose);
      await ai.bootstrap();
      await expectLater(
        ai.chat(
          petName: 'Biscuit',
          species: 'dog',
          question: 'what should he eat',
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.noKey,
          ),
        ),
      );
    });

    test('the unavailable UI copy names the failure and the fix', () {
      expect(aiUnavailableText(AiFailure.noKey), contains('no API key'));
      expect(
        aiUnavailableText(AiFailure.noKey),
        contains('Settings → CarePaws AI'),
      );
      expect(
        aiUnavailableText(AiFailure.unreachable),
        contains("couldn't reach"),
      );
      expect(
        aiUnavailableText(AiFailure.serviceError),
        contains('returned an error'),
      );
    });
  });

  group('Photos are stored on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // A tiny 1x1 PNG — enough to prove bytes survive the round trip.
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
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
      expect(
        store.petCount,
        countBefore,
        reason: 'editing must not duplicate the pet',
      );
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

/// Fake transport for the failover tests: Gemini answers the models list and
/// the liveness probe but 500s real requests; OpenAI answers everything
/// unless [openaiDown]. Request bodies are JSON, so the probe is recognised
/// by its "Reply with exactly this word: ok" text.
class _FailoverFake extends http.BaseClient {
  _FailoverFake(
    this.triageJson, {
    this.openaiDown = false,
    this.geminiGarbled = false,
  });

  final String triageJson;
  final bool openaiDown;

  /// When true, Gemini's content requests return 200 with non-JSON text —
  /// drives the malformed-reply failover path (not a transport error).
  final bool geminiGarbled;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    final path = request.url.path;
    var bodyText = '';
    if (request is http.Request) bodyText = request.body;
    final isProbe = bodyText.contains('Reply with exactly this word: ok');

    Object? body;
    var code = 200;
    if (host.contains('generativelanguage')) {
      if (path.endsWith('/models')) {
        body = {
          'models': [
            {
              'name': 'models/gemini-flash-test',
              'displayName': 'Flash (test)',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        };
      } else if (isProbe) {
        body = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
            },
          ],
        };
      } else if (geminiGarbled) {
        body = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'definitely not JSON, just chatter'},
                ],
              },
            },
          ],
        };
      } else {
        code = 500; // Real Gemini requests fail: failover must kick in.
        body = {'error': 'overloaded'};
      }
    } else {
      // OpenAI-compatible.
      if (openaiDown) {
        code = 500;
        body = {'error': 'down'};
      } else if (path.endsWith('/models')) {
        body = {
          'data': [
            {'id': 'gpt-4o-mini'},
          ],
        };
      } else {
        body = {
          'choices': [
            {
              'message': {'content': isProbe ? 'ok' : triageJson},
            },
          ],
        };
      }
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      code,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// The first Gemini key is rejected (401); the second answers. Drives
/// key-pool rotation: the request must succeed on the second key.
class _KeyRotationFake extends http.BaseClient {
  _KeyRotationFake(this.triageJson);

  final String triageJson;

  static const _badKey = 'gemini-key-00000000000000001';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    final path = request.url.path;
    final key = request.url.queryParameters['key'] ?? '';
    var bodyText = '';
    if (request is http.Request) bodyText = request.body;
    final isProbe = bodyText.contains('Reply with exactly this word: ok');

    Object? body;
    var code = 200;
    if (host.contains('generativelanguage')) {
      if (path.endsWith('/models')) {
        body = {
          'models': [
            {
              'name': 'models/gemini-flash-test',
              'displayName': 'Flash (test)',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        };
      } else if (isProbe) {
        // Probes succeed for both keys so bootstrap goes live on key one;
        // the real request is what rejects it.
        body = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
            },
          ],
        };
      } else if (key == _badKey) {
        code = 401;
        body = {'error': 'API key not valid'};
      } else {
        body = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': triageJson},
                ],
              },
            },
          ],
        };
      }
    } else {
      body = {
        'choices': [
          {
            'message': {'content': isProbe ? 'ok' : triageJson},
          },
        ],
      };
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      code,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// The first Gemini model 404s; the second answers. Drives model fallback.
class _ModelFallbackFake extends http.BaseClient {
  _ModelFallbackFake(this.triageJson);

  final String triageJson;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    final path = request.url.path;
    var bodyText = '';
    if (request is http.Request) bodyText = request.body;
    final isProbe = bodyText.contains('Reply with exactly this word: ok');

    Object? body;
    var code = 200;
    if (host.contains('generativelanguage')) {
      if (path.endsWith('/models')) {
        body = {
          'models': [
            {
              'name': 'models/gemini-flash-test',
              'displayName': 'Flash (test)',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-flash-test-2',
              'displayName': 'Flash 2 (test)',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        };
      } else if (isProbe) {
        body = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
            },
          ],
        };
      } else if (path.contains('gemini-flash-test:generateContent')) {
        // The primary model is gone; the fallback must answer instead.
        code = 404;
        body = {'error': 'model not found'};
      } else {
        body = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': triageJson},
                ],
              },
            },
          ],
        };
      }
    } else {
      body = {
        'choices': [
          {
            'message': {'content': isProbe ? 'ok' : triageJson},
          },
        ],
      };
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      code,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
