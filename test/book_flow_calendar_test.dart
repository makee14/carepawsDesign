import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/appointments/book_flow.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Booking date/time rework: month-grid calendar + vet-availability slots.
///
/// fixedNow is Tue 2026-10-13 09:40 (clinic hours Mon–Sat 9:00–18:00).
/// Seed a1 books Dr. Rafael (s1, auto-assigned for vet services) on
/// Fri 2026-10-16 10:00–10:30; seed a2 books Ana (s3, groomer) on
/// Mon 2026-10-19 09:00–11:00.
DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

class _Launcher extends StatelessWidget {
  const _Launcher({required this.screen});
  final Widget screen;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Launcher')),
    child: Center(
      child: CupertinoButton(
        onPressed: () => Navigator.of(context).push(appRoute(screen)),
        child: const Text('Open'),
      ),
    ),
  );
}

Future<AppStore> pumpBookFlow(
  WidgetTester tester, {
  AppStore? store,
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final s = store ?? AppStore(now: now ?? fixedNow());
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const _Launcher(screen: BookFlow()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return s;
}

/// The nav-bar back chevron inside [DetailNavBar] — DetailNavBar's only
/// CupertinoButton is its back button.
Finder navBack() => find.descendant(
  of: find.byType(DetailNavBar),
  matching: find.byType(CupertinoButton),
);

/// Taps a time-slot pill: the slot Wrap can extend below the fold (and under
/// the floating StickyCta), so scroll it into view first.
Future<void> tapSlot(WidgetTester tester, String label) async {
  final finder = find.bySemanticsLabel(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pet → triage → service → date/time for a non-grooming service.
Future<void> toDateTimeStep(WidgetTester tester, String serviceName) async {
  await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(serviceName));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
  await tester.pumpAndSettle();
}

void main() {
  group('calendar + availability', () {
    testWidgets('booked slots render disabled and cannot be selected', (
      tester,
    ) async {
      await pumpBookFlow(tester);
      await toDateTimeStep(tester, 'Vet Consultation');
      expect(find.text('Oct 2026'), findsOneWidget);

      // Seed a1: Dr. Rafael is booked Fri 2026-10-16 10:00–10:30.
      await tester.tap(find.bySemanticsLabel('Fri, 16 Oct'));
      await tester.pumpAndSettle();
      expect(find.text('Available times'), findsOneWidget);

      // The booked slot is visible but disabled: tapping selects nothing.
      await tapSlot(tester, '10:00 AM');
      expect(
        (tester.widget(
          find.widgetWithText(PrimaryButton, 'Continue'),
        ) as PrimaryButton).onPressed,
        isNull,
        reason: 'tapping a booked slot must not select it',
      );

      // A free slot selects normally.
      await tapSlot(tester, '10:30 AM');
      expect(
        (tester.widget(
          find.widgetWithText(PrimaryButton, 'Continue'),
        ) as PrimaryButton).onPressed,
        isNotNull,
      );
    });

    testWidgets('empty day: graceful state with next-available jump', (
      tester,
    ) async {
      // Fill every slot of Thu 2026-10-15 for Dr. Rafael (s1): 9:00–17:30
      // every 30 minutes.
      final store = AppStore(now: fixedNow());
      for (var h = 9; h < 18; h++) {
        for (var m = 0; m < 60; m += 30) {
          store.appointments.add(
            Appointment(
              id: 'full$h$m',
              petId: 'p1',
              serviceId: 'sv1',
              staffId: 's1',
              start: DateTime(2026, 10, 15, h, m),
              durationMinutes: 30,
              status: ApptStatus.confirmed,
              price: 850,
            ),
          );
        }
      }
      await pumpBookFlow(tester, store: store);
      await toDateTimeStep(tester, 'Vet Consultation');

      await tester.tap(find.bySemanticsLabel('Thu, 15 Oct'));
      await tester.pumpAndSettle();
      expect(find.text('No times left on 15 Oct'), findsOneWidget);
      expect(find.text('Available times'), findsNothing);
      expect(
        find.text('Next available: Fri, 16 Oct'),
        findsOneWidget,
        reason: 'one-tap jump to the next open day',
      );

      // The jump button sits below the fold — scroll it into view first.
      await tester.ensureVisible(find.text('Next available: Fri, 16 Oct'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next available: Fri, 16 Oct'));
      await tester.pumpAndSettle();
      expect(find.text('Available times'), findsOneWidget);
      expect(find.text('No times left on 15 Oct'), findsNothing);
    });

    testWidgets('Sundays are unselectable: clinic closed', (tester) async {
      await pumpBookFlow(tester);
      await toDateTimeStep(tester, 'Vet Consultation');
      // Sun 2026-10-18 (exact semantics label carries the closed suffix).
      await tester.tap(find.bySemanticsLabel('Sun, 18 Oct, clinic closed'));
      await tester.pumpAndSettle();
      // Nothing selected: still the "choose a day" hint, no slots.
      expect(find.text('Available times'), findsNothing);
      expect(find.textContaining('Choose a day'), findsOneWidget);
    });

    testWidgets('calendar month navigation', (tester) async {
      // now = Wed 2026-10-28: the 14-day window (Oct 28 – Nov 10) crosses
      // the month boundary, so paging is real.
      await pumpBookFlow(tester, now: DateTime(2026, 10, 28, 9, 40));
      await toDateTimeStep(tester, 'Vet Consultation');
      expect(find.text('Oct 2026'), findsOneWidget);

      // Previous month is disabled on the current month.
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('Oct 2026'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('Nov 2026'), findsOneWidget);

      // A November day inside the window is selectable with real slots.
      await tester.tap(find.bySemanticsLabel('Mon, 2 Nov'));
      await tester.pumpAndSettle();
      expect(find.text('Available times'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('Oct 2026'), findsOneWidget);
    });

    testWidgets('no availability anywhere: call-the-clinic card, no dead end', (
      tester,
    ) async {
      // Book Dr. Rafael solid for the whole 14-day window.
      final store = AppStore(now: fixedNow());
      for (var d = 0; d < 14; d++) {
        final day = DateTime(2026, 10, 13 + d);
        if (day.weekday == DateTime.sunday) continue;
        for (var h = 9; h < 18; h++) {
          for (var m = 0; m < 60; m += 30) {
            store.appointments.add(
              Appointment(
                id: 'full${d}h$h$m',
                petId: 'p1',
                serviceId: 'sv1',
                staffId: 's1',
                start: DateTime(day.year, day.month, day.day, h, m),
                durationMinutes: 30,
                status: ApptStatus.confirmed,
                price: 850,
              ),
            );
          }
        }
      }
      await pumpBookFlow(tester, store: store);
      await toDateTimeStep(tester, 'Vet Consultation');

      expect(find.text('No availability right now'), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Call the clinic'),
        findsOneWidget,
      );
      // Continue is disabled with nothing to pick — the call card is the
      // only action, never a dead end.
      expect(
        (tester.widget(
          find.widgetWithText(PrimaryButton, 'Continue'),
        ) as PrimaryButton).onPressed,
        isNull,
      );
    });
  });

  group('restructured step order', () {
    testWidgets(
      'non-grooming: no questions step between service and date/time',
      (tester) async {
        await pumpBookFlow(tester);
        await toDateTimeStep(tester, 'Vet Consultation');
        // Landed directly on date/time: calendar, no service-questions step.
        expect(find.text('Oct 2026'), findsOneWidget);
        expect(find.text('Service details'), findsNothing);
        expect(find.text('Grooming intake'), findsNothing);
      },
    );

    testWidgets(
      'grooming: questions only in the details step, calendar+slots only in date/time',
      (tester) async {
        await pumpBookFlow(tester);
        // Pet → triage → service.
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
        // Full Grooming is below the fold in the service list.
        await tester.scrollUntilVisible(
          find.text('Full Grooming'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Full Grooming'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();

        // Details step: the per-service questions live here and only here.
        expect(find.text('Service details'), findsOneWidget);
        expect(find.text('Grooming intake'), findsOneWidget);
        expect(find.text('Notes for the groomer'), findsOneWidget);
        expect(find.text('Oct 2026'), findsNothing);
        expect(find.text('Available times'), findsNothing);

        // Step-aware back still works with the shifted indices.
        await tester.tap(navBack());
        await tester.pumpAndSettle();
        expect(find.text('What does Biscuit need?'), findsOneWidget);
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Service details'), findsOneWidget);

        // Date/time step: calendar + slots only — no service questions.
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Oct 2026'), findsOneWidget);
        expect(find.text('Service details'), findsNothing);
        expect(find.text('Grooming intake'), findsNothing);
        expect(find.text('Notes for the groomer'), findsNothing);

        // Seed a2 books Ana (auto-assigned groomer) Mon 2026-10-19 09:00–11:00,
        // so Fri 2026-10-16 9:00 AM is free for the 120-minute service.
        await tester.tap(find.bySemanticsLabel('Fri, 16 Oct'));
        await tester.pumpAndSettle();
        await tapSlot(tester, '9:00 AM');
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();

        // Review → confirm completes the reworked order.
        expect(find.text('Check the details, then confirm.'), findsOneWidget);
        expect(find.text('Grooming intake'), findsOneWidget);
        await tester.tap(find.widgetWithText(PrimaryButton, 'Confirm booking'));
        await tester.pumpAndSettle();
        expect(find.text('You are booked'), findsOneWidget);
      },
    );
  });
}
