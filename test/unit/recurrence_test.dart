import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';

void main() {
  group('nextOccurrence once', () {
    test('returns today at h:m when now is before target', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [840],
        recurrence: Recurrence.once,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 14, 0)));
    });

    test('returns target when now is exactly at target', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [600],
        recurrence: Recurrence.once,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 10, 0)));
    });

    test('returns null when now is after target', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [480],
        recurrence: Recurrence.once,
        daysMask: 0,
      );
      expect(result, isNull);
    });
  });

  group('nextOccurrence daily', () {
    test('returns today at h:m when now is before target', () {
      final now = DateTime(2026, 10, 6, 6, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [540],
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 9, 0)));
    });

    test('returns same moment when now is exactly at target', () {
      final now = DateTime(2026, 10, 6, 8, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [480],
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 8, 0)));
    });

    test('returns tomorrow at h:m when now is after target', () {
      final now = DateTime(2026, 10, 6, 23, 1);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [1380],
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 7, 23, 0)));
    });
  });

  group('nextOccurrence weekly / custom', () {
    // Bit = 1 << DateTime.weekday (Mon=1 .. Sun=7).
    // Bits 1, 3, 5 = Mon, Wed, Fri.
    const maskMonWedFri = 42; // 0b101010 unsupported: bits 1, 3, 5.

    test('weekly: returns today when today matches the mask', () {
      // 2026-10-07 is a Wednesday.
      final now = DateTime(2026, 10, 7, 8, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [600],
        recurrence: Recurrence.weekly,
        daysMask: maskMonWedFri,
      );
      expect(result, equals(DateTime(2026, 10, 7, 10, 0)));
    });

    test('weekly: skips non-matching days, finds next match', () {
      // 2026-10-08 is a Thursday; next match is Friday 2026-10-09.
      final now = DateTime(2026, 10, 8, 8, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [600],
        recurrence: Recurrence.weekly,
        daysMask: maskMonWedFri,
      );
      expect(result, equals(DateTime(2026, 10, 9, 10, 0)));
    });

    test('custom: behaves identically to weekly for the same mask', () {
      final now = DateTime(2026, 10, 8, 8, 0);
      final weekly = nextOccurrence(
        now: now,
        timesOfDayMinutes: [600],
        recurrence: Recurrence.weekly,
        daysMask: maskMonWedFri,
      );
      final custom = nextOccurrence(
        now: now,
        timesOfDayMinutes: [600],
        recurrence: Recurrence.custom,
        daysMask: maskMonWedFri,
      );
      expect(custom, equals(weekly));
    });

    test('weekly: returns null when the mask is empty', () {
      final now = DateTime(2026, 10, 6, 8, 0);
      final result = nextOccurrence(
        now: now,
        timesOfDayMinutes: [600],
        recurrence: Recurrence.weekly,
        daysMask: 0,
      );
      expect(result, isNull);
    });
  });

  group('nextOccurrence interval', () {
    test('interval 60 with no window returns now + 60 min', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 10, 0),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 0,
        intervalMinutes: 60,
      );
      expect(result, equals(DateTime(2026, 10, 6, 11, 0)));
    });

    test('null intervalMinutes returns null (once-like defensive)', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 10, 30),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 0,
      );
      expect(result, isNull);
    });

    test('zero intervalMinutes returns null (no tight loop)', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 10, 30),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 0,
        intervalMinutes: 0,
      );
      expect(result, isNull);
    });
  });

  group('nextOccurrence multi-time daily', () {
    const times = [780, 960, 1200, 1380]; // 1pm, 4pm, 8pm, 11pm.

    test('picks the next time later today', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 14, 0),
        timesOfDayMinutes: times,
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 16, 0)));
    });

    test('rolls to the first time tomorrow when today is exhausted', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 23, 30),
        timesOfDayMinutes: times,
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 7, 13, 0)));
    });
  });

  group('nextOccurrence windowed interval', () {
    test('rounds up to the next tick inside the window', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 7, 14),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 0,
        intervalMinutes: 30,
        windowStartMinutes: 420,
        windowEndMinutes: 1380,
      );
      expect(result, equals(DateTime(2026, 10, 6, 7, 30)));
    });

    test('last tick lands exactly on the window end', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 22, 47),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 0,
        intervalMinutes: 30,
        windowStartMinutes: 420,
        windowEndMinutes: 1380,
      );
      expect(result, equals(DateTime(2026, 10, 6, 23, 0)));
    });

    test('rolls to window start tomorrow when today is exhausted', () {
      final result = nextOccurrence(
        now: DateTime(2026, 10, 6, 23, 15),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 0,
        intervalMinutes: 30,
        windowStartMinutes: 420,
        windowEndMinutes: 1380,
      );
      expect(result, equals(DateTime(2026, 10, 7, 7, 0)));
    });

    test('skips masked-out days to the next valid window', () {
      // 2026-10-10 is a Saturday; mask 62 = Mon-Fri.
      final result = nextOccurrence(
        now: DateTime(2026, 10, 10, 10, 0),
        timesOfDayMinutes: const [],
        recurrence: Recurrence.interval,
        daysMask: 62,
        intervalMinutes: 120,
        windowStartMinutes: 540,
        windowEndMinutes: 1080,
      );
      expect(result, equals(DateTime(2026, 10, 12, 9, 0)));
    });
  });

  group('snoozeDurationFor', () {
    test('medication snoozes 15 minutes', () {
      expect(
        snoozeDurationFor(Category.medication),
        equals(const Duration(minutes: 15)),
      );
    });

    test('water snoozes 30 minutes', () {
      expect(
        snoozeDurationFor(Category.water),
        equals(const Duration(minutes: 30)),
      );
    });

    test('study, errand, and payment snooze 60 minutes', () {
      const hour = Duration(minutes: 60);
      expect(snoozeDurationFor(Category.study), equals(hour));
      expect(snoozeDurationFor(Category.errand), equals(hour));
      expect(snoozeDurationFor(Category.payment), equals(hour));
    });

    test('appointment and other fall back to 15 minutes', () {
      const quarter = Duration(minutes: 15);
      expect(snoozeDurationFor(Category.appointment), equals(quarter));
      expect(snoozeDurationFor(Category.other), equals(quarter));
    });
  });
}
