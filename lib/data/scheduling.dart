import 'package:flutter/foundation.dart';

import 'clinic.dart';
import 'models.dart';

/// One bookable slot on a clinic day.
@immutable
class DaySlot {
  const DaySlot({required this.start, required this.available});

  final DateTime start;
  final bool available;
}

/// Every theoretical slot on [day] for [service] with [staff], flagged by
/// real availability.
///
/// Clinic hours come from [Clinic] (Mon–Sat 9–18, closed Sundays); a slot is
/// unavailable when it overlaps one of the staff member's active appointments
/// that day. Past days and Sundays return no slots at all.
///
/// One canonical implementation: the customer booking flow and the vet
/// reschedule sheet both build on this, so the rule can never drift between
/// the two.
List<DaySlot> daySlots(
  DateTime day,
  Service service,
  Staff staff,
  List<Appointment> appointments,
  DateTime now,
) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d.weekday == DateTime.sunday || d.isBefore(today)) return const [];
  // Slot spacing follows the service duration: grooming 1–2h, assistant
  // 15–20m, vet consults 30m.
  final floor = switch (service.role) {
    StaffRole.groomer => const Duration(minutes: 60),
    StaffRole.vet => const Duration(minutes: 30),
    StaffRole.vetAssistant => const Duration(minutes: 15),
  };
  final len = Duration(minutes: service.durationMinutes);
  final step = len > floor ? len : floor;
  final open = DateTime(d.year, d.month, d.day, Clinic.openHour);
  final close = DateTime(d.year, d.month, d.day, Clinic.closeHour);
  final booked = appointments
      .where(
        (a) =>
            a.staffId == staff.id &&
            a.status.isActive &&
            a.start.year == d.year &&
            a.start.month == d.month &&
            a.start.day == d.day,
      )
      .toList();
  final lead = now.add(const Duration(minutes: 30));
  final out = <DaySlot>[];
  // A slot must END by closing time, and start at least 30 minutes out.
  for (var t = open; !t.add(len).isAfter(close); t = t.add(step)) {
    if (t.isBefore(lead)) continue;
    final end = t.add(len);
    final clash = booked.any((a) => t.isBefore(a.end) && a.start.isBefore(end));
    out.add(DaySlot(start: t, available: !clash));
  }
  return out;
}
