import 'package:sqflite/sqflite.dart' as sql;
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';
import 'package:nudge/core/db/database_helper.dart' as db;

class ReminderRepository {
  final sql.Database _db;

  ReminderRepository(this._db);

  Future<Reminder> insert(Reminder r) async {
    final id = await db.insertReminder(_db, r.toJson());
    return r.copyWith(id: id);
  }

  Future<List<Reminder>> getAll() async {
    final rows = await db.queryReminders(_db);
    return rows.map((m) => Reminder.fromJson(m)).toList();
  }

  Future<List<Reminder>> getUpcoming() async {
    final all = await getAll();
    return all.where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.due).toList();
  }

  Future<void> update(Reminder r) async {
    await db.updateReminder(_db, r.id!, r.toJson());
  }

  Future<void> delete(int id) async {
    await db.deleteReminder(_db, id);
  }

  Future<Reminder> snooze(int id) async {
    final all = await getAll();
    final r = all.firstWhere((e) => e.id == id);
    final next =
        (r.nextFireAt ?? DateTime.now()).add(snoozeDurationFor(r.category));
    final updated = r.copyWith(nextFireAt: next, status: ReminderStatus.pending);
    await update(updated);
    return updated;
  }

  /// Completes one step of a sequential reminder, or the reminder itself.
  ///
  /// Shared by the foreground ([ReminderProvider.complete]) and background
  /// ([notificationTapBackground]) 'done' paths so both behave
  /// identically. Returns the updated reminder; callers cancel the fired
  /// notification when [Reminder.status] is completed, otherwise
  /// reschedule via [NotificationService.scheduleNext]:
  /// - No steps: existing behavior (status = completed).
  /// - Not on the last step: index advances, status stays pending. When
  ///   now is inside today's window (or no window is set) the next fire
  ///   is 30 seconds out; outside the window it is tomorrow's window
  ///   start (same time tomorrow when windowless, unreachable in
  ///   practice since windowless is always "inside").
  /// - On the last step: status = completed; [startNextCycle] rolls the
  ///   next recurrence cycle back to step 0.
  Future<Reminder> completeStep(int id, {DateTime? now}) async {
    final ref = now ?? DateTime.now();
    final all = await getAll();
    final r = all.firstWhere((e) => e.id == id);
    if (r.sequentialSteps.isEmpty ||
        r.currentStepIndex >= r.sequentialSteps.length - 1) {
      final done = r.copyWith(status: ReminderStatus.completed);
      await update(done);
      return done;
    }
    final nowMinutes = ref.hour * 60 + ref.minute;
    final withinWindow = r.windowStartMinutes == null ||
        r.windowEndMinutes == null ||
        (nowMinutes >= r.windowStartMinutes! &&
            nowMinutes <= r.windowEndMinutes!);
    final DateTime nextFire;
    if (withinWindow) {
      nextFire = ref.add(const Duration(seconds: 30));
    } else if (r.windowStartMinutes != null) {
      final ws = r.windowStartMinutes!;
      nextFire =
          DateTime(ref.year, ref.month, ref.day + 1, ws ~/ 60, ws % 60);
    } else {
      nextFire = DateTime(
          ref.year, ref.month, ref.day + 1, ref.hour, ref.minute, ref.second);
    }
    final updated = r.copyWith(
      currentStepIndex: r.currentStepIndex + 1,
      status: ReminderStatus.pending,
      nextFireAt: nextFire,
    );
    await update(updated);
    return updated;
  }

  /// Rolls a completed sequential reminder into its next recurrence
  /// cycle: index back to 0, status to pending, next fire recomputed
  /// via [nextOccurrence]. The in-app cycle trigger is still open (no
  /// path re-arms completed reminders yet); this is the entry point
  /// when one lands.
  Future<Reminder> startNextCycle(int id, {DateTime? now}) async {
    final ref = now ?? DateTime.now();
    final all = await getAll();
    final r = all.firstWhere((e) => e.id == id);
    final next = nextOccurrence(
      now: ref,
      timesOfDayMinutes: r.timesOfDayMinutes,
      recurrence: r.recurrence,
      daysMask: r.daysMask,
      intervalMinutes: r.intervalMinutes,
      windowStartMinutes: r.windowStartMinutes,
      windowEndMinutes: r.windowEndMinutes,
    );
    final rolled = r.copyWith(
      currentStepIndex: 0,
      status: ReminderStatus.pending,
      nextFireAt: next,
    );
    await update(rolled);
    return rolled;
  }
}