import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nudge/core/models/reminder.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static void Function(int id, String? actionId)? onAction;

  static void _onResponse(NotificationResponse response) {
    onAction?.call(response.id, response.actionId);
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onResponse,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
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
      'A gentle reminder',
      r.title,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancel(int id) async => _plugin.cancel(id);
}