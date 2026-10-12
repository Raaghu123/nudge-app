import 'package:flutter/foundation.dart' hide Category;
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';
import 'package:nudge/core/db/database_helper.dart';
import 'package:nudge/core/repositories/reminder_repository.dart';
import 'package:nudge/services/notification_service.dart';
import 'package:nudge/services/oem_settings.dart';

class ReminderProvider extends ChangeNotifier {
  ReminderRepository? _repo;
  Future<void>? _initFuture;
  List<Reminder> _reminders = [];

  ReminderProvider() {
    NotificationService.onAction = _handleNotificationAction;
    _initFuture = _init();
  }

  Future<void> _init() async {
    final db = await openAppDatabase();
    _repo = ReminderRepository(db);
    _reminders = await _repo!.getAll();
    final now = DateTime.now();
    for (final r in _reminders) {
      if (r.status == ReminderStatus.pending &&
          r.nextFireAt != null &&
          !r.nextFireAt!.isAfter(now)) {
        final due = r.copyWith(status: ReminderStatus.due);
        await _repo!.update(due);
        _replace(due);
      }
    }
    for (final r in _reminders) {
      if (r.status == ReminderStatus.pending || r.status == ReminderStatus.due) {
        await NotificationService.scheduleNext(r);
      }
    }
    notifyListeners();
  }

  Future<void> _ensureInit() async {
    if (_initFuture != null) {
      await _initFuture;
    }
  }

  /// Opens the OEM autostart / battery allowlist screen for this device
  /// (app details page as fallback), so the user can exempt Nudge from
  /// aggressive power management. Call path for future UI wiring.
  Future<bool> openAutostartSettings() => OemSettings.openAutostartSettings();

  /// Everything still needing the user's attention. Delivered/acknowledged
  /// reminders stay visible until explicitly completed, snoozed (which
  /// returns them to pending), or deleted — a bare notification tap must
  /// never make a reminder vanish. Only completed reminders are hidden.
  List<Reminder> get upcoming {
    final list = _reminders.where((r) => r.status != ReminderStatus.completed).toList();
    list.sort((a, b) {
      final at = a.nextFireAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.nextFireAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    return list;
  }

  /// Creates a reminder from the form or the natural-language capture UI.
  ///
  /// [importance]/[urgency] fall back to the model defaults when null, so
  /// the form path (which omits them) is unchanged. [scheduledAt], when
  /// provided by the NL parser, becomes [Reminder.nextFireAt] directly:
  /// the parser distinguishes "at 3pm" from "tomorrow at 3pm" (both
  /// hour=15, minute=0) and only scheduledAt carries that difference.
  /// [timesOfDayMinutes]/[windowStartMinutes]/[windowEndMinutes], when
  /// provided by the NL capture UI, are stored as-is; otherwise the
  /// reminder is single-time at [hour]:[minute].
  Future<Reminder> addReminder({
    required String title,
    required int hour,
    required int minute,
    required Recurrence recurrence,
    required int daysMask,
    required Category category,
    Importance? importance,
    Urgency? urgency,
    DateTime? scheduledAt,
    int? intervalMinutes,
    List<int>? timesOfDayMinutes,
    int? windowStartMinutes,
    int? windowEndMinutes,
  }) async {
    await _ensureInit();
    final now = DateTime.now();
    final times = timesOfDayMinutes ?? [hour * 60 + minute];
    final next = scheduledAt ??
        nextOccurrence(
            now: now,
            timesOfDayMinutes: times,
            recurrence: recurrence,
            daysMask: daysMask,
            intervalMinutes: intervalMinutes,
            windowStartMinutes: windowStartMinutes,
            windowEndMinutes: windowEndMinutes);
    final r = Reminder(
      title: title,
      timesOfDayMinutes: times,
      recurrence: recurrence,
      daysMask: daysMask,
      category: category,
      status: ReminderStatus.pending,
      nextFireAt: next,
      createdAt: now,
      updatedAt: now,
      importance: importance ?? Importance.medium,
      urgency: urgency ?? Urgency.low,
      intervalMinutes: intervalMinutes,
      windowStartMinutes: windowStartMinutes,
      windowEndMinutes: windowEndMinutes,
    );
    final saved = await _repo!.insert(r);
    _reminders.add(saved);
    await NotificationService.scheduleNext(saved);
    notifyListeners();
    return saved;
  }

  Future<void> acknowledge(int id) async {
    await _ensureInit();
    final r = _reminders.firstWhere((e) => e.id == id);
    final updated = r.copyWith(status: ReminderStatus.acknowledged);
    await _repo!.update(updated);
    _replace(updated);
    notifyListeners();
  }

  Future<void> complete(int id) async {
    await _ensureInit();
    final r = _reminders.firstWhere((e) => e.id == id);
    final updated = r.copyWith(status: ReminderStatus.completed);
    await _repo!.update(updated);
    await NotificationService.cancel(id);
    _replace(updated);
    notifyListeners();
  }

  Future<void> deleteReminder(int id) async {
    await _ensureInit();
    await _repo!.delete(id);
    await NotificationService.cancel(id);
    _reminders.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> snooze(int id) async {
    await _ensureInit();
    // Dismiss the fired notification first: rescheduling under the same id
    // does not reliably clear what is already on screen.
    await NotificationService.cancel(id);
    final updated = await _repo!.snooze(id);
    await NotificationService.scheduleNext(updated);
    _replace(updated);
    notifyListeners();
  }

  void _replace(Reminder r) {
    final i = _reminders.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      _reminders[i] = r;
    }
  }

  void _handleNotificationAction(int id, String? actionId) {
    _markDelivered(id);
    if (actionId == 'done') {
      complete(id);
    } else if (actionId == 'snooze') {
      snooze(id);
    } else {
      acknowledge(id);
    }
  }

  /// Records that the notification reached the user: tapping it (or one of
  /// its actions) proves delivery, so pending/due becomes delivered before
  /// the action itself is applied.
  Future<void> _markDelivered(int id) async {
    await _ensureInit();
    final i = _reminders.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final r = _reminders[i];
    if (r.status == ReminderStatus.pending || r.status == ReminderStatus.due) {
      final delivered = r.copyWith(status: ReminderStatus.delivered);
      await _repo!.update(delivered);
      _reminders[i] = delivered;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}