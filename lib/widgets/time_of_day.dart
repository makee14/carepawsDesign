import 'package:flutter/foundation.dart';
/// Minimal Cupertino-friendly replacement for Material's `TimeOfDay`.
/// The app never imports Material, so this keeps the tree Cupertino-only.
@immutable
class TimeOfDay {
  const TimeOfDay({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is TimeOfDay && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
