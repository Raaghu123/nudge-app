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
    case Category.exercise:
    case Category.study:
    case Category.errand:
    case Category.payment:
      return const Duration(minutes: 60);
    case Category.appointment:
    case Category.other:
      return const Duration(minutes: 15);
  }
}

/// Distinct snooze durations (minutes) used for iOS notification
/// categories. iOS has no nested action submenus, so each duration gets
/// its own registered category with a pre-labelled Snooze action. Derived
/// from [snoozeDurationFor]: medication/appointment/other 15m, water 30m,
/// exercise/study/errand/payment 1h.
const List<int> iosSnoozeDurationsMinutes = [15, 30, 60];

/// Snooze button label for an iOS category: 15m/30m stay in minutes,
/// whole hours use "1h", a full day would use "1d".
String iosSnoozeLabel(int minutes) {
  switch (minutes) {
    case 60:
      return 'Snooze 1h';
    case 1440:
      return 'Snooze 1d';
    default:
      return 'Snooze ${minutes}m';
  }
}

/// iOS notification category id for a reminder's category, e.g.
/// `nudge_actions_30`. Durations outside [iosSnoozeDurationsMinutes]
/// fall back to the 15m category.
String iosCategoryIdFor(Category category) {
  final minutes = snoozeDurationFor(category).inMinutes;
  final capped =
      iosSnoozeDurationsMinutes.contains(minutes) ? minutes : 15;
  return 'nudge_actions_$capped';
}

DateTime? nextOccurrence({
  required DateTime now,
  required int hour,
  required int minute,
  required Recurrence recurrence,
  required int daysMask,
  int? intervalMinutes,
  DateTime? lastFire,
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

    case Recurrence.interval:
      // Defensive: corrupt or missing interval degrades to once with no
      // computable next fire rather than a zero-duration tight loop.
      if (intervalMinutes == null || intervalMinutes <= 0) return null;
      return (lastFire ?? now).add(Duration(minutes: intervalMinutes));
  }
}