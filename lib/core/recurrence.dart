import 'package:nudge/core/models/reminder.dart';

/// Snooze duration per category (UX.md section 4.3).
///
/// Medication snaps back quickly; water gets half an hour; study, errands,
/// and payments get an hour. Anything else (appointments, uncategorised)
/// falls back to the 15-minute default.
Duration snoozeDurationFor(Category category) {
  switch (category) {
    case Category.medication:
      return const Duration(minutes: 15);
    case Category.water:
      return const Duration(minutes: 30);
    case Category.study:
    case Category.errand:
    case Category.payment:
      return const Duration(minutes: 60);
    case Category.appointment:
    case Category.other:
      return const Duration(minutes: 15);
  }
}

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