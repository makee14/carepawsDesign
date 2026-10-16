/// Single source of truth for CarePaws Veterinary Clinic facts.
///
/// Every screen, the AI service and the seed data read from here — clinic
/// facts are never duplicated as string literals anywhere else.
abstract final class Clinic {
  static const name = 'CarePaws Veterinary Clinic';
  static const address =
      'Unit 12, Greenhills Shopping Centre, Shaw Blvd, Brgy. Shaw, Mandaluyong City';
  static const phone = '+63 2 8712 4409';

  /// After-hours fallback for urgent concerns.
  static const afterHoursName = 'Animal Emergency Center — Mandaluyong';
  static const afterHoursPhone = '+63 2 8556 0190';

  /// Mon–Sat 9:00 AM – 6:00 PM. Closed Sundays.
  static const openHour = 9;
  static const closeHour = 18;
  static const hoursLabel = 'Mon–Sat 9:00 AM – 6:00 PM · Closed Sundays';

  /// Short forms derived from [openHour]/[closeHour] — use these instead of
  /// hardcoding times in UI strings.
  static String get openTimeLabel => '$openHour:00 AM';
  static String get closeTimeLabel => '${closeHour - 12}:00 PM';
  static String get hoursRangeLabel => '$openHour:00 AM – ${closeHour - 12}:00 PM';

  /// Walk-in cutoff, one hour before close.
  static String get walkInCutoffLabel => '${closeHour - 13}:00 PM';

  static const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String weekdayName(int weekday) => weekdayNames[weekday - 1];

  static bool isOpenNow(DateTime t) {
    if (t.weekday == DateTime.sunday) return false;
    return t.hour >= openHour && t.hour < closeHour;
  }

  /// The next 9:00 AM opening on a non-Sunday. Call only when closed — the
  /// result is meaningless while [isOpenNow] is true.
  static DateTime nextOpening(DateTime t) {
    var day = DateTime(t.year, t.month, t.day);
    if (t.weekday != DateTime.sunday && t.hour < openHour) {
      return day.add(const Duration(hours: openHour));
    }
    do {
      day = day.add(const Duration(days: 1));
    } while (day.weekday == DateTime.sunday);
    return day.add(const Duration(hours: openHour));
  }
}
