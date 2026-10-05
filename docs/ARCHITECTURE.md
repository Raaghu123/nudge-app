# ARCHITECTURE.md

Project: Contextual Reminder System
Version: 0.2 — Foundation
Status: Draft for review
Last updated: October 6, 2026

---

## 1. Overview

The system is a context-aware reminder engine. It is not a monolithic app; it is a set of seven loosely coupled components that communicate through a central event bus. This separation is deliberate: it lets us evolve the intelligence without rewriting delivery logic, and it lets the same core run on Android, iOS, and later watchOS / Wear OS / glasses.

The architecture is offline-first. All core functionality — creating reminders, making delivery decisions, learning from responses — works without a network. Cloud services are optional and additive.

---

## 2. Component Map

```
                        ┌─────────────────────┐
                        │   CAPTURE LAYER      │
                        │ (NL, voice, form)    │
                        └──────────┬──────────┘
                                   │ raw intent
                                   ▼
                        ┌─────────────────────┐
                        │  UNDERSTANDING       │
                        │  (parser + LLM)      │
                        └──────────┬──────────┘
                                   │ structured reminder draft
                                   ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│  CONTEXT ENGINE      │   │ REMINDER INTELLIGENCE│   │ BEHAVIOR LEARNING   │
│  (calendar, location,│   │ CORE                 │   │ (patterns, history) │
│   device, activity)  │   │ (data model, rules)  │   │                     │
└──────────┬──────────┘   └──────────┬──────────┘   └──────────┬──────────┘
           │                         │                         │
           │ context snapshot        │ reminder + state        │ learned behaviors
           └────────────┬────────────┴────────────┬────────────┘
                        ▼                         ▼
               ┌─────────────────────┐   ┌─────────────────────┐
               │  DELIVERY            │   │  PROACTIVE           │
               │  ORCHESTRATOR        │◄──│  INTELLIGENCE        │
               │ (when/how to deliver)│   │ (suggestions)        │
               └──────────┬──────────┘   └─────────────────────┘
                          │
                          ▼
               ┌─────────────────────┐
               │  PLATFORM ADAPTERS   │
               │ (Android, iOS, ...)  │
               └──────────┬──────────┘
                          │
                          ▼
               ┌─────────────────────┐
               │  USER               │
               └─────────────────────┘
```

Each box is a distinct module with a clear contract. No component reaches into another's internal state; they communicate through events and well-defined interfaces.

---

## 3. Component Details

### 3.1 Capture Layer

**Responsibility:** Accept user input in any form and produce a raw intent object.

**Does not:** Interpret, schedule, or deliver.

Inputs:

- Typed natural language
- Voice (speech-to-text first, then same as typed)
- One-tap category templates (Water, Meds, Bill, etc.)
- Structured form (fallback / editing)
- Home-screen widget (quick capture)
- Share sheet (from other apps, e.g., share a link to remind later)

**Output:** RawIntent — a plain object containing the original text or voice transcript, plus any metadata (timestamp, source, attached files).

### 3.2 Understanding Layer

**Responsibility:** Turn RawIntent into a structured ReminderDraft with confidence scores.

**Uses:** A deterministic rule-based parser as the primary path; an LLM (cloud or on-device) as an enhancement for ambiguous or low-confidence input. See Section 7.

**Does not:** Decide delivery or scheduling.

Process:

1. Parse text for: task, time expressions, recurrence, location, people, deadlines, category.
2. Assign confidence to each extracted field.
3. If confidence is low on a field that matters (e.g., time for a medication), generate a clarifying question.
4. Return ReminderDraft.

Special case — silent-hour warning:

If the parsed time falls inside the user's silent hours, the layer must return a flag `silentHourConflict: true` and a suggested message. The Capture UI shows this before saving.

**Output:** ReminderDraft — a structured object with fields matching the Reminder Intelligence Model, each with a confidence score, plus optional clarifying questions.

### 3.3 Reminder Intelligence Core

**Responsibility:** The single source of truth for every reminder. Stores the full model, manages lifecycle state, and enforces core rules (e.g., urgency climbs as deadline nears).

**Does not:** Know about notifications, context signals, or user behavior.

Data model: Matches PRODUCT.md section 3.

Lifecycle states: `pending → due → delivered → acknowledged → completed` or `delivered → ignored → deferred → completed` or `delivered → skipped → next_occurrence`.

Rules enforced here:

- User-locked time cannot be changed.
- Deadline escalation: urgency increases automatically as deadline approaches.
- Recurrence expansion: generates the next occurrence.
- Multi-stage intervention plans are stored as part of the reminder (e.g., milk: stage 1 leave work, stage 2 near shop).

**Output:** Reminder object, lifecycle events (ReminderDue, ReminderCompleted, etc.).

### 3.4 Context Engine

**Responsibility:** Maintain a real-time snapshot of what's true right now.

**Does not:** Know about reminders.

Signals (platform-dependent):

- Time — current time, day of week, quiet hours.
- Calendar — active events, upcoming events, busy/free status.
- Location — geofences (home, work, custom places), route progress, near a specific place.
- Device state — screen on/off, locked/unlocked, Do Not Disturb, driving mode.
- Activity — driving, walking, stationary, in a call (where available).
- User state — recently interacted with phone, last unlock time.

Platform adapters:

- Android: Geofencing API, UsageStats (optional, permission-gated), ACTION_SCREEN_ON/OFF broadcasts via foreground service, CalendarContract.
- iOS: Core Location region monitoring, EventKit, limited background execution. No screen-state access. No per-app usage.

**Output:** ContextSnapshot — a plain object with available signals and a timestamp.

### 3.5 Delivery Orchestrator

**Responsibility:** The decision-maker. Given a reminder, a context snapshot, learned behaviors, and the intervention budget, decide:

- Should we deliver now?
- Which channel? (sound, vibration, voice, visual)
- Which surface? (phone, watch later)
- If not now, when to re-evaluate?
- If multiple reminders are due, combine or sequence?

**Does not:** Store reminder data or learn by itself.

Decision inputs:

- Reminder (with urgency, importance, flexibility, deadline)
- ContextSnapshot
- LearnedBehavior for this reminder type / user
- Current intervention budget usage

**Decision outputs:** DeliveryPlan — a list of planned interventions with timing, channel, content, and fallback conditions.

Key logic:

- Silent hours: if current time is in silent hours and reminder is not critical, defer. If the reminder was set for a silent hour, deliver silently at the set time and again after silent hours end (unless completed).
- Meeting context: if calendar shows busy, use gentle delivery (vibration + notification, no sound).
- Driving context: if driving, use voice-first delivery.
- Combining: if multiple low-urgency reminders are due, combine into one notification.
- Escalation: if a reminder is ignored, increase urgency according to its follow-through rules.

**Output:** DeliveryPlan sent to Platform Adapters.

### 3.6 Behavior Learning Layer

**Responsibility:** Observe how the user responds to reminders, find patterns, and generate suggestions.

**Does not:** Change behavior silently. All learned behavior is user-approved.

Inputs: Delivery events, user responses (acknowledged, snoozed, ignored, completed), context snapshots at delivery time.

Outputs:

- LearnedBehavior records (e.g., "For AWS study, user usually completes when home").
- Suggestion objects (e.g., "Wait until home for AWS study?").

Rules:

- Observation → Pattern → Suggestion → User approval → Learned behavior.
- Suggestion wording must be specific, not descriptive.
- Rate-limit suggestions (no more than one per day per reminder type, configurable).

### 3.7 Proactive Intelligence Engine

**Responsibility:** Generate suggestions not directly requested by the user, based on calendar, patterns, and follow-through.

**Does not:** Auto-create reminders. Always suggests.

Triggers:

- Calendar event detected (dentist, flight, interview) → suggest preparation reminder.
- Repeated one-off task → suggest making it recurring.
- Skipped goal + low-value phone time → suggest resurfacing (doomscroll rescue, later stage).
- Follow-through completed → suggest locking in a standing version.

Rules:

- Suggestions are always user-confirmed.
- One suggestion per context, no nagging.
- If ignored, do not repeat in the same session.

---

## 4. Platform Adapters

**Responsibility:** Translate abstract delivery plans into platform-specific actions and collect platform-specific context signals.

Android Adapter:

- Notification channels, exact alarms (SCHEDULE_EXACT_ALARM permission), geofencing, foreground service for screen-state and usage stats, calendar access, TTS.
- Handles Android 12+ exact alarm restrictions and guides user through permission onboarding.

iOS Adapter:

- Local notifications, region monitoring, EventKit, background app refresh (limited), TTS.
- No screen-state, no per-app usage, no exact alarm permission (uses UNUserNotificationCenter with time intervals / calendar triggers).

Common Interface:

- `scheduleDelivery(plan)`
- `cancelDelivery(id)`
- `getContextSnapshot()`
- `requestPermissions(feature)`

Future surfaces: watchOS, Wear OS, glasses — added as new adapters without changing core.

---

## 5. Data Layer

Local-first: All reminders, learned behaviors, and event history stored locally.

- Android: Room (SQLite) — via sqflite/drift in Flutter.
- iOS: Core Data / SQLite — later phase.

Cloud (optional, later): For multi-device sync, user accounts, and backup.

The free stack noted earlier — Cloudflare Pages, Neon, Clerk, Resend, R2 — can serve as the backend if needed, but the app must work fully offline.

---

## 6. Event Bus

All inter-component communication happens through an internal event bus. Events are simple, typed, and immutable.

Key events:

- RawIntentCreated
- ReminderDraftParsed
- ReminderSaved
- ReminderDue
- ContextUpdated
- DeliveryPlanCreated
- DeliveryAttempted
- UserResponded
- SuggestionGenerated
- LearnedBehaviorApproved

This decouples components and makes it easy to add new ones (e.g., a watch adapter) without touching the rest.

---

## 7. AI Usage Policy

**Locked decision (v0.2): rules-first, LLM as enhancement.**

- **Primary path — deterministic rule-based parser.** Common patterns ("every day at [time] remind me to [task]", "every weekday", "on the 10th of every month") are parsed with hand-written rules. This path is free, instant, offline, private, and fully testable.
- **Enhancement path — LLM.** When the rule parser's confidence is low on a field that matters, an LLM (cloud or on-device) is invoked to re-parse, resolve ambiguity, or generate clarifying questions. The LLM result is a draft only — it goes through the same editable confirmation screen as every other parse.
- **No LLM for real-time delivery decisions.** "Should this buzz right now" must work instantly, offline, and deterministically. Rules + simple statistics (weighted averages, counts) only.
- **No LLM in the notification path.** Delivery, escalation, and follow-through are pure rules.
- **Privacy:** the app works fully without the LLM; where cloud parsing is used, reminder text is sent only for parsing, disclosed in the privacy policy, and never used for training.
- **Suggestion wording** may be LLM-generated or template-based; it must always obey PRODUCT.md 2.17 (specific, not descriptive).

---

## 8. Silent-Hour Implementation Detail

When a reminder is created with a time inside silent hours:

1. Understanding Layer sets `silentHourConflict: true`.
2. Capture UI shows: "This reminder falls in your silent hours (10 PM–7 AM). You won't be reminded then. Would you like to change the time or adjust silent hours?"
3. User can:
   - Change reminder time
   - Change silent hours
   - Ignore (reminder saved as-is)
4. If ignored, Orchestrator schedules:
   - A silent delivery at the set time (no sound, notification only)
   - A normal delivery after silent hours end, if not completed.

---

## 9. Deployment (later)

When ready to release:

- Frontend (if web dashboard needed): Cloudflare Pages
- Database (cloud sync): Neon (PostgreSQL)
- Auth: Clerk
- Email: Resend
- File Storage: Cloudflare R2

But these are optional; the mobile app is primary.

---

## 10. Open Architecture Questions

1. On-device LLM vs cloud API: cost, latency, privacy trade-offs.
2. Background execution limits: Android foreground service vs WorkManager; iOS background refresh limits.
3. Geofence accuracy: how many geofences can we monitor reliably?
4. Data sync conflict resolution: if we add cloud sync later.
5. Voice TTS: platform TTS vs custom voice. Calm tone is required.
6. Rule parser coverage: which natural-language patterns must the deterministic parser cover before the LLM is even consulted? (Define a pattern table in Phase 2.)

---

## 11. Change Log

| Date | Version | Change |
|---|---|---|
| Oct 6, 2026 | 0.1 | Initial architecture: seven components, platform adapters, event bus, AI policy, silent-hour detail. |
| Oct 6, 2026 | 0.2 | AI Usage Policy rewritten: rules-first primary parser, LLM as enhancement only. Component map updated to reflect parser + LLM. Data layer noted as Flutter (sqflite/drift). Open question 6 added. |

---

*End of ARCHITECTURE.md v0.2*
