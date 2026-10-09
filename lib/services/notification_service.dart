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
@pragma('vm:entry-point')
Future<void> _backgroundResponse(NotificationResponse response) async {
  final id = response.id;
  if (id == null) return;
  tz.initializeTimeZones();
  final database = await db.openAppDatabase();
  try {
    final repo = ReminderRepository(database);
    final all = await repo.getAll();
    if (!all.any((e) => e.id == id)) return;
    final actionId = response.actionId;
    if (actionId == 'done') {
      final r = all.firstWhere((e) => e.id == id);
      await repo.update(r.copyWith(status: ReminderStatus.completed));
      await NotificationService.cancel(id);
    } else if (actionId == 'snooze') {
      await NotificationService.cancel(id);
      final updated = await repo.snooze(id);
      await NotificationService.scheduleNext(updated);
    } else {
      final r = all.firstWhere((e) => e.id == id);
      if (r.status == ReminderStatus.pending ||
          r.status == ReminderStatus.due) {
        await repo.update(r.copyWith(status: ReminderStatus.acknowledged));
      }
    }
  } finally {
    await database.close();
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static void Function(int id, String? actionId)? onAction;

  static void _onResponse(NotificationResponse response) {
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
      onDidReceiveBackgroundNotificationResponse: _backgroundResponse,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> scheduleNext(Reminder r) async {
    if (r.nextFireAt == null) return;
    final tzDate = tz.TZDateTime.from(r.nextFireAt!, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'nudge_reminders',
        'Reminders',
        channelDescription: 'Reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('done', 'Done'),
          AndroidNotificationAction('snooze', 'Snooze'),
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