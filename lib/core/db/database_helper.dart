import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as p;

class DatabaseSchema {
  static const String table = 'reminders';
  static const String id = 'id';
  static const String title = 'title';
  static const String hour = 'hour';
  static const String minute = 'minute';
  static const String recurrence = 'recurrence';
  static const String daysMask = 'days_mask';
  static const String category = 'category';
  static const String status = 'status';
  static const String nextFireAt = 'next_fire_at';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String importance = 'importance';
  static const String urgency = 'urgency';

  static const String createTableSql = '''CREATE TABLE reminders(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, hour INTEGER, minute INTEGER, recurrence TEXT, days_mask INTEGER, category TEXT, status TEXT, next_fire_at TEXT, created_at TEXT, updated_at TEXT, importance TEXT, urgency TEXT)''';
}

Future<sql.Database> openAppDatabase() async {
  final dir = await sql.getDatabasesPath();
  final path = p.join(dir, 'nudge.db');
  return sql.openDatabase(
    path,
    version: 2,
    onCreate: (db, version) async {
      await db.execute(DatabaseSchema.createTableSql);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      // v2: Phase 2 added importance/urgency. Existing rows keep NULL and
      // Reminder.fromJson falls back to the field defaults.
      if (oldVersion < 2) {
        await db.execute(
            'ALTER TABLE ${DatabaseSchema.table} ADD COLUMN ${DatabaseSchema.importance} TEXT');
        await db.execute(
            'ALTER TABLE ${DatabaseSchema.table} ADD COLUMN ${DatabaseSchema.urgency} TEXT');
      }
    },
  );
}

Future<int> insertReminder(sql.Database db, Map<String, dynamic> data) => db.insert(DatabaseSchema.table, data);

Future<List<Map<String, dynamic>>> queryReminders(sql.Database db, {String? where}) => db.query(DatabaseSchema.table, where: where);

Future<int> updateReminder(sql.Database db, int id, Map<String, dynamic> data) => db.update(DatabaseSchema.table, data, where: '${DatabaseSchema.id} = ?', whereArgs: [id]);

Future<int> deleteReminder(sql.Database db, int id) => db.delete(DatabaseSchema.table, where: '${DatabaseSchema.id} = ?', whereArgs: [id]);