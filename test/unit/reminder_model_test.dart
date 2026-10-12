import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';

void main() {
  group('Reminder construction', () {
    test('title is required by the form layer, model holds it verbatim', () {
      final reminder = Reminder(
        title: 'Take medication',
        timesOfDayMinutes: [480],
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.medication,
        status: ReminderStatus.pending,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      expect(reminder.id, isNull);
      expect(reminder.title, equals('Take medication'));
      expect(reminder.hour, equals(8));
      expect(reminder.minute, equals(0));
    });

    test('hour accepts boundary values 0 and 23', () {
      final midnight = Reminder(
        title: 'Test', timesOfDayMinutes: [0],
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final late = Reminder(
        title: 'Test', timesOfDayMinutes: [1380],
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(midnight.hour, equals(0));
      expect(late.hour, equals(23));
    });

    test('minute accepts boundary values 0 and 59', () {
      final start = Reminder(
        title: 'Test', timesOfDayMinutes: [480],
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final end = Reminder(
        title: 'Test', timesOfDayMinutes: [539],
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(start.minute, equals(0));
      expect(end.minute, equals(59));
    });
  });

  group('Round-trip toJson/fromJson', () {
    test('preserves all fields', () {
      final original = Reminder(
        id: 7,
        title: 'Take medication',
        timesOfDayMinutes: [480],
        recurrence: Recurrence.daily,
        daysMask: 0,
        category: Category.medication,
        status: ReminderStatus.pending,
        nextFireAt: DateTime.parse('2026-10-07T08:00:00'),
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );

      final parsed = Reminder.fromJson(original.toJson());

      expect(parsed.id, equals(original.id));
      expect(parsed.title, equals(original.title));
      expect(parsed.hour, equals(original.hour));
      expect(parsed.minute, equals(original.minute));
      expect(parsed.recurrence, equals(original.recurrence));
      expect(parsed.daysMask, equals(original.daysMask));
      expect(parsed.category, equals(original.category));
      expect(parsed.status, equals(original.status));
      expect(parsed.nextFireAt, equals(original.nextFireAt));
      expect(parsed.createdAt, equals(original.createdAt));
      expect(parsed.updatedAt, equals(original.updatedAt));
    });

    test('fromJson reads weekly recurrence with days_mask', () {
      final reminder = Reminder.fromJson({
        'id': 2,
        'title': 'Weekly team sync',
        'hour': 10,
        'minute': 30,
        'recurrence': 'weekly',
        'days_mask': 42,
        'category': 'errand',
        'status': 'due',
        'next_fire_at': '2026-10-07T10:30:00',
        'created_at': '2026-10-06T09:00:00',
        'updated_at': '2026-10-06T09:00:00',
      });

      expect(reminder.id, equals(2));
      expect(reminder.recurrence, equals(Recurrence.weekly));
      expect(reminder.daysMask, equals(42));
      expect(reminder.category, equals(Category.errand));
      expect(reminder.status, equals(ReminderStatus.due));
      expect(reminder.nextFireAt, equals(DateTime.parse('2026-10-07T10:30:00')));
    });

    test('fromJson preserves null nextFireAt', () {
      final reminder = Reminder.fromJson({
        'id': 3,
        'title': 'Pay rent',
        'hour': 1,
        'minute': 0,
        'recurrence': 'custom',
        'days_mask': 254,
        'category': 'payment',
        'status': 'acknowledged',
        'next_fire_at': null,
        'created_at': '2026-10-06T12:00:00',
        'updated_at': '2026-10-06T12:00:00',
      });

      expect(reminder.id, equals(3));
      expect(reminder.recurrence, equals(Recurrence.custom));
      expect(reminder.nextFireAt, isNull);
    });

    test('toJson writes null next_fire_at when nextFireAt is null', () {
      final reminder = Reminder(
        title: 'Test',
        timesOfDayMinutes: [555],
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.appointment,
        status: ReminderStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = reminder.toJson();
      expect(json['next_fire_at'], isNull);
      expect(json['created_at'], isNotNull);
      expect(json['updated_at'], isNotNull);
    });
  });

  group('copyWith', () {
    test('replaces given fields and refreshes updatedAt by default', () {
      final original = Reminder(
        id: 5,
        title: 'Test',
        timesOfDayMinutes: [480],
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.other,
        status: ReminderStatus.pending,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );

      final updated = original.copyWith(status: ReminderStatus.completed);

      expect(updated.id, equals(5));
      expect(updated.title, equals('Test'));
      expect(updated.status, equals(ReminderStatus.completed));
      expect(
        updated.updatedAt.isAfter(original.updatedAt),
        isTrue,
        reason: 'copyWith should default updatedAt to now',
      );
    });
  });

  group('importance and urgency (Phase 2.1)', () {
    test('default to medium importance and low urgency', () {
      final reminder = Reminder(
        title: 'Test', timesOfDayMinutes: [480],
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      expect(reminder.importance, equals(Importance.medium));
      expect(reminder.urgency, equals(Urgency.low));
    });

    test('round-trips importance and urgency through toJson/fromJson', () {
      final original = Reminder(
        title: 'Take medication',
        timesOfDayMinutes: [480],
        recurrence: Recurrence.daily, daysMask: 0,
        category: Category.medication, status: ReminderStatus.pending,
        importance: Importance.high, urgency: Urgency.high,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      final parsed = Reminder.fromJson(original.toJson());
      expect(parsed.importance, equals(Importance.high));
      expect(parsed.urgency, equals(Urgency.high));
    });

    test('fromJson falls back to defaults for pre-v2 rows', () {
      final reminder = Reminder.fromJson({
        'id': 9,
        'title': 'Old row',
        'hour': 9,
        'minute': 0,
        'recurrence': 'once',
        'days_mask': 0,
        'category': 'other',
        'status': 'pending',
        'next_fire_at': null,
        'created_at': '2026-10-06T10:00:00',
        'updated_at': '2026-10-06T10:00:00',
      });
      expect(reminder.importance, equals(Importance.medium));
      expect(reminder.urgency, equals(Urgency.low));
    });

    test('fromJson falls back on unknown enum names', () {
      final reminder = Reminder.fromJson({
        'id': 10,
        'title': 'Odd row',
        'hour': 9,
        'minute': 0,
        'recurrence': 'once',
        'days_mask': 0,
        'category': 'other',
        'status': 'pending',
        'next_fire_at': null,
        'created_at': '2026-10-06T10:00:00',
        'updated_at': '2026-10-06T10:00:00',
        'importance': 'critical',
        'urgency': 'asap',
      });
      expect(reminder.importance, equals(Importance.medium));
      expect(reminder.urgency, equals(Urgency.low));
    });

    test('copyWith replaces importance and urgency', () {
      final original = Reminder(
        title: 'Test', timesOfDayMinutes: [480],
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      final updated = original.copyWith(
        importance: Importance.high,
        urgency: Urgency.high,
      );
      expect(updated.importance, equals(Importance.high));
      expect(updated.urgency, equals(Urgency.high));
    });
  });

  group('v4 rich time patterns', () {
    test('normalizes times to sorted unique', () {
      final reminder = Reminder(
        title: 'Test', timesOfDayMinutes: [1200, 480, 480],
        recurrence: Recurrence.daily, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      expect(reminder.timesOfDayMinutes, equals([480, 1200]));
    });

    test('hour/minute derive from the first entry', () {
      final reminder = Reminder(
        title: 'Test', timesOfDayMinutes: [1380, 480],
        recurrence: Recurrence.daily, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      expect(reminder.hour, equals(8));
      expect(reminder.minute, equals(0));
    });

    test('round-trips times and window through toJson/fromJson', () {
      final original = Reminder(
        title: 'Drink water', timesOfDayMinutes: [780, 960, 1200, 1380],
        recurrence: Recurrence.interval, daysMask: 62,
        category: Category.water, status: ReminderStatus.pending,
        intervalMinutes: 30,
        windowStartMinutes: 420,
        windowEndMinutes: 1380,
        createdAt: DateTime.parse('2026-10-06T10:00:00'),
        updatedAt: DateTime.parse('2026-10-06T10:00:00'),
      );
      final parsed = Reminder.fromJson(original.toJson());
      expect(parsed.timesOfDayMinutes, equals([780, 960, 1200, 1380]));
      expect(parsed.intervalMinutes, equals(30));
      expect(parsed.windowStartMinutes, equals(420));
      expect(parsed.windowEndMinutes, equals(1380));
    });

    test('fromJson falls back to legacy hour/minute for pre-v4 rows', () {
      final reminder = Reminder.fromJson({
        'id': 11,
        'title': 'Old row',
        'hour': 8,
        'minute': 30,
        'recurrence': 'daily',
        'days_mask': 0,
        'category': 'water',
        'status': 'pending',
        'next_fire_at': null,
        'created_at': '2026-10-06T10:00:00',
        'updated_at': '2026-10-06T10:00:00',
      });
      expect(reminder.timesOfDayMinutes, equals([510]));
      expect(reminder.windowStartMinutes, isNull);
      expect(reminder.windowEndMinutes, isNull);
    });
  });
}
