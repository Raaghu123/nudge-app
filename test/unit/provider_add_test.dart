import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/providers/reminder_provider.dart';
import 'package:nudge/core/recurrence.dart';

/// Exercises the real [ReminderProvider.addReminder] against an FFI-backed
/// sqflite database. The notifications plugin has no VM implementation, so
/// its method channel is stubbed: scheduleNext's zonedSchedule call is
/// swallowed and tests assert on saved database state, not delivery.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall call) async => null,
    );
  });

  setUp(() async {
    // Fresh database per test: the provider always opens nudge.db.
    await databaseFactory
        .deleteDatabase(p.join(await getDatabasesPath(), 'nudge.db'));
  });

  ReminderProvider newProvider() => ReminderProvider();

  group('addReminder importance/urgency', () {
    test('saves explicit importance and urgency', () async {
      final provider = newProvider();
      final saved = await provider.addReminder(
        title: 'Take thyroid pill',
        hour: 8,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
        category: Category.medication,
        importance: Importance.high,
        urgency: Urgency.high,
      );

      expect(saved.importance, equals(Importance.high));
      expect(saved.urgency, equals(Urgency.high));
    });

    test('persists importance/urgency through the v2 columns', () async {
      final provider = newProvider();
      await provider.addReminder(
        title: 'Take thyroid pill',
        hour: 8,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
        category: Category.medication,
        importance: Importance.high,
        urgency: Urgency.high,
      );

      // A fresh provider re-reads from disk, proving the values round-trip
      // through SQLite (not just the in-memory copy).
      final reloaded = newProvider();
      // Allow the constructor's async init to settle via any call.
      await reloaded.addReminder(
        title: 'Drink water',
        hour: 9,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
        category: Category.water,
      );
      final pill =
          reloaded.upcoming.firstWhere((r) => r.title == 'Take thyroid pill');
      expect(pill.importance, equals(Importance.high));
      expect(pill.urgency, equals(Urgency.high));
    });

    test('falls back to model defaults when omitted (form path)', () async {
      final provider = newProvider();
      final saved = await provider.addReminder(
        title: 'Buy milk',
        hour: 18,
        minute: 0,
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.errand,
      );

      expect(saved.importance, equals(Importance.medium));
      expect(saved.urgency, equals(Urgency.low));
    });
  });

  group('addReminder scheduledAt', () {
    test('uses the provided scheduledAt as nextFireAt verbatim', () async {
      final provider = newProvider();
      final now = DateTime.now();
      // Tomorrow 15:00: hour/minute alone (15:00) would recompute to a
      // different instant, so this proves scheduledAt is not recomputed.
      final fireAt = DateTime(now.year, now.month, now.day + 1, 15, 0);
      final saved = await provider.addReminder(
        title: 'Call John',
        hour: 15,
        minute: 0,
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.appointment,
        scheduledAt: fireAt,
      );

      expect(saved.nextFireAt, equals(fireAt));
    });

    test('without scheduledAt keeps nextOccurrence behavior', () async {
      final provider = newProvider();
      final before = DateTime.now();
      final saved = await provider.addReminder(
        title: 'Take thyroid pill',
        hour: 8,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
        category: Category.medication,
      );

      expect(
        saved.nextFireAt,
        equals(nextOccurrence(
          now: before,
          hour: 8,
          minute: 0,
          recurrence: Recurrence.daily,
          daysMask: 0,
        )),
      );
    });
  });
}
