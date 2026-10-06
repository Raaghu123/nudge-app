import 'package:flutter/foundation.dart' hide Category;
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';
import 'package:nudge/core/db/database_helper.dart';
import 'package:nudge/core/repositories/reminder_repository.dart';
import 'package:nudge/services/notification_service.dart';

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

  List<Reminder> get upcoming {
    final list = _reminders.where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.due).toList();
    list.sort((a, b) {
      final at = a.nextFireAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.nextFireAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    return list;
  }

  Future<Reminder> addReminder({
    required String title,
    required int hour,
    required int minute,
    required Recurrence recurrence,
    required int daysMask,
    required Category category,
  }) async {
    await _ensureInit();
    final now = DateTime.now();
    final next = nextOccurrence(now: now, hour: hour, minute: minute, recurrence: recurrence, daysMask: daysMask);
    final r = Reminder(
      title: title,
      hour: hour,
      minute: minute,
      recurrence: recurrence,
      daysMask: daysMask,
      category: category,
      status: ReminderStatus.pending,
      nextFireAt: next,
      createdAt: now,
      updatedAt: now,
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
    if (actionId == 'done') {
      complete(id);
    } else if (actionId == 'snooze') {
      snooze(id);
    } else {
      acknowledge(id);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}