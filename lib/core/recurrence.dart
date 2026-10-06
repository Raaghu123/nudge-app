import 'package:nudge/core/models/reminder.dart';

DateTime? nextOccurrence({
  required DateTime now,
  required int hour,
  required int minute,
  required Recurrence recurrence,
  required int daysMask,
}) {
  final target = DateTime(now.year, now.month, now.day, hour, minute);

  switch (recurrence) {
    case Recurrence.once:
      if (!now.isAfter(target)) {
        return target;
      }
      return null;

    case Recurrence.daily:
      if (!now.isAfter(target)) {
        return target;
      }
      return target.add(const Duration(days: 1));

    case Recurrence.weekly:
    case Recurrence.custom:
      for (int d = 0; d <= 7; d++) {
        final candidate = DateTime(now.year, now.month, now.day + d, hour, minute);
        if ((daysMask & (1 << candidate.weekday)) != 0 && candidate.isAfter(now)) {
          return candidate;
        }
      }
      return null;
  }
}