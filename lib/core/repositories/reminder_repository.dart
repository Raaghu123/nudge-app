import 'package:sqflite/sqflite.dart' as sql;
import 'package:nudge/core/models/reminder.dart';
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
    final next = (r.nextFireAt ?? DateTime.now()).add(const Duration(minutes: 10));
    final updated = r.copyWith(nextFireAt: next, status: ReminderStatus.pending);
    await update(updated);
    return updated;
  }
}