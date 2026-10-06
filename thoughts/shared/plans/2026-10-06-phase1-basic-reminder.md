# Phase 1 — Basic Reminder App (Nudge)

Date: 2026-10-06
Status: Draft for approval
Model: coding on `opencode/nemotron-3.5-lightning-free` (muse-spark-1.3 rate-limited; fallback `opencode/space-bunny-free`).

## 1. Scope (ROADMAP §4)

Build a plain, boring reminder app. No intelligence. Local-first, offline.

In scope:
- SQLite (sqflite)
- Reminder model: title, time, recurrence (once / daily / weekly / custom), category
- Create-reminder form (no natural language)
- Recurring reminders
- Local notification at the set time
- Notification actions: done, snooze
- Home screen showing upcoming reminders
- Lifecycle: pending → due → delivered → acknowledged → completed (plus snooze → back to due)
- Persistence across app restarts

Out of scope (guardrails — do not build):
- No NL input, no context awareness, no learning, no location, no calendar, no voice, no suggestions.

## 2. Decisions

### 2.1 Directory layout
ROADMAP §0 sketches a nested `app/lib/`. The committed Phase 0 scaffold uses the standard Flutter layout (`lib/` + `pubspec.yaml` at repo root), which CI (`flutter create .`) requires. Decision: keep the standard layout and map ROADMAP's `core/` and `ui/` into `lib/`. `components/` and `adapters/` are for intelligence phases (2+) and are deferred. (Flagged for owner — see §9.)

```
lib/
  main.dart
  core/
    models/reminder.dart              # Reminder + ReminderStatus enum
    db/database_helper.dart           # sqflite open + schema
    repositories/reminder_repository.dart  # CRUD + lifecycle transitions
    recurrence.dart                   # next-occurrence computation
    providers/reminder_provider.dart  # state + scheduling wiring
  services/notification_service.dart  # flutter_local_notifications
  ui/
    screens/home_screen.dart
    screens/create_reminder_screen.dart
test/
  unit/recurrence_test.dart
  unit/lifecycle_test.dart
  unit/reminder_model_test.dart
```

### 2.2 State management
`provider` + `ChangeNotifier` (matches hydration_reminder precedent). Offline-first, no remote.

### 2.3 DB schema — `reminders` table
| column | type | notes |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| title | TEXT NOT NULL | user intent, verbatim |
| hour | INTEGER | 0–23 (time-of-day) |
| minute | INTEGER | 0–59 |
| recurrence | TEXT NOT NULL | 'once' \| 'daily' \| 'weekly' \| 'custom' |
| days_mask | INTEGER | bitmask 0–6 (Sun–Sat) for weekly/custom; null otherwise |
| category | TEXT | medication, errand, study, appointment, payment, other |
| status | TEXT NOT NULL default 'pending' | pending/due/delivered/acknowledged/completed |
| next_fire_at | INTEGER | epoch ms; null when nothing pending |
| created_at | INTEGER | epoch ms |
| updated_at | INTEGER | epoch ms |

### 2.4 Notification approach (modeled on hydration_reminder)
- `flutter_local_notifications` v17+ via `zonedSchedule`; `timezone` package for TZDateTime.
- BANNED: `flutter_timezone`.
- Chain-of-one: schedule only the next occurrence (id 1001). After delivery/acknowledge/snooze, compute and schedule the following occurrence.
- Exact alarms need `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM`; reschedule after reboot via `RECEIVE_BOOT_COMPLETED` + boot receiver.
- Actions: Done → completed; Snooze → +10 min → due again (fixed for Phase 1).

## 3. Dependencies (pubspec additions)
- sqflite ^2.x, path ^1.x
- flutter_local_notifications ^17.2.0
- timezone ^0.9.2
- provider ^6.1.1
- intl ^0.19.0

(No permission_handler needed — flutter_local_notifications handles the notification permission request.)

## 4. patch_android.py changes
Extend the Phase 0 stub to:
1. Permissions: POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, VIBRATE.
2. flutter_local_notifications receivers inside `<application>`: ScheduledNotificationReceiver + ScheduledNotificationBootReceiver (BOOT_COMPLETED intent filter). Verify exact class names against installed v17.
3. Core desugaring (`desugar_jdk_libs:2.1.4`) appended to build.gradle(.kts).

Pattern: append-only, no fragile regex — mirror `hydration_reminder/patch_android.py`.

## 5. Task list (one file per task; executor parallelizes by batch)

Batch 0 (independent):
1. pubspec.yaml — add dependencies.
2. lib/core/models/reminder.dart — Reminder + ReminderStatus.
3. lib/core/db/database_helper.dart — sqflite open + schema.

Batch 1 (after 2, 3):
4. lib/core/recurrence.dart — next occurrence for once/daily/weekly/custom.
5. lib/core/repositories/reminder_repository.dart — CRUD + lifecycle transitions.

Batch 2 (after 4, 5):
6. lib/services/notification_service.dart — init, permission, zonedSchedule, actions, boot reschedule.
7. lib/core/providers/reminder_provider.dart — state + scheduling wiring.

Batch 3 (after 7):
8. lib/ui/screens/home_screen.dart — upcoming reminders list.
9. lib/ui/screens/create_reminder_screen.dart — form.
10. lib/main.dart — wire db + notifications + timezone + provider.

Batch 4 (after 4, 5; independent of UI):
11. patch_android.py — Phase 1 patches.
12. test/unit/recurrence_test.dart
13. test/unit/lifecycle_test.dart
14. test/unit/reminder_model_test.dart

## 6. Tests
- recurrence: next occurrence for daily/weekly/custom incl. week boundary and once.
- lifecycle: valid transitions accepted; invalid transitions rejected.
- model: title required; hour 0–23; minute 0–59.
- Plain given→expect list for recurrence/lifecycle (ROADMAP §15 rules-engine convention).

## 7. Verification (CI)
`.github/workflows/build-apk.yml` (exists): `flutter create .` → `patch_android.py` → `pub get` → `analyze` → `build apk --debug`. A green run proves compile + static-analyze. Manual exit criteria (ROADMAP §4) verified by owner on device.

## 8. Exit-criteria mapping (ROADMAP §4)
| Criterion | Proof |
|---|---|
| Create "8 PM daily medication" | create_reminder_screen → repository write |
| Notification fires at 8 PM | notification_service zonedSchedule + exact alarm |
| Done / snooze | notification quick actions → lifecycle transition |
| Persists across restart | sqflite on-device DB |
| Works on Android | CI apk build + on-device manual check |

## 9. Open questions for owner
1. Directory layout: standard `lib/` at root (recommended; matches shipped Phase 0 + CI) vs ROADMAP's nested `app/lib/`.
2. Snooze duration: fixed +10 min for Phase 1 (recommended) vs configurable now.
3. Category set: fixed list from PRODUCT 3.1 — medication, errand, study, appointment, payment, other (confirm).
