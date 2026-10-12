import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';

void main() {
  group('iosCategoryIdFor', () {
    test('maps every category to its snooze-duration category', () {
      expect(iosCategoryIdFor(Category.medication), equals('nudge_actions_15'));
      expect(iosCategoryIdFor(Category.appointment), equals('nudge_actions_15'));
      expect(iosCategoryIdFor(Category.other), equals('nudge_actions_15'));
      expect(iosCategoryIdFor(Category.water), equals('nudge_actions_30'));
      expect(iosCategoryIdFor(Category.exercise), equals('nudge_actions_60'));
      expect(iosCategoryIdFor(Category.study), equals('nudge_actions_60'));
      expect(iosCategoryIdFor(Category.errand), equals('nudge_actions_60'));
      expect(iosCategoryIdFor(Category.payment), equals('nudge_actions_60'));
    });

    test('every category resolves to a registered duration', () {
      for (final category in Category.values) {
        final id = iosCategoryIdFor(category);
        final minutes = int.parse(id.split('_').last);
        expect(
          iosSnoozeDurationsMinutes,
          contains(minutes),
          reason: '$category mapped to unregistered $id',
        );
      }
    });

    test('agrees with snoozeDurationFor for every category', () {
      for (final category in Category.values) {
        expect(
          iosCategoryIdFor(category),
          equals('nudge_actions_${snoozeDurationFor(category).inMinutes}'),
        );
      }
    });
  });

  group('iosSnoozeLabel', () {
    test('labels minutes, hours, and days', () {
      expect(iosSnoozeLabel(15), equals('Snooze 15m'));
      expect(iosSnoozeLabel(30), equals('Snooze 30m'));
      expect(iosSnoozeLabel(60), equals('Snooze 1h'));
      expect(iosSnoozeLabel(1440), equals('Snooze 1d'));
    });
  });
}
