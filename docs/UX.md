# UX.md

Project: Contextual Reminder System
Version: 0.2 — Foundation
Status: Draft for review
Last updated: October 6, 2026

---

## 1. UX Philosophy

The app should feel like a calm, competent assistant who understands you — not a productivity tool that nags you, not an AI that tries to manage your life.

Three feelings the app should never produce:

- **Anxiety** — no red overdue badges, no "you failed," no streak guilt.
- **Surveillance** — the user should never feel watched. Learned behavior is always explained and confirmed.
- **Helplessness** — the user should always be able to override, edit, or turn off intelligence.

Three feelings the app should always produce:

- **Trust** — the app explains itself when it does something unexpected.
- **Control** — the user can always say "just do exactly what I said."
- **Calm** — the tone, voice, and visual design are unhurried and non-judgmental.

---

## 2. Core User Flows

### 2.1 Capture — the primary flow

The main way users create reminders is by typing or speaking naturally.

Entry points:

- Home screen: large text field at the top — "What do you want to remember?"
- Voice button beside the text field.
- Quick-add widget (home screen or lock screen).
- Share sheet from other apps.
- Category chips (Water, Meds, Bill, etc.) for one-tap templates.

Example flow — thyroid pill:

```
┌─────────────────────────────────────────┐
│                                         │
│  What do you want to remember?          │
│                                         │
│  "Remind me to take my thyroid pill     │
│   every morning and night."             │
│                                         │
│                               🎙️         │
└─────────────────────────────────────────┘
```

After the user submits, the app shows what it understood:

```
┌─────────────────────────────────────────┐
│ 💊 Thyroid medication                   │
│                                         │
│ Every day                                │
│                                         │
│ 🌅 8:00 AM                               │
│ 🌙 8:00 PM                               │
│                                         │
│ Importance        ●●●●○                  │
│ Urgency           ●●●●●                  │
│                                         │
│ 🔔 Normal sound                          │
│                                         │
│ 📝 Add a note                            │
│                                         │
│              Save                        │
└─────────────────────────────────────────┘
```

Key UX rules for this screen:

- Every field is tappable and editable. The user can change anything.
- The "Save" button is primary. No second review screen — save immediately with an undo option.
- If any field has low confidence, it's visually highlighted (soft underline, subtle accent). The user can confirm or correct it.
- "More options" expands to show: sound, vibration, recurrence, grace period, escalation, location, calendar relationship, notes, urgency, importance, notification behavior.
- The default view shows only what matters. Depth is one tap away.

If the parse fails or is ambiguous:

The app shows its best guess, but with fields visibly open for correction. Example:

```
┌─────────────────────────────────────────┐
│ I think you want to:                     │
│                                         │
│ Call John                                │
│                                         │
│ When?                                    │
│ ○ Tomorrow morning                       │
│ ● Tomorrow afternoon                     │
│ ○ Choose a time                          │
│                                         │
│              Save                        │
└─────────────────────────────────────────┘
```

Never guess silently and hope it's right.

### 2.2 Confirmation — showing the plan

When the app adds intelligent behavior beyond the literal request, it must show the plan.

Example — milk on the way home:

User types: "Remind me to buy milk on the way home from work."

App responds:

```
┌─────────────────────────────────────────┐
│ Got it. I'll add two reminders:          │
│                                         │
│ 🔔 When you leave work                   │
│ 🔊 When you're near the shop             │
│                                         │
│ You can change this anytime.             │
│                                         │
│              OK     Change               │
└─────────────────────────────────────────┘
```

Rules:

- This confirmation appears once, inline, and disappears after acknowledgment.
- It doesn't block saving — the reminder is already saved, this is just a notice.
- If the user taps "Change," they go to the reminder detail screen with all fields editable.
- The confirmation uses plain language, not technical terms.

Example — silent hour conflict:

User types: "Remind me to call Mom at 11 PM."

App responds:

```
┌─────────────────────────────────────────┐
│ ⚠️ This falls in your silent hours       │
│    (10 PM – 7 AM).                       │
│                                         │
│ You won't be reminded at 11 PM.          │
│ I'll remind you silently and again       │
│ after 7 AM.                              │
│                                         │
│ Change time    Change silent hours       │
│                                         │
│              Save anyway                 │
└─────────────────────────────────────────┘
```

Rules:

- The warning must appear before saving.
- The user can change the reminder time, change silent hours, or ignore.
- If they ignore, the reminder still saves and fires silently at the set time, then again after silent hours end.

### 2.3 Response — acting on a reminder

Notifications should offer fast, clear actions.

Notification anatomy (example — medication):

```
┌─────────────────────────────────────────┐
│ 💊 Take your thyroid medication          │
│                                         │
│ [ Medicine taken ]  [ After meeting ]    │
└─────────────────────────────────────────┘
```

Rules:

- Two primary actions max on the notification. More options are one tap away.
- Swipe right = done. Swipe left = snooze with a smart default duration.
- Long-press = reschedule, edit, or see "Why now?"
- If the user does nothing and the context that blocked them ends (e.g., meeting over), the reminder fires again with normal delivery.

"Why now?" interaction:

User taps "Why now?" on a notification. App responds:

```
┌─────────────────────────────────────────┐
│ Why now?                                 │
│                                         │
│ You planned this for 8 PM.               │
│ You're free now, and you usually         │
│ study for about 40 minutes around        │
│ this time.                               │
└─────────────────────────────────────────┘
```

This builds trust and makes the intelligence visible without overwhelming the user.

### 2.4 Suggestions — proactive, confirmed

Suggestions are separate from reminders. They appear as notifications with Yes/No and a text box.

Example — dentist preparation:

```
┌─────────────────────────────────────────┐
│ 💡 Suggestion                            │
│                                         │
│ You have a dentist appointment           │
│ tomorrow at 4:00 PM.                     │
│                                         │
│ Would you like a reminder to prepare?    │
│                                         │
│ [ Yes ]       [ No ]                     │
│                                         │
│ Or tell me when:                         │
│ ┌─────────────────────────────────────┐ │
│ │ e.g., "at 6pm" or "when I'm home"   │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

Rules:

- Suggestions are always a notification, never an auto-created reminder.
- The text box lets the user respond naturally: "yes, around 6," "when I'm home," "between 5 and 7."
- If the user ignores or dismisses, the suggestion doesn't repeat in the same session.
- Rate limit: one suggestion per reminder type per day, configurable.
- If the user says no, remember that choice and don't re-suggest the same thing.

Specific suggestions, not pattern descriptions:

- Bad: "You usually go to the mall on Saturdays."
- Good: "Should I remind you on the next Saturday at 10 AM?"

---

## 3. Home Screen

### 3.1 Layout

```
┌─────────────────────────────────────────┐
│  Now                                     │
│                                         │
│  💊 Take medication                      │
│  8:00 PM                                 │
│  In 12 minutes                           │
│                                         │
│  Later                                   │
│                                         │
│  📞 Call John                            │
│  9:00 PM                                 │
│                                         │
│  Suggestions                             │
│                                         │
│  ✈️ Flight tomorrow                      │
│  Leave-home reminder?                    │
│                                         │
│  Completed                               │
│                                         │
│  ✓ 7 things completed today              │
│                                         │
│  [+ Add a reminder]                      │
└─────────────────────────────────────────┘
```

### 3.2 Rules

- Show "right now," not "everything today." A flat list of every reminder is visual noise. Lead with the next one or two things. The full day is a tap away.
- No guilt indicators. No red overdue counts, no "3 missed" badges, no streaks.
- Completed section is quiet. A simple count with a tap-to-expand, not a celebratory animation that pressures the user.
- Suggestions are distinct. Visually different from reminders, clearly labeled as suggestions the user can accept or ignore.
- Add button is always visible. Easy capture in the moment.

### 3.3 Full day view

Tapping "Later" or swiping up reveals the full day:

```
┌─────────────────────────────────────────┐
│  Today                                   │
│                                         │
│  Morning                                 │
│  💊 Medication — 8:00 AM ✓               │
│  🏋️ Workout — 7:00 AM ✓                  │
│                                         │
│  Afternoon                               │
│  📄 Submit report — 2:00 PM              │
│  📞 Call John — 4:00 PM                  │
│                                         │
│  Evening                                 │
│  💊 Medication — 8:00 PM                 │
│  📚 Study AWS — 8:00 PM                  │
│                                         │
│  Tomorrow                                │
│  🦷 Dentist — 4:00 PM                    │
└─────────────────────────────────────────┘
```

Completed items have a subtle check. Missed items are not marked red — they simply roll forward or disappear based on their follow-through rules.

---

## 4. Notification Design

### 4.1 Channels

| Channel | When used |
|---|---|
| Silent notification | Low urgency, quiet hours, meeting context |
| Gentle | One vibration + soft beep |
| Normal | Sound + vibration (user-selected) |
| Voice | Driving, hands-free, audio-first context |
| Combined | Multiple low-priority reminders bundled |

### 4.2 Rules

- One reminder = one notification. Never fire the same reminder twice in quick succession unless escalation rules require it.
- Combining: If multiple low-urgency reminders are due at once, combine them:

```
┌─────────────────────────────────────────┐
│ A few things for this evening            │
│                                         │
│ 💧 Drink water                           │
│ 📞 Call John                             │
│ 📚 Study AWS                             │
└─────────────────────────────────────────┘
```

- Meeting context: notification appears with 1–2 vibrations, no loud sound. If not acknowledged, re-fires after the meeting ends.
- Driving context: voice-first. "You're near the shop. Don't forget the milk." No screen interaction required.
- Quiet hours: silent notification at the set time, then normal delivery after quiet hours end if not completed.

### 4.3 Notification actions

- Swipe right: done.
- Swipe left: snooze with smart default (e.g., 15 min for medication, 1 hour for study).
- Tap: open the reminder detail with "Why now?" available.
- Long-press: reschedule, edit, or mark not applicable.

---

## 5. Voice Design

### 5.1 Personality

- Calm by default. This is not a setting; it's the app's voice.
- Never say "calm voice" to the user. The delivery embodies it.
- Short, unhurried, non-judgmental.
- Never overly enthusiastic. Never robotic if good TTS is available.

### 5.2 When voice is used

- Driving context (audio-first).
- Near-location opportunity (e.g., near shop, near pharmacy).
- When the user's phone is likely not visible.
- When the reminder is location-triggered and time-sensitive.

### 5.3 Examples

- "You're near the shop. Don't forget the milk."
- "You're near the pharmacy. Your prescription is ready for pickup."
- "It's 8 PM. Time to take your medication."

### 5.4 Rules

- Voice messages are short — one sentence.
- No exclamation marks, no urgency language unless the reminder is critical.
- If multiple reminders are due in a voice context, combine: "You're near the shop. Don't forget the milk. You also have a package to pick up nearby."

---

## 6. Settings and Controls

### 6.1 Per-reminder controls

Every reminder has:

- Adaptive or Exact mode toggle.
- Sound selection.
- Silent-hour behavior.
- Escalation preference (gentle, normal, persistent).
- Location triggers (if applicable).

### 6.2 Global controls

- Adaptive reminders on/off. If off, the app behaves like a traditional reminder app.
- Silent hours. Default 10 PM–7 AM, adjustable.
- Quiet mode. Temporarily pause all non-critical reminders.
- Voice on/off. For voice reminders.
- Suggestion frequency. How often the app can suggest (default: low).
- Learned behaviors. View all learned adaptations, with the ability to undo each one.

### 6.3 Learned behaviors view

```
┌─────────────────────────────────────────┐
│ Learned behaviors                        │
│                                         │
│ 📚 AWS study                             │
│ You approved: wait until home            │
│ instead of 8 PM.                         │
│ [ Undo ]                                 │
│                                         │
│ 🛒 Milk on the way home                  │
│ You approved: remind near shop.          │
│ [ Undo ]                                 │
└─────────────────────────────────────────┘
```

This gives the user visibility and control.

---

## 7. Permission Onboarding

### 7.1 Principle

Request permissions when the feature needs them, not all at signup.

### 7.2 Flow

- Calendar access: requested when the user first creates a meeting-aware or preparation reminder.
- Location: requested when the user first creates a location-aware reminder (e.g., "near the shop").
- Notifications: requested when the user saves their first reminder.
- Exact alarms (Android 12+): requested with explanation when the user first sets a time-sensitive reminder.

### 7.3 Explanation style

Every permission request includes:

- What it's for.
- Why it helps.
- What happens if denied.

Example:

```
┌─────────────────────────────────────────┐
│ Calendar access                          │
│                                         │
│ So I can see when you're in meetings     │
│ and stay quiet during them.              │
│                                         │
│ Without this, reminders will fire        │
│ normally even during meetings.           │
│                                         │
│ [ Allow ]       [ Not now ]              │
└─────────────────────────────────────────┘
```

---

## 8. Tone and Copywriting

### 8.1 Voice

- Calm, neutral, non-judgmental.
- Short sentences.
- No exclamation marks.
- No urgency language unless the reminder is critical.
- No "you failed" or "you missed" language.
- No streaks, no celebrations that pressure.

### 8.2 Examples

| Situation | Copy |
|---|---|
| Reminder fires | "Time to take your medication." |
| Reminder deferred | "I'll remind you when you're home." |
| Reminder quiet during meeting | "Quiet because you're in a meeting. I'll remind you when it ends." |
| Suggestion | "You have a dentist appointment tomorrow. Would you like a reminder to prepare?" |
| Learning suggestion | "You usually study AWS when you're home. Would you like me to wait until you're home?" |
| Completed | "Done." |
| Missed | "Not completed today. I'll remind you tomorrow." |
| Silent hour warning | "This falls in your silent hours. You won't be reminded then." |

### 8.3 What to never say

- "Don't forget!"
- "You missed this!"
- "You're falling behind!"
- "Let's crush it!"
- "Great job! 🔥"
- Any language that shames, pressures, or over-celebrates.

---

## 9. Accessibility

- Screen reader support: all interactive elements labeled.
- Dynamic type: layouts adapt to larger text.
- VoiceOver / TalkBack: full navigation.
- Color contrast: WCAG AA minimum.
- Motion: no essential information conveyed only through animation.
- Sound alternatives: vibration-only mode for users who prefer it.

---

## 10. Open UX Questions

1. Undo window: how long after saving can the user undo?
2. Snooze defaults: should they vary by category?
3. Home screen widget: what should it show?
4. Onboarding: how much to explain vs. let the user discover?
5. Voice selection: which TTS voice best matches the calm personality?
6. Combined notification threshold: how many low-priority reminders before combining?

---

## 11. Change Log

| Date | Version | Change |
|---|---|---|
| Oct 6, 2026 | 0.1 | Initial UX document: capture, confirmation, response, suggestions, home screen, notifications, voice, settings, permissions, tone, accessibility. |
| Oct 6, 2026 | 0.2 | Recorded platform sequencing: Android is the primary build target through the core loop (see ROADMAP.md v0.2). iOS-specific signals (screen-state, per-app usage) remain unavailable; flows referencing them apply on Android only for now. |

---

*End of UX.md v0.2*
