import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/db/database_helper.dart' as db;
import 'package:nudge/core/repositories/reminder_repository.dart';

/// Handles notification actions when the app process is dead.
///
/// The foreground handler ([NotificationService.onAction], wired to the
/// provider) only runs while a Dart isolate is alive — e.g. the app is open
/// or backgrounded. When the user swipes the app away and later taps Snooze
/// or Done on a fired notification, no isolate exists to receive it, so the
/// tap would be silently dropped. This entry-point runs in a background
/// isolate instead and applies the action straight to the database, then
/// reschedules or cancels via the plugin.
///
/// Public top-level function (not private): the native side looks this
/// callback up by handle, so it must survive tree-shaking (hence the
/// entry-point pragma) and stay referenceable.
///
/// Logging: every step prints a `NudgeBg:` line so a cold action tap can be
/// traced end-to-end in logcat (`adb logcat | grep NudgeBg`). Any failure is
/// caught and printed with the exact exception instead of failing silently.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  // REQUIRED first line: this runs in a background isolate where the
  // generated Dart plugin registrant never ran. Without it, every plugin
  // call below (sqflite open/query/update, plugin cancel/schedule) throws
  // MissingPluginException and the action silently does nothing.
  // (dart:ui, idempotent, must not be called on the root isolate.)
  DartPluginRegistrant.ensureInitialized();
  print('NudgeBg: fired id=${response.id} actionId=${response.actionId}');
  final id = response.id;
  if (id == null) {
    print('NudgeBg: null notification id, ignoring');
    return;
  }
  try {
    print('NudgeBg: opening database for id=$id');
    tz.initializeTimeZones();
    final database = await db.openAppDatabase();
    try {
      final repo = ReminderRepository(database);
      print('NudgeBg: loading reminders for id=$id');
      final all = await repo.getAll();
      if (!all.any((e) => e.id == id)) {
        print('NudgeBg: id=$id not in database, ignoring');
        return;
      }
      final actionId = response.actionId;
      if (actionId == 'done') {
        print('NudgeBg: branch=done for id=$id');
        final r = all.firstWhere((e) => e.id == id);
        await repo.update(r.copyWith(status: ReminderStatus.completed));
        print('NudgeBg: marked id=$id completed, cancelling notification');
        await NotificationService.cancel(id);
      } else if (actionId == 'snooze') {
        print('NudgeBg: branch=snooze for id=$id');
        print('NudgeBg: cancelling notification id=$id before snooze');
        await NotificationService.cancel(id);
        print('NudgeBg: snoozing id=$id in database');
        final updated = await repo.snooze(id);
        print('NudgeBg: rescheduling id=$id for ${updated.nextFireAt}');
        await NotificationService.scheduleNext(updated);
      } else {
        print('NudgeBg: branch=tap (no action) for id=$id');
        final r = all.firstWhere((e) => e.id == id);
        if (r.status == ReminderStatus.pending ||
            r.status == ReminderStatus.due) {
          await repo.update(r.copyWith(status: ReminderStatus.acknowledged));
          print('NudgeBg: marked id=$id acknowledged');
        }
      }
    } finally {
      await database.close();
    }
    print('NudgeBg: handled id=$id actionId=${response.actionId}');
  } catch (e) {
    print('NudgeBg: ERROR id=$id actionId=${response.actionId}: $e');
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static void Function(int id, String? actionId)? onAction;

  static void _onResponse(NotificationResponse response) {
    print('NudgeFg: id=${response.id} actionId=${response.actionId}');
    final id = response.id;
    if (id != null) onAction?.call(id, response.actionId);
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    // Ground truth for exact-alarm privilege on this device. If this logs
    // false, every exactAllowWhileIdle schedule silently degrades to an
    // inexact alarm (batched/delayed by Android) no matter what the
    // manifest declares — check Settings > Alarms & reminders.
    final canExact = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.canScheduleExactNotifications();
    print('NudgeSched: canScheduleExactNotifications=$canExact');
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> scheduleNext(Reminder r) async {
    if (r.nextFireAt == null) return;
    final tzDate = tz.TZDateTime.from(r.nextFireAt!, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      print('NudgeSched: skipping id=${r.id} (fire time ${r.nextFireAt!.toIso8601String()} is in the past)');
      return;
    }
    // Proves the exact instant programmed into AlarmManager: compare the
    // epoch here against the observed delivery time in logcat to tell an
    // app-side time bug apart from platform-side batching/delay.
    print('NudgeSched: scheduling id=${r.id} fireAt=${tzDate.toIso8601String()} epoch=${tzDate.millisecondsSinceEpoch}');
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'nudge_reminders',
        'Reminders',
        channelDescription: 'Reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        // showsUserInterface: false (the default, stated explicitly) keeps
        // action taps on the background broadcast path instead of launching
        // the app; the foreground/background handlers route on actionId.
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('done', 'Done', showsUserInterface: false),
          AndroidNotificationAction('snooze', 'Snooze',
              showsUserInterface: false),
        ],
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      r.id ?? 0,
      r.title,
      null,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) async => _plugin.cancel(id);
}