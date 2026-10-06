import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';

void main() {
  group('nextOccurrence once', () {
    test('returns today at h:m when now is before target', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final result = nextOccurrence(
        now: now,
        hour: 14,
        minute: 0,
        recurrence: Recurrence.once,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 14, 0)));
    });

    test('returns target when now is exactly at target', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final result = nextOccurrence(
        now: now,
        hour: 10,
        minute: 0,
        recurrence: Recurrence.once,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 10, 0)));
    });

    test('returns null when now is after target', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final result = nextOccurrence(
        now: now,
        hour: 8,
        minute: 0,
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
        hour: 9,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 9, 0)));
    });

    test('returns same moment when now is exactly at target', () {
      final now = DateTime(2026, 10, 6, 8, 0);
      final result = nextOccurrence(
        now: now,
        hour: 8,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 6, 8, 0)));
    });

    test('returns tomorrow at h:m when now is after target', () {
      final now = DateTime(2026, 10, 6, 23, 1);
      final result = nextOccurrence(
        now: now,
        hour: 23,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
      );
      expect(result, equals(DateTime(2026, 10, 7, 23, 0)));
    });
  });

  group('nextOccurrence weekly / custom', () {
    // Bit = 1 << DateTime.weekday (Mon=1 .. Sun=7).
    // Bits 1, 3, 5 = Mon, Wed, Fri.
    const maskMonWedFri = 0b101010;

    test('weekly: returns today when today matches the mask', () {
      // 2026-10-07 is a Wednesday.
      final now = DateTime(2026, 10, 7, 8, 0);
      final result = nextOccurrence(
        now: now,
        hour: 10,
        minute: 0,
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
        hour: 10,
        minute: 0,
        recurrence: Recurrence.weekly,
        daysMask: maskMonWedFri,
      );
      expect(result, equals(DateTime(2026, 10, 9, 10, 0)));
    });

    test('custom: behaves identically to weekly for the same mask', () {
      final now = DateTime(2026, 10, 8, 8, 0);
      final weekly = nextOccurrence(
        now: now,
        hour: 10,
        minute: 0,
        recurrence: Recurrence.weekly,
        daysMask: maskMonWedFri,
      );
      final custom = nextOccurrence(
        now: now,
        hour: 10,
        minute: 0,
        recurrence: Recurrence.custom,
        daysMask: maskMonWedFri,
      );
      expect(custom, equals(weekly));
    });

    test('weekly: returns null when the mask is empty', () {
      final now = DateTime(2026, 10, 6, 8, 0);
      final result = nextOccurrence(
        now: now,
        hour: 10,
        minute: 0,
        recurrence: Recurrence.weekly,
        daysMask: 0,
      );
      expect(result, isNull);
    });
  });
}
