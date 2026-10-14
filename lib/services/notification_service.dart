import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// Hide the domain Importance: this file's `Importance.max` is the
// flutter_local_notifications channel importance, not the reminder field.
import 'package:nudge/core/models/reminder.dart' hide Importance;
import 'package:nudge/core/recurrence.dart';
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
        final updated = await repo.completeStep(id);
        if (updated.status == ReminderStatus.completed) {
          print('NudgeBg: marked id=$id completed, cancelling notification');
          await NotificationService.cancel(id);
        } else {
          print('NudgeBg: advanced id=$id to step '
              '${updated.currentStepIndex}, rescheduling');
          await NotificationService.cancel(id);
          await NotificationService.scheduleNext(updated);
          // Best-effort re-arm when the next step comes due. If the OS
          // kills this isolate before it fires, the scheduled alarm
          // above still delivers the step on time.
          Future.delayed(const Duration(seconds: 30), () async {
            try {
              print('NudgeBg: 30s best-effort re-arm for id=$id');
              await NotificationService.scheduleNext(updated);
            } catch (e) {
              print('NudgeBg: 30s re-arm skipped for id=$id: $e');
            }
          });
        }
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

  /// iOS notification categories, one per distinct snooze duration (see
  /// [iosSnoozeDurationsMinutes] in recurrence.dart). iOS attaches actions
  /// via categories registered at init (unlike Android, which puts them
  /// on each notification), has no nested submenus, and offers no
  /// styled/primary button — both actions stay normal (never red).
  /// Every scheduled notification references its duration's identifier
  /// via iosCategoryIdFor in scheduleNext.
  static List<DarwinNotificationCategory> _iosCategories() {
    return <DarwinNotificationCategory>[
      for (final minutes in iosSnoozeDurationsMinutes)
        DarwinNotificationCategory(
          'nudge_actions_$minutes',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('done', 'Mark done'),
            DarwinNotificationAction.plain('snooze', iosSnoozeLabel(minutes)),
          ],
        ),
    ];
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Not const: DarwinNotificationAction.plain is a non-const factory, and
    // notificationCategories takes a List.
    final iosInit = DarwinInitializationSettings(
      notificationCategories: _iosCategories(),
    );
    await _plugin.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
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
    // Not const: the iOS categoryIdentifier varies per reminder category.
    // The Android block is intentionally unchanged by the iOS polish.
    final details = NotificationDetails(
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
      // iOS shows the Mark done / Snooze <duration> buttons via the
      // per-duration category registered at init; the action ids match
      // the Android ones so the existing onAction routing handles both
      // platforms unchanged.
      iOS: DarwinNotificationDetails(
          categoryIdentifier: iosCategoryIdFor(r.category)),
    );
    await _plugin.zonedSchedule(
      r.id ?? 0,
      _stepTitle(r),
      _stepBody(r),
      tzDate,
      details,
      // alarmClock (AlarmManager.setAlarmClock) instead of exactAllowWhileIdle:
      // OxygenOS 16 downgrades setExactAndAllowWhileIdle to an inexact,
      // windowed alarm even with SCHEDULE_EXACT_ALARM granted and battery
      // unrestricted. setAlarmClock is the same API real clock apps use and
      // OEMs cannot window it. Trade-off: a status-bar alarm icon, which is
      // acceptable for a reminder app.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) async => _plugin.cancel(id);

  /// Notification title: the current step for sequential reminders,
  /// the umbrella title otherwise. The index is clamped defensively so
  /// a stale value can never throw inside the scheduler.
  static String _stepTitle(Reminder r) {
    if (r.sequentialSteps.isEmpty) return r.title;
    return r.sequentialSteps[_safeStepIndex(r)];
  }

  /// Notification body: "<umbrella> — step N of M" for sequential
  /// reminders, null (existing behavior) otherwise.
  static String? _stepBody(Reminder r) {
    if (r.sequentialSteps.isEmpty) return null;
    final index = _safeStepIndex(r);
    return '${r.title} — step ${index + 1} of ${r.sequentialSteps.length}';
  }

  static int _safeStepIndex(Reminder r) {
    if (r.currentStepIndex < 0) return 0;
    if (r.currentStepIndex >= r.sequentialSteps.length) {
      return r.sequentialSteps.length - 1;
    }
    return r.currentStepIndex;
  }
}