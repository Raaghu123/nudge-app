import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';

/// Lifecycle transition tests for the reminder application.
/// States: pending → due → delivered → acknowledged → completed.
///
/// The phase-1 provider maps onto this table:
///   acknowledge(id) → acknowledged, complete(id) → completed,
///   snooze(id) → pending with nextFireAt pushed by the per-category
///   snooze duration (see snoozeDurationFor in recurrence.dart).
///
/// Valid single-step transitions (given→expect):
///   pending→due, due→delivered, delivered→acknowledged, acknowledged→completed,
///   plus snooze (due→due, next fire pushed by category duration).

/// Returns whether a transition from [from] to [to] is valid.
/// Forward-only along the lifecycle order; staying in place (snooze) is valid.
bool transition(ReminderStatus from, ReminderStatus to) {
  if (from == to) return true;
  return to.index > from.index;
}

void main() {
  group('Lifecycle valid transitions', () {
    test('pending → due is valid', () {
      expect(transition(ReminderStatus.pending, ReminderStatus.due), isTrue);
    });

    test('due → delivered is valid', () {
      expect(transition(ReminderStatus.due, ReminderStatus.delivered), isTrue);
    });

    test('delivered → acknowledged is valid', () {
      expect(
        transition(ReminderStatus.delivered, ReminderStatus.acknowledged),
        isTrue,
      );
    });

    test('acknowledged → completed is valid', () {
      expect(
        transition(ReminderStatus.acknowledged, ReminderStatus.completed),
        isTrue,
      );
    });

    test('due → due (snooze, pushed by category duration) is valid', () {
      expect(transition(ReminderStatus.due, ReminderStatus.due), isTrue);
    });
  });

  group('Lifecycle invalid transitions', () {
    test('pending → completed is invalid (skips intermediate states)', () {
      expect(
        transition(ReminderStatus.pending, ReminderStatus.completed),
        isFalse,
      );
    });

    test('due → pending is invalid (goes backward)', () {
      expect(transition(ReminderStatus.due, ReminderStatus.pending), isFalse);
    });

    test('delivered → pending is invalid (goes backward)', () {
      expect(
        transition(ReminderStatus.delivered, ReminderStatus.pending),
        isFalse,
      );
    });

    test('acknowledged → due is invalid (goes backward)', () {
      expect(
        transition(ReminderStatus.acknowledged, ReminderStatus.due),
        isFalse,
      );
    });

    test('completed → any earlier state is invalid (terminal state)', () {
      expect(
        transition(ReminderStatus.completed, ReminderStatus.pending),
        isFalse,
      );
      expect(transition(ReminderStatus.completed, ReminderStatus.due), isFalse);
      expect(
        transition(ReminderStatus.completed, ReminderStatus.delivered),
        isFalse,
      );
      expect(
        transition(ReminderStatus.completed, ReminderStatus.acknowledged),
        isFalse,
      );
    });
  });
}
