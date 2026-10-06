import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';

void main() {
  group('Reminder construction', () {
    test('title is required by the form layer, model holds it verbatim', () {
      final reminder = Reminder(
        title: 'Take medication',
        hour: 8,
        minute: 0,
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
        title: 'Test', hour: 0, minute: 0,
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final late = Reminder(
        title: 'Test', hour: 23, minute: 0,
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(midnight.hour, equals(0));
      expect(late.hour, equals(23));
    });

    test('minute accepts boundary values 0 and 59', () {
      final start = Reminder(
        title: 'Test', hour: 8, minute: 0,
        recurrence: Recurrence.once, daysMask: 0,
        category: Category.other, status: ReminderStatus.pending,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final end = Reminder(
        title: 'Test', hour: 8, minute: 59,
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
        hour: 8,
        minute: 0,
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
        hour: 9,
        minute: 15,
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
        hour: 8,
        minute: 0,
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
}
