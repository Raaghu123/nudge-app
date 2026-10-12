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

/// Next fire time at or after [now] for the given schedule, or null when
/// none can be computed (empty times with no interval, unknown mask day,
/// corrupt interval).
///
/// [timesOfDayMinutes] holds the daily/weekly/custom fire times as minutes
/// since midnight (sorted by the model; re-sorted here defensively).
/// [daysMask] also gates [Recurrence.interval] (0 = all days).
/// Windowed intervals are stateless: ticks are windowStart + N * interval
/// and the next fire is the smallest tick after [now] on a valid day,
/// rolling to windowStart on the next valid day when today is exhausted.
DateTime? nextOccurrence({
  required DateTime now,
  required List<int> timesOfDayMinutes,
  required Recurrence recurrence,
  required int daysMask,
  int? intervalMinutes,
  int? windowStartMinutes,
  int? windowEndMinutes,
}) {
  final times = List<int>.of(timesOfDayMinutes)..sort();

  switch (recurrence) {
    case Recurrence.once:
      if (times.isEmpty) return null;
      final first = times.first;
      final target = DateTime(
          now.year, now.month, now.day, first ~/ 60, first % 60);
      if (!now.isAfter(target)) {
        return target;
      }
      return null;

    case Recurrence.daily:
      for (int d = 0; d <= 1; d++) {
        for (final t in times) {
          final candidate = DateTime(
              now.year, now.month, now.day + d, t ~/ 60, t % 60);
          if (!now.isAfter(candidate)) {
            return candidate;
          }
        }
      }
      return null;

    case Recurrence.weekly:
    case Recurrence.custom:
      for (int d = 0; d <= 7; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        if ((daysMask & (1 << day.weekday)) == 0) continue;
        for (final t in times) {
          final candidate =
              DateTime(day.year, day.month, day.day, t ~/ 60, t % 60);
          if (candidate.isAfter(now)) {
            return candidate;
          }
        }
      }
      return null;

    case Recurrence.interval:
      // Defensive: corrupt or missing interval degrades to no computable
      // next fire rather than a zero-duration tight loop.
      if (intervalMinutes == null || intervalMinutes <= 0) return null;
      if (windowStartMinutes == null ||
          windowEndMinutes == null ||
          windowStartMinutes >= windowEndMinutes) {
        return now.add(Duration(minutes: intervalMinutes));
      }
      return _nextWindowedTick(
          now, intervalMinutes, windowStartMinutes, windowEndMinutes, daysMask);
  }
}

/// Smallest tick windowStart + N * interval (N >= 0, tick <= windowEnd)
/// after [now] on a day accepted by [daysMask] (0 = any day); rolls to
/// windowStart on the next valid day when no tick remains today.
DateTime? _nextWindowedTick(
  DateTime now,
  int intervalMinutes,
  int windowStartMinutes,
  int windowEndMinutes,
  int daysMask,
) {
  for (int d = 0; d <= 7; d++) {
    final day = DateTime(now.year, now.month, now.day + d);
    if (daysMask != 0 && (daysMask & (1 << day.weekday)) == 0) continue;
    final startToday = DateTime(day.year, day.month, day.day,
        windowStartMinutes ~/ 60, windowStartMinutes % 60);
    final endToday = DateTime(day.year, day.month, day.day,
        windowEndMinutes ~/ 60, windowEndMinutes % 60);
    if (d == 0 && now.isBefore(startToday)) {
      return startToday;
    }
    if (d > 0) {
      return startToday;
    }
    final elapsed = now.difference(startToday).inMinutes;
    final tick =
        startToday.add(Duration(minutes: (elapsed ~/ intervalMinutes + 1) * intervalMinutes));
    if (!tick.isAfter(endToday)) {
      return tick;
    }
    // Today's window is exhausted; the loop rolls to the next valid day.
  }
  return null;
}