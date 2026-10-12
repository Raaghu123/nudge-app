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
          timesOfDayMinutes: [480],
          recurrence: Recurrence.daily,
          daysMask: 0,
        )),
      );
    });
  });

  group('addReminder intervalMinutes', () {
    test('interval reminder keeps recurrence + minutes, first tick +30m', () async {
      final provider = newProvider();
      final before = DateTime.now();
      final saved = await provider.addReminder(
        title: 'Drink water',
        hour: 10,
        minute: 30,
        recurrence: Recurrence.interval,
        daysMask: 0,
        category: Category.water,
        intervalMinutes: 30,
      );

      expect(saved.recurrence, equals(Recurrence.interval));
      expect(saved.intervalMinutes, equals(30));
      // No scheduledAt: next fire is computed as now + 30 minutes.
      expect(saved.nextFireAt!.isAfter(before.add(const Duration(minutes: 29))), isTrue);
      expect(saved.nextFireAt!.isBefore(before.add(const Duration(minutes: 31))), isTrue);
    });

    test('intervalMinutes round-trips through the v3 column', () async {
      final provider = newProvider();
      await provider.addReminder(
        title: 'Drink water',
        hour: 10,
        minute: 30,
        recurrence: Recurrence.interval,
        daysMask: 0,
        category: Category.water,
        intervalMinutes: 30,
      );

      // A fresh provider re-reads from disk, proving the value survives
      // SQLite (not just the in-memory copy).
      final reloaded = newProvider();
      await reloaded.addReminder(
        title: 'Buy milk',
        hour: 18,
        minute: 0,
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.errand,
      );
      final water =
          reloaded.upcoming.firstWhere((r) => r.title == 'Drink water');
      expect(water.recurrence, equals(Recurrence.interval));
      expect(water.intervalMinutes, equals(30));
    });

    test('intervalMinutes round-trips through toJson/fromJson', () {
      final reminder = Reminder(
        title: 'Drink water',
        timesOfDayMinutes: [630],
        recurrence: Recurrence.interval,
        daysMask: 0,
        category: Category.water,
        status: ReminderStatus.pending,
        createdAt: DateTime(2026, 10, 6, 10, 0),
        updatedAt: DateTime(2026, 10, 6, 10, 0),
        intervalMinutes: 30,
      );
      final restored = Reminder.fromJson(reminder.toJson());
      expect(restored.recurrence, equals(Recurrence.interval));
      expect(restored.intervalMinutes, equals(30));
    });
  });

  group('addReminder rich time patterns', () {
    test('multi-time daily stores the full list and survives reload', () async {
      final provider = newProvider();
      final saved = await provider.addReminder(
        title: 'Drink water',
        hour: 13,
        minute: 0,
        recurrence: Recurrence.daily,
        daysMask: 0,
        category: Category.water,
        timesOfDayMinutes: [780, 960, 1200, 1380],
      );

      expect(saved.timesOfDayMinutes, equals([780, 960, 1200, 1380]));
      expect(saved.hour, equals(13));

      // A fresh provider re-reads from disk, proving the v4 column works.
      final reloaded = newProvider();
      await reloaded.addReminder(
        title: 'Buy milk',
        hour: 18,
        minute: 0,
        recurrence: Recurrence.once,
        daysMask: 0,
        category: Category.errand,
      );
      final water =
          reloaded.upcoming.firstWhere((r) => r.title == 'Drink water');
      expect(water.timesOfDayMinutes, equals([780, 960, 1200, 1380]));
    });

    test('windowed interval stores bounds and fires inside the window',
        () async {
      final provider = newProvider();
      final saved = await provider.addReminder(
        title: 'Drink water',
        hour: 7,
        minute: 0,
        recurrence: Recurrence.interval,
        daysMask: 0,
        category: Category.water,
        intervalMinutes: 30,
        windowStartMinutes: 420,
        windowEndMinutes: 1380,
      );

      expect(saved.intervalMinutes, equals(30));
      expect(saved.windowStartMinutes, equals(420));
      expect(saved.windowEndMinutes, equals(1380));
      expect(saved.nextFireAt, isNotNull);
      final fireMinutes =
          saved.nextFireAt!.hour * 60 + saved.nextFireAt!.minute;
      expect(fireMinutes >= 420 && fireMinutes <= 1380, isTrue);
    });
  });
}
