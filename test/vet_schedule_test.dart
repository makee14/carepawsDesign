import 'package:carepaws/data/clinic.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/data/scheduling.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/vet/schedule_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 4 — vet schedule screen (day view + appointment actions).
/// Written before the implementation (RED first).
///
/// Pins the spec:
/// - the day view groups appointments by calendar day; today is selected
///   by default;
/// - confirm moves requestPending -> confirmed;
/// - cancel marks cancelled and is one-way (terminal): there is no restore
///   path, and cancelled/completed appointments reject every other action;
/// - status advances follow the enforced chain
///   confirmed/booked -> beingGroomed (grooming) | completed,
///   beingGroomed -> readyForPickup -> completed;
///   illegal transitions are rejected by the store, not just the UI;
/// - reschedule only lands inside clinic hours (Mon–Sat, [Clinic.openHour]–
///   [Clinic.closeHour]);
/// - staff assignment reassigns the appointment's staffId.
DateTime _now() => DateTime(2026, 10, 17, 9, 30); // a Saturday

AppStore _store() {
  final s = AppStore(now: _now());
  addTearDown(s.dispose);
  return s;
}

Appointment _appt({
  String id = 't1',
  String serviceId = 'sv1', // Vet Consultation, 30 min, not grooming
  String staffId = 's1',
  DateTime? start,
  ApptStatus status = ApptStatus.confirmed,
}) => Appointment(
  id: id,
  petId: 'p1',
  serviceId: serviceId,
  staffId: staffId,
  start: start ?? DateTime(2026, 10, 17, 10, 0),
  durationMinutes: serviceId == 'sv4' ? 120 : 30,
  status: status,
  price: 850,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('schedule grouping', () {
    test('groups appointments by calendar day, sorted by start time', () {
      final s = _store();
      s.appointments = [
        _appt(
          id: 'a',
          start: DateTime(2026, 10, 19, 10, 0),
        ), // Mon, different day
        _appt(id: 'b', start: DateTime(2026, 10, 17, 10, 0)),
        _appt(id: 'c', start: DateTime(2026, 10, 17, 9, 0)),
      ];
      final grouped = groupAppointmentsByDay(s.appointments);
      expect(grouped.keys, hasLength(2));
      expect(grouped[DateTime(2026, 10, 17)]!.map((a) => a.id), ['c', 'b']);
      expect(grouped[DateTime(2026, 10, 19)]!.map((a) => a.id), ['a']);
    });

    test('an empty appointment list groups to an empty map', () {
      expect(groupAppointmentsByDay(const []), isEmpty);
    });
  });

  group('confirmAppointment', () {
    test('a pending request becomes confirmed', () {
      final s = _store();
      s.addAppointment(
        _appt(
          start: DateTime(2026, 10, 19, 10, 0),
          status: ApptStatus.requestPending,
        ),
      );
      expect(s.confirmAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.confirmed);
    });

    test('confirm is one-shot and rejects every other state', () {
      final s = _store();
      s.addAppointment(
        _appt(
          start: DateTime(2026, 10, 19, 10, 0),
          status: ApptStatus.requestPending,
        ),
      );
      expect(s.confirmAppointment('t1'), isTrue);
      expect(s.confirmAppointment('t1'), isFalse);
      for (final status in [
        ApptStatus.booked,
        ApptStatus.beingGroomed,
        ApptStatus.readyForPickup,
        ApptStatus.completed,
        ApptStatus.cancelled,
      ]) {
        s.addAppointment(_appt(id: 'x-${status.name}', status: status));
        expect(
          s.confirmAppointment('x-${status.name}'),
          isFalse,
          reason: 'confirm from $status',
        );
      }
      expect(s.confirmAppointment('nope'), isFalse);
    });
  });

  group('cancelAppointment', () {
    test('marks an active appointment cancelled', () {
      final s = _store();
      s.addAppointment(_appt());
      expect(s.cancelAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.cancelled);
    });

    test('cancel is terminal — nothing leads back out of cancelled', () {
      final s = _store();
      s.addAppointment(_appt());
      expect(s.cancelAppointment('t1'), isTrue);
      // No restore path exists: every other action is rejected.
      expect(s.cancelAppointment('t1'), isFalse);
      expect(s.confirmAppointment('t1'), isFalse);
      expect(s.advanceAppointment('t1'), isFalse);
      expect(
        s.rescheduleAppointment('t1', DateTime(2026, 10, 19, 10, 0)),
        isFalse,
      );
      expect(s.assignStaff('t1', 's2'), isFalse);
      expect(s.appt('t1')!.status, ApptStatus.cancelled);
    });

    test('cancel rejects completed appointments and unknown ids', () {
      final s = _store();
      s.addAppointment(_appt(status: ApptStatus.completed));
      expect(s.cancelAppointment('t1'), isFalse);
      expect(s.cancelAppointment('nope'), isFalse);
    });
  });

  group('advanceAppointment', () {
    test('grooming chain: confirmed -> beingGroomed -> readyForPickup -> completed', () {
      final s = _store();
      s.addAppointment(_appt(serviceId: 'sv4')); // Full Grooming
      expect(s.advanceAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.beingGroomed);
      expect(s.advanceAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.readyForPickup);
      expect(s.advanceAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.completed);
      // Terminal: nothing further.
      expect(s.advanceAppointment('t1'), isFalse);
    });

    test('non-grooming visits skip the grooming states', () {
      final s = _store();
      s.addAppointment(_appt(serviceId: 'sv1')); // Vet Consultation
      expect(s.advanceAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.completed);
    });

    test('a booked grooming appointment also enters the chain', () {
      final s = _store();
      s.addAppointment(_appt(serviceId: 'sv4', status: ApptStatus.booked));
      expect(s.advanceAppointment('t1'), isTrue);
      expect(s.appt('t1')!.status, ApptStatus.beingGroomed);
    });

    test('illegal transitions are rejected', () {
      final s = _store();
      // A request must be confirmed before it can advance.
      s.addAppointment(_appt(id: 'p', status: ApptStatus.requestPending));
      expect(s.advanceAppointment('p'), isFalse);
      expect(s.appt('p')!.status, ApptStatus.requestPending);
      // Terminal states never advance.
      s.addAppointment(_appt(id: 'done', status: ApptStatus.completed));
      expect(s.advanceAppointment('done'), isFalse);
      s.addAppointment(_appt(id: 'cx', status: ApptStatus.cancelled));
      expect(s.advanceAppointment('cx'), isFalse);
      expect(s.advanceAppointment('nope'), isFalse);
    });
  });

  group('rescheduleAppointment', () {
    test('moves an active appointment to a valid in-hours slot', () {
      final s = _store();
      s.addAppointment(_appt());
      final target = DateTime(2026, 10, 19, 10, 30); // a Monday
      expect(s.rescheduleAppointment('t1', target), isTrue);
      final moved = s.appt('t1')!;
      expect(moved.start, target);
      // The move keeps everything else: status, pet, staff, price.
      expect(moved.status, ApptStatus.confirmed);
      expect(moved.petId, 'p1');
      expect(moved.staffId, 's1');
    });

    test('rejects Sundays — the clinic is closed', () {
      final s = _store();
      s.addAppointment(_appt());
      expect(
        s.rescheduleAppointment('t1', DateTime(2026, 10, 18, 10, 0)),
        isFalse,
      );
      expect(s.appt('t1')!.start, DateTime(2026, 10, 17, 10, 0));
    });

    test('rejects slots that end after closing time', () {
      final s = _store();
      // 120-minute grooming starting 17:00 ends 19:00 — past the 18:00 close.
      s.addAppointment(_appt(serviceId: 'sv4'));
      expect(
        s.rescheduleAppointment('t1', DateTime(2026, 10, 19, 17, 0)),
        isFalse,
      );
    });

    test('rejects starts before opening and starts in the past', () {
      final s = _store();
      s.addAppointment(_appt());
      expect(
        s.rescheduleAppointment('t1', DateTime(2026, 10, 19, 8, 0)),
        isFalse,
      );
      expect(
        s.rescheduleAppointment('t1', DateTime(2026, 10, 16, 10, 0)),
        isFalse,
      );
      expect(s.appt('t1')!.start, DateTime(2026, 10, 17, 10, 0));
    });

    test('rejects rescheduling terminal appointments and unknown ids', () {
      final s = _store();
      s.addAppointment(_appt(status: ApptStatus.completed));
      expect(
        s.rescheduleAppointment('t1', DateTime(2026, 10, 19, 10, 0)),
        isFalse,
      );
      expect(
        s.rescheduleAppointment('nope', DateTime(2026, 10, 19, 10, 0)),
        isFalse,
      );
    });
  });

  group('assignStaff', () {
    test('reassigns the appointment to another staff member', () {
      final s = _store();
      s.addAppointment(_appt());
      expect(s.assignStaff('t1', 's2'), isTrue);
      expect(s.appt('t1')!.staffId, 's2');
    });

    test('rejects unknown staff and terminal appointments', () {
      final s = _store();
      s.addAppointment(_appt());
      expect(s.assignStaff('t1', 's9'), isFalse);
      expect(s.appt('t1')!.staffId, 's1');
      s.addAppointment(_appt(id: 'done', status: ApptStatus.completed));
      expect(s.assignStaff('done', 's2'), isFalse);
      expect(s.assignStaff('nope', 's2'), isFalse);
    });
  });

  group('shared day slots', () {
    test('Sundays have no slots — the clinic is closed', () {
      final s = _store();
      final service = s.serviceOf('sv1');
      expect(
        daySlots(
          DateTime(2026, 10, 18),
          service,
          s.staffOf('s1'),
          s.appointments,
          _now(),
        ),
        isEmpty,
      );
    });

    test('slots never end after closing time', () {
      final s = _store();
      final service = s.serviceOf('sv4'); // 120-minute grooming
      final slots = daySlots(
        DateTime(2026, 10, 19),
        service,
        s.staffOf('s3'),
        s.appointments,
        _now(),
      );
      expect(slots, isNotEmpty);
      final close = DateTime(2026, 10, 19, Clinic.closeHour);
      for (final slot in slots) {
        expect(
          slot.start.add(const Duration(minutes: 120)).isAfter(close),
          isFalse,
        );
      }
    });
  });

  group('schedule screen', () {
    Future<void> pumpSchedule(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const ScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('today is selected by default', (tester) async {
      final s = _store();
      s.addAppointment(_appt()); // today, 10:00
      await pumpSchedule(tester, s);
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel('Sat, 17 Oct, selected', skipOffstage: false),
        findsOneWidget,
      );
      // Today's appointment is the one shown.
      expect(
        find.textContaining('Vet Consultation', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('confirming a pending request from the day view', (
      tester,
    ) async {
      final s = _store();
      s.addAppointment(
        _appt(
          status: ApptStatus.requestPending,
          start: DateTime(2026, 10, 17, 11, 0),
        ),
      );
      await pumpSchedule(tester, s);
      expect(tester.takeException(), isNull);
      final confirm = find.text('Confirm');
      expect(confirm, findsOneWidget);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      // The card now reads Confirmed and the Confirm action is gone.
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Confirmed', skipOffstage: false), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Sunday shows the closed-clinic empty state', (tester) async {
      final s = _store();
      s.addAppointment(_appt());
      await pumpSchedule(tester, s);
      expect(tester.takeException(), isNull);
      // Tap the Sunday cell (18 Oct) in the day strip.
      final sunday = find.bySemanticsLabel('Sun, 18 Oct', skipOffstage: false);
      expect(sunday, findsOneWidget);
      await tester.tap(sunday);
      await tester.pumpAndSettle();
      expect(find.textContaining('Closed on Sundays'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AX5: the day view lays out without overflow', (tester) async {
      // Text-placement strictness pinned as a test: at 3.2x the day cells
      // widen and the card header/staff rows stack instead of overflowing.
      // Any RenderFlex overflow surfaces as a FlutterError, caught below.
      final s = _store();
      s.addAppointment(_appt());
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const ScheduleScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
