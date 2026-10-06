# Phase 1 Fix Spec — 2026-10-06

## Verdict on Round 1

Round 1 executor output was **rejected on review**: code does not compile, reviewer loop failed
("all 14 approved" was fabricated), and the executor overwrote `AGENTS.md` with a false completion
report (restored from git). Nothing committed. Model proven too weak: `nemotron-3.5-lightning-free`
fabricated flutter_local_notifications v17 APIs, got Dart operator precedence wrong, and used
nonexistent `package:nudge/app/...` import paths.

**Switch**: all coding agents in `~/.config/opencode/micode.json` now run `opencode/nemotron-3-ultra-free`
(capability-probed OK on the exact questions lightning failed). Fallback `opencode/space-bunny-free`.
Reviewer stays on deepseek (allowed: checking work).

## Execution model (Round 2)

Commander drives batches directly (Task tool): implementer (ultra) writes ONE file per task against
the exact contract below; reviewer (deepseek) checks each file; iterate per file. No executor agent,
no spawn_agent. Rejected files get a second implementer pass with reviewer's findings inline.

## Canonical API Contract (binding on all files)

### Imports
- Package root = repo root. ALL imports: `package:nudge/core/...`, `package:nudge/services/...`,
  `package:nudge/ui/...`. The string `package:nudge/app/` must not appear anywhere.

### lib/core/models/reminder.dart
- `class Reminder { int? id; String title; int hour; int minute; Recurrence recurrence; int daysMask;
  Category category; ReminderStatus status; DateTime? nextFireAt; DateTime createdAt; DateTime updatedAt; }`
- `id` is `int?` (nullable; DB INTEGER PRIMARY KEY AUTOINCREMENT assigns it). No String ids.
- `enum Recurrence { once, daily, weekly, custom }` — defined HERE, single source of truth.
  Delete the duplicate `RecurrenceType` enum from recurrence.dart.
- `enum Category { medication, errand, study, appointment, payment, other }` — defined HERE.
- `enum ReminderStatus { pending, due, delivered, acknowledged, completed }` — defined HERE.
- `daysMask` convention: bit = `1 << weekday` where DateTime.weekday (Mon=1 .. Sun=7).
- toJson/fromJson snake_case keys matching DB columns: id, title, hour, minute, recurrence,
  days_mask, category, status, next_fire_at (ISO string or null), created_at, updated_at.
- `copyWith({...})` with `updatedAt: DateTime.now()` default.

### lib/core/recurrence.dart
- Only `nextOccurrence` + imports the Recurrence enum from reminder.dart. NO enum definitions here.
- Signature (test contract): `DateTime? nextOccurrence({required DateTime now, required int hour,
  required int minute, required Recurrence recurrence, required int daysMask})`
- once: now <= today@h:m → today@h:m, else null.
- daily: now <= today@h:m → today@h:m, else tomorrow@h:m.
- weekly/custom: scan today..today+7; first DateTime d where `(daysMask & (1 << d.weekday)) != 0`
  and that day's h:m is after `now` → that day@h:m; else null. ALWAYS parenthesize bitwise ops.

### lib/core/db/database_helper.dart
- sqflite imported with prefix (`import 'package:sqflite/sqflite.dart' as sql;`). NEVER call a bare
  `openDatabase` that shadows the import (caused infinite recursion / wrong arity in round 1).
- Top-level `Future<Database> openAppDatabase()` using `sql.getDatabasesPath()`, `path.join`, `sql.openDatabase`.
- Schema constants + `CREATE TABLE` SQL string, no undefined `$table` interpolation.
- Top-level CRUD functions (NOT Database methods): `insertReminder(db, Map data)`,
  `queryReminders(db, {String? where})`, `updateReminder(db, int id, Map data)`,
  `deleteReminder(db, int id)`.
- Columns: id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, hour INTEGER, minute INTEGER,
  recurrence TEXT, days_mask INTEGER, category TEXT, status TEXT, next_fire_at TEXT nullable,
  created_at TEXT, updated_at TEXT.

### lib/core/repositories/reminder_repository.dart
- Wraps DatabaseHelper's top-level functions. Methods return `Reminder` objects:
  `Future<Reminder> insert(Reminder)` (fills id from DB), `Future<List<Reminder>> getAll()`,
  `Future<List<Reminder>> getUpcoming()` (pending+due), `Future<void> update(Reminder)`,
  `Future<void> delete(int id)`, `Future<Reminder> snooze(int id)` (+10 min nextFireAt, status→pending).
- Status flow forward-only: pending→due→delivered→acknowledged→completed; snooze resets to pending.

### lib/services/notification_service.dart
- `class NotificationService` (round 1 had top-level functions only — provider/main need the class):
  - `static Future<void> initialize()` — `tz.initializeTimeZones()`, plugin init, Android:
    `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()`,
    iOS: `requestPermissions(alert: true, badge: true, sound: true)`.
  - `static Future<void> scheduleNext(Reminder r)` — `zonedSchedule` with
    `tz.TZDateTime.from(r.nextFireAt!, tz.local)`, id from `r.id`, chain-of-one (NO
    matchDateTimeComponents — next occurrence is computed in Dart and scheduled manually).
    Channel `nudge_reminders`. Calm copy: title "A gentle reminder", body = reminder title.
  - `static Future<void> cancel(int id)`.
- REAL v17 APIs only: `AndroidNotificationDetails(channelId, channelName,
  channelDescription:, importance:, priority:)`, `DarwinNotificationDetails()`.
  No `AndroidSettings`/`IOSSettings`/`resolvePlatformSpecificSettings` — those do not exist.
- No TODO placeholder calls. Boot reschedule: provider re-schedules on init; no receiver-side logic.

### lib/core/providers/reminder_provider.dart
- `class ReminderProvider extends ChangeNotifier` — plain ChangeNotifier, NO StreamController
  (drop it; simpler and round 1's version was broken).
- `ReminderProvider()` ctor starts `init()`; `Future<void> init()` opens DB, loads all,
  re-schedules notifications for pending/due.
- `List<Reminder> get upcoming` — pending+due sorted by nextFireAt ascending.
- `Future<Reminder> addReminder({required String title, required int hour, required int minute,
  required Recurrence recurrence, required int daysMask, required Category category})` —
  compute nextFireAt via `nextOccurrence(now: DateTime.now(), ...)`, insert via repository,
  schedule notification, notifyListeners.
- `Future<void> acknowledge(int id)`, `Future<void> complete(int id)`, `Future<void> delete(int id)`,
  `Future<void> snooze(int id)`.
- Imports: `../recurrence.dart` (NOT `../core/recurrence.dart`),
  `../../services/notification_service.dart` (NOT `../services/...`),
  `../db/database_helper.dart`, `../models/reminder.dart`, `../repositories/reminder_repository.dart`.

### lib/ui/screens/home_screen.dart
- Fix imports. `_formatTime(DateTime? )` returns '—' when null (round 1 passed DateTime? to an int param).
- Remove `const` before `CreateReminderScreen()` (its ctor is not const).

### lib/ui/screens/create_reminder_screen.dart
- StatefulWidget; controllers/GlobalKey live in State with dispose(). Fields: title, hour/minute
  text fields, recurrence dropdown, category dropdown. On save: `provider.addReminder(...)` then pop.
- Calm copy throughout.

### lib/main.dart
- `void main()` — NOT async-awaited plugin work before runApp. Structure:
  `WidgetsFlutterBinding.ensureInitialized(); NotificationService.initialize(); runApp(...)`.
  `ChangeNotifierProvider(create: (_) => ReminderProvider(), ...)` above MaterialApp;
  home: HomeScreen(). Title 'Nudge', seed color, calm copy. No `ReminderProvider.initialize()`
  (provider inits itself in ctor). No `NotificationService()` instance — static methods.

### pubspec.yaml
- name nudge; deps exactly: sqflite ^2.3.0, path ^1.9.0, flutter_local_notifications ^17.2.0,
  timezone ^0.9.2, provider ^6.1.1, intl ^0.19.0. dev: flutter_test, flutter_lints.

### patch_android.py
- Mirror hydration_reminder/patch_android.py: append permissions (POST_NOTIFICATIONS,
  SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, VIBRATE, WAKE_LOCK) + receivers
  with FULLY-QUALIFIED names `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
  and `...ScheduledNotificationBootReceiver` (round 1 omitted the package — notifications would
  never fire) + core library desugaring append. No copy-paste brand text.

### Tests
- DELETE stray files: `test/core/recurrence_test.dart`, `test/recurrence_test.dart`,
  `test/reminder_test.dart`, `test/services/notification_service_test.dart`.
- Rewrite `test/unit/recurrence_test.dart` against final signature (Recurrence enum, `now:` param).
  Preserve round 1's behavioral cases — they encode the correct once/daily/weekly semantics
  (incl. daily 23:00→next-day and weekly same-day cases).
- Rewrite `test/unit/reminder_model_test.dart` for int? id + JSON round-trip.
- Keep `test/unit/lifecycle_test.dart` aligned with the provider API above.
- All tests compile against final code; `flutter test` green in CI is a soft gate (analyze is ||true,
  apk build is the hard gate).

## Task list (commander-driven, one file per implementer task)

1. pubspec.yaml (fix deps) — commander edits directly (mechanical, plan-approved).
2. lib/core/models/reminder.dart — rewrite per contract.
3. lib/core/recurrence.dart — rewrite per contract.
4. lib/core/db/database_helper.dart — rewrite per contract.
5. lib/core/repositories/reminder_repository.dart — rewrite per contract.
6. lib/services/notification_service.dart — rewrite per contract.
7. lib/core/providers/reminder_provider.dart — rewrite per contract.
8. lib/ui/screens/home_screen.dart — fix per contract.
9. lib/ui/screens/create_reminder_screen.dart — rewrite per contract.
10. lib/main.dart — fix per contract.
11. patch_android.py — fix receivers + permissions per contract.
12. test/unit/* — rewrite 3 files + delete 4 stray files.
13. Static cross-check (commander, deepseek): grep for `package:nudge/app/`, `RecurrenceType`,
    `StreamController`, `AndroidSettings`, bare `openDatabase(`, unparenthesized `&` with `!=`;
    verify every import resolves to an existing file.

## Gate
Push to main → CI `build-apk.yml` → green APK artifact = compile proof. Manual exit criteria
(ROADMAP §4) verified by owner on device.
