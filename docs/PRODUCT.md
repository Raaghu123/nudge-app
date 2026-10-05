# PRODUCT.md

Project: Nudge — a contextual reminder system
Version: 0.4 — Foundation
Status: Draft for review
Last updated: October 6, 2026

---

## 1. Vision

### 1.1 What this app is

A personal context engine that helps people follow through on intentions.

The app is not a reminder app that happens to have intelligence. It is an intelligence layer that understands what the user wants to accomplish, understands what is happening around them, and chooses the least disruptive moment and method to help them act.

**The reminder is only the mechanism. The product is follow-through.**

### 1.2 What this app is not

- Not a to-do list with notifications.
- Not a productivity system that assigns goals, streaks, or scores.
- Not a coach that tells the user what they should be doing.
- Not a surveillance tool that watches the user's behavior without consent.
- Not an AI that redefines the user's intention.

### 1.3 One-sentence positioning

A calm, intelligent reminder system that understands when a task can actually be done — not just when the clock says so.

### 1.4 Long-term direction

The phone is the first sensor and delivery surface, not the product. The intelligence layer is the product. Over time it can extend to watches, glasses, and ambient devices without changing its core model.

---

## 2. Core Principles

These are the laws of the product. Every feature, screen, notification, and algorithm must be consistent with them. When there is a conflict, these principles win.

- **2.1 User intent comes first** — The app assists the user's intention. It does not replace, reinterpret, or override it without consent.
- **2.2 Time is a signal, not always the trigger** — A reminder can wait for a better opportunity. A clock time is one input among many, not the master command — unless the user explicitly locks it.
- **2.3 Context determines opportunity** — Location, calendar, activity, device state, and time can all affect whether a reminder should fire now, later, or quietly.
- **2.4 Importance and urgency are separate** — Something can matter greatly without needing immediate interruption. Something can be urgent without being important. The app treats these as two independent dials, not one "priority" score.
- **2.5 The system can infer, but should not over-assume** — Only infer what available evidence reasonably supports. When confidence is low and the missing information matters, ask.
- **2.6 Suggestions are not actions** — Proactive ideas require user confirmation before becoming persistent reminders or behavior changes. The app proposes; the user decides.
- **2.7 Learning requires transparency** — When the app changes its behavior based on observation, it tells the user why, and asks before making the change permanent.
- **2.8 The user can always override intelligence** — There is always an exact/manual mode. Some users want "figure it out for me." Others want "do exactly what I said." Both are valid.
- **2.9 Never punish the user** — No guilt, no streaks that shame, no "you failed" language, no red overdue badges that induce anxiety. The tone is calm, neutral, and non-judgmental.
- **2.10 The system should explain itself** — The user should be able to understand: Why did you remind me now? Why didn't you remind me earlier? Why did you change my reminder?
- **2.11 Don't pretend to know what you don't know** — This applies especially to future sensors, wearables, cameras, and AI perception. If the app isn't sure, it says so — or stays silent.
- **2.12 The least disruptive effective intervention wins** — If a vibration is sufficient, don't play a sound. If waiting is better, wait. If a voice message is safer than a screen notification, use voice. Escalation happens only when it's needed.
- **2.13 One intention can have multiple intervention points** — A single reminder is not a single notification. It is an intention with opportunities. The app plans those opportunities — leaving work, near the shop, meeting ended — without changing the user's underlying instruction.
- **2.14 Transparent intelligence** — When the app adds intelligent behavior beyond the literal request, it briefly shows the user the plan. Example: "I'll remind you when you leave work, then again when you're near the shop."
- **2.15 Calm is the default personality** — The app's voice, tone, notifications, and confirmations are calm by default. This is not a setting. It is who the app is. We do not label it, market it, or say "calm voice" to the user.
- **2.16 Optimize execution; don't redefine intention** — The app can learn when, where, and how to remind. It does not decide what the user should do, what materials they should study, what workout they should follow, or what goals they should have.
- **2.17 Specific suggestions, not pattern descriptions** — When the app wants to propose a learned behavior, it proposes a concrete next action, not a description of the user's habits. Bad: "You usually go to the mall on Saturdays." Good: "Should I remind you on the next Saturday at 10 AM?"
- **2.18 Attention is a limited resource** — The app has an implicit intervention budget. Not every reminder deserves the same interruption. Several low-priority reminders can be combined into one. High-value reminders earn stronger delivery.
- **2.19 Ask before turning observations into permanent behavior** — Observation → Pattern → Suggestion → User approval → Learned behavior. Never silently convert an observation into a permanent preference.
- **2.20 Quiet hours are respected** — Once quiet hours begin, non-critical reminders are deferred until quiet hours end. The user can set quiet hours; the app should also learn them over time.
- **2.21 Silent-hour warnings are shown at creation time** — If the user sets a reminder to fire during a silent or sleep-hour window, the app must tell them immediately that they won't be reminded at that time, and offer to adjust the silent hours or the reminder time. If the user takes no action, the reminder still fires at the set time (silently) and again when the silent window ends.

---

## 3. Reminder Intelligence Model

Every reminder in the system is represented as an intention with conditions. This is the core data model. Not every field must be filled by the user — most are derived, inferred, or learned.

### 3.1 Core fields

| Field | Meaning | Source |
|---|---|---|
| Intent | What the user actually wants to accomplish | User input, preserved verbatim |
| Task | The actionable thing associated with the intent | Derived from intent |
| Category | Medication, errand, study, appointment, payment, etc. | Inferred or user-selected |
| Time | Scheduled time, preferred window, earliest, relative time | User or inferred |
| Deadline | Latest acceptable time; may be soft or hard | User or inferred |
| Location | Where the task happens, origin, destination, route | User or inferred |
| Context | What's happening around the user (meeting, driving, home) | Context engine |
| Opportunity | Can the user reasonably do this now? | Derived from context + task |
| Urgency | How much timing matters right now | Dynamic |
| Importance | How bad it is if this gets missed entirely | Static or slowly changing |
| Flexibility | How much the system may move this | Inferred or user-set |
| Confidence | How sure the app is about its interpretation | Derived |
| Delivery | How the reminder should reach the user | Orchestrator decision |
| Follow-through | What happens if the user doesn't respond | Rule + learned |
| Attached resources | User-provided links, videos, contacts | User only |
| Dependencies | What must happen before this | Optional |
| Completion | How the app knows it's done | User confirmation or inference |
| Learned behavior | User-approved adaptations | Learning layer |

### 3.2 Time concepts

The app distinguishes between several temporal ideas that traditional reminder apps collapse into one:

- **Exact time** — 8:00 PM (locked if the user says "exactly")
- **Preferred time** — around 8:00 PM
- **Time window** — between 7–10 PM
- **Earliest time** — don't remind before 6 PM
- **Deadline** — must happen before 10 PM
- **Relative time** — after work, before the meeting
- **Event-relative** — 30 minutes before the appointment

### 3.3 Opportunity model

Opportunity is dynamic. It changes as context changes.

Example — Study AWS:

| Context | Opportunity |
|---|---|
| At work | Low |
| Driving | None |
| At home | High |
| At study desk | Very high |
| Home but in a meeting | Low |

Example — Pick up package:

| Context | Opportunity |
|---|---|
| At work | Low |
| Leaving work | High |
| Driving toward shop | Very high |
| Near shop | Very high |
| Already home | Low |

### 3.4 Urgency and importance

Two independent dials, not one score.

**Urgency** — how much timing matters right now. Can change with time.

| Reminder | Urgency |
|---|---|
| Drink water | Low |
| Study AWS | Low |
| Pay electricity bill (20 days out) | Low |
| Pay electricity bill (tomorrow) | High |
| Take medication | High |
| Join meeting | Very high |
| Flight boarding | Extremely high |

**Importance** — how bad it is if this is missed entirely. Generally stable.

| Reminder | Importance |
|---|---|
| Drink water | Medium |
| Take medication | High |
| Study for an exam | High |
| Watch Netflix | Low |

### 3.5 Flexibility

How much the system is allowed to move the reminder.

| Reminder | Flexibility |
|---|---|
| Drink water | High |
| Study | Very high |
| Dentist preparation | Medium |
| Package pickup near closing | Low |
| Medication | Low |
| Meeting | Very low |

### 3.6 Confidence

The app should know how confident it is about its own interpretation. Low confidence + high stakes → ask. Low confidence + low stakes → make a reasonable assumption and let the user correct it.

### 3.7 Learned behavior

A learned behavior has:

- What was observed
- How confident the system is
- What change it wants to make
- Whether the user approved it
- When it was approved
- Whether the user can undo it

---

## 4. Locked Behaviors

These are decisions made during scenario design. They are binding until explicitly revised.

### 4.1 Scenario 1 — Exact medication reminder

User says: "Remind me to take my medicine every day at 8 PM. Exactly 8 PM. Don't change it."

At 8 PM, user is in a meeting:

- The reminder must not be moved. User-locked time is respected.
- Delivery: one short beep, one vibration, notification.
- Notification has two buttons: **Medicine taken** and **Remind me after meeting**.
- If the user taps Medicine taken → completed. No second reminder.
- If the user taps Remind me after meeting → the app waits until the meeting ends, then delivers the reminder with the user's normal selected sound.
- If nothing is pressed → treated as Remind me after meeting.

Rules extracted:

- A user-locked time must not be changed by contextual intelligence.
- Context may change delivery intensity and follow-up behavior, but not the user's explicitly specified time.
- No response to a contextual reminder can result in automatic follow-up when the blocking context ends.
- There is a difference between "ignore" and "temporarily unable to act."

### 4.2 Scenario 2 — Milk on the way home

User says: "Remind me to buy milk on the way home from work."

Behavior:

- The app adds two intervention points:
  1. Notification when the user leaves work (gentle — one vibration, one soft beep). Includes a note: "I'll remind you again when you're near the shop."
  2. Voice message when the user is near the shop: "You're near the shop. Don't forget the milk."
- Confirmation shown to user: "I'll remind you when you leave work, then again when you're near the shop."

Rules extracted:

- One intention can have multiple planned intervention points.
- Departure reminder = awareness. Opportunity reminder = action prompt.
- Voice is audio-first when the user may not be looking at the phone.
- Do not say "calm voice." Calmness is the default.

### 4.3 Scenario 3 — Prescription pickup

User says: "Remind me to pick up my prescription when I'm near the pharmacy."

First time:

- If the user hasn't specified a time or pharmacy, ask.
- Ask which pharmacy (name or location) and whether there's a usual cycle.

Later occurrences:

- The app knows the pharmacy.
- Remind when near the pharmacy and/or when leaving home or work.
- If it's a monthly cycle, increase reminder frequency as the cycle date approaches.

Rules extracted:

- First-time ambiguity → ask.
- Later occurrences → infer and confirm.
- Cyclical errands increase urgency as the cycle date nears.
- Location triggers are opportunity-based, not time-based.

### 4.4 Scenario 4 — Return to store

User says: "Remind me to return this when I'm near the mall. The return deadline is Friday."

Behavior:

- Remind whenever the user is near the mall, even if the deadline is days away.
- Escalate urgency as the deadline approaches.
- On the last day, remind regardless of location — early in the day.
- Ask for the last return date when creating the reminder.
- After the user-set start date, remind daily until the deadline if not completed.

Suggestions must be specific:

- Do not say: "You usually go to the mall on Saturdays."
- Say: "Should I remind you on the next Saturday at [time]?"
- If no, give an option to set a specific date and time.

Delivery:

- Driving → voice.
- Not driving → notification with beep or chosen tune.

### 4.5 Scenario 5 — AWS study

User says: "Remind me to study AWS every day at 8 PM."

Locked rules:

1. When not home at 8 PM: notification + one soft vibration. No loud sound.
2. Learning threshold: 5 occurrences of ignoring the 8 PM reminder but studying later when home.
3. Suggestion wording: "You usually study AWS when you're home. Would you like me to wait until you're home instead of reminding you at 8 PM?"
4. If user says yes: stop the 8 PM reminder entirely. Only remind when the user is home.
5. If the user is home at 8 PM: remind at 8 PM as originally requested.
6. If the user is home but busy: do not remind. Wait until they're free.
7. If the user ignores the reminder while home: let it go until tomorrow.
8. If the user misses it and gets home late: skip the reminder once quiet hours start. (Default quiet hours: 10 PM–7 AM, user-adjustable.)
9. If the user never studies for several days: first suggest a different time. If ignored, then ask if they want to change or pause it.
10. "Every day" but only 3 days a week: learn the actual days and suggest adjusting, but until the user changes anything, keep the daily reminder but be gentle.

---

## 5. Open Questions

These are deliberately unresolved. They will be answered as we design further.

1. Quiet hours default: 10 PM–7 AM? Different for weekdays vs weekends?
2. Back-to-back meetings: does a deferred reminder eventually fire anyway after some ceiling, or defer indefinitely?
3. Calls not on the calendar: foreground-app detection on Android could fill this gap, but it's platform-specific.
4. Doomscroll rescue: MVP approach is to resurface skipped items on next phone unlock, not to interrupt mid-scroll. Final approach TBD.
5. Streaks vs plain data: locked as plain, non-judgmental data. But how exactly do we present accomplishments?
6. Note vs notes app: locked as contextual notes attached to reminders, not a full notes app.
7. Suggestion frequency: how often can the app suggest? Needs a rate limit.
8. Voice personality: locked as calm, neutral, unhurried. Specific voice selection TBD.
9. Wear OS / Apple Watch: later stage. Architecture must not assume phone-only.
10. Permissions onboarding: request when needed, not all at signup. Exact timing TBD.
11. Location learning: ask before saving a learned location, always.
12. Attached resources: user-provided only. The app never suggests study materials, workout videos, or courses.

---

## 6. Glossary

- **Intention** — what the user wants to accomplish, preserved from their own words.
- **Intervention** — a single delivery of a reminder (notification, vibration, voice, etc.).
- **Intervention budget** — the app's implicit limit on how much user attention it spends at once.
- **Opportunity** — how suitable the current moment is for completing the task.
- **Orchestrator** — the decision-maker that chooses when, how, and whether to deliver a reminder.
- **Quiet hours** — user-defined period during which non-critical reminders are deferred.
- **Reminder** — an intention with conditions, tracked through its lifecycle.
- **Suggestion** — a proactive, user-confirmed idea from the app. Never a silent action.
- **Trigger context** — the event that makes a reminder relevant (e.g., leaving work).
- **Opportunity context** — the moment when action is actually possible (e.g., near the shop).
- **Follow-through** — what happens when the user doesn't respond to an intervention.
- **Learned behavior** — a user-approved adaptation the app has made based on observation.

---

## 7. Change Log

| Date | Version | Change |
|---|---|---|
| Oct 5, 2026 | 0.1 | Initial foundation. Core principles, reminder model, 5 locked scenarios, open questions. |
| Oct 6, 2026 | 0.2 | Added Principle 2.21: silent-hour warnings at creation. |
| Oct 6, 2026 | 0.3 | Session decisions locked: Flutter confirmed as framework; Android-first build sequencing (see ROADMAP.md v0.2); rules-first AI policy with LLM as enhancement (see ARCHITECTURE.md v0.2). No principle changes. |
| Oct 6, 2026 | 0.4 | App name locked: **Nudge**. Android applicationId `com.nudge.app.nudge` (changeable before first Play listing). |

---

*End of PRODUCT.md v0.3*
