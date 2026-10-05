# ROADMAP.md

Project: Nudge — a contextual reminder system
Version: 0.3 — Foundation
Status: Draft for review
Last updated: October 6, 2026

---

## 1. How to Read This Document

This is the phased build plan. It is written for an AI coding agent (OpenCode, Freebuff, or similar) working with a non-coding product owner.

Three rules for the AI coding agent:

1. **Never skip a phase.** Each phase produces a working, testable app. Do not start Phase N+1 until Phase N's exit criteria are met.
2. **Never add features from a later phase.** If something belongs in Phase 4, do not build it during Phase 2 — even if it seems easy.
3. **Always preserve the constitution.** The documents in /docs (PRODUCT.md, ARCHITECTURE.md, UX.md) are binding. If a build decision conflicts with them, the documents win.

Each phase has:

- **Goal** — what this phase proves.
- **Deliverables** — what exists at the end.
- **Exit criteria** — how we know it's done.
- **Explicitly not in this phase** — guardrails against scope creep.
- **AI agent instructions** — what to tell the coding tool.

### 1.1 Platform Sequencing (locked decision, added v0.2)

- **Framework: Flutter.** Locked. One codebase, native plugin support for calendar, location, and notifications, consistent UI.
- **Android-first.** Android is the only build target through Phase 8. The iOS adapter is brought online as a dedicated effort after the core loop is validated on Android.
- Wherever an exit criterion below says "both Android and iOS" or "both platforms," read it as **"Android"** until the iOS ramp. The iOS adapter phases are defined in Section 14a and come online after Phase 6's exit criteria are met on Android.

---

## 2. Phase Overview

```
Phase 0 — Project Foundation
    │
Phase 1 — Basic Reminder App
    │
Phase 2 — Natural Language Capture  ← the "wow" moment
    │
Phase 3 — Time Intelligence & Silent Hours
    │
Phase 4 — Calendar & Meeting Awareness
    │
Phase 5 — Location Awareness
    │
Phase 6 — Delivery Orchestration
    │
Phase 7 — Behavior Learning
    │
Phase 8 — Proactive Intelligence
    │
Phase 9 — Insights & Polish
    │
Phase 10 — Release Preparation
```

Phases 0–5 produce the "lighter version that feels smart."
Phases 6–8 produce the full differentiator.
Phases 9–10 prepare for public release.

---

## 3. Phase 0 — Project Foundation

Goal: Set up the project so that every subsequent phase builds on a stable, well-documented base.

Deliverables:

- A Flutter mobile project (framework is **locked** — see Section 1.1).
- Repository structure with /docs, /app, /tests.
- The four constitution documents committed: PRODUCT.md, ARCHITECTURE.md, UX.md, ROADMAP.md.
- AGENTS.md — the persistent instruction file for OpenCode.
- A minimal app that launches on Android and shows a blank home screen.

Technology decision: **Flutter (locked).**

Repository structure:

```
reminder-app/
│
├── AGENTS.md
├── README.md
│
├── docs/
│   ├── PRODUCT.md
│   ├── ARCHITECTURE.md
│   ├── UX.md
│   └── ROADMAP.md
│
├── app/
│   ├── lib/
│   │   ├── core/          (shared logic: models, rules, event bus)
│   │   ├── components/    (capture, understanding, orchestrator, etc.)
│   │   ├── adapters/      (android/, ios/)
│   │   └── ui/            (screens, widgets)
│   ├── android/
│   └── ios/
│
└── tests/
    ├── unit/
    └── integration/
```

Exit criteria:

- App launches on Android.
- Blank home screen is visible.
- All docs are committed.
- AGENTS.md is in the repo root.

Explicitly not in this phase:

- No reminders.
- No database.
- No notifications.
- No natural language.

AI agent instructions:

Read all files in /docs before starting. Then create the project structure described in ROADMAP.md Phase 0. Use Flutter. Do not implement any reminder functionality yet. The deliverable is a launching app shell and a documented repository.

---

## 4. Phase 1 — Basic Reminder App

Goal: Build a working reminder app that is no smarter than a normal reminder app. This proves the foundation is solid before we add intelligence.

Deliverables:

- Local database (SQLite via sqflite in Flutter).
- Reminder data model matching PRODUCT.md section 3.1 (basic fields only: title, time, recurrence, category).
- Create reminder screen with a simple form (no natural language yet).
- Recurring reminders (daily, weekly, custom).
- Local notifications that fire at the set time.
- Notification actions: done, snooze.
- Home screen showing upcoming reminders.
- Reminder lifecycle: pending → due → delivered → acknowledged → completed.

Exit criteria:

- User can create a reminder like "Take medication at 8 PM every day."
- Notification fires at 8 PM.
- User can mark it done or snooze it.
- Data persists across app restarts.
- Works on Android.

Explicitly not in this phase:

- No natural language input.
- No context awareness.
- No learning.
- No location.
- No calendar.
- No voice.
- No suggestions.

AI agent instructions:

Implement Phase 1 as a plain reminder app. Do not add any intelligence. The point is to have a solid, boring foundation. All reminder data must persist locally.

---

## 5. Phase 2 — Natural Language Capture

Goal: Let the user type or speak a reminder in plain language, and have the app understand it. This is the first "wow" moment.

Deliverables:

- Capture screen with a large text field: "What do you want to remember?"
- Voice input button (uses platform speech-to-text).
- Understanding layer that parses raw text into a structured reminder draft.
- Confidence scores per field.
- Draft confirmation screen showing what the app understood, with every field editable.
- Fallback to Phase 1's form if parsing fails.
- Category auto-detection (medication, errand, study, appointment, payment, etc.).
- Default urgency and importance per category.

Example:

Input: "Remind me to take my thyroid pill every morning and night."

Output draft:

```
💊 Thyroid medication
Every day
🌅 8:00 AM
🌙 8:00 PM
Importance: ●●●●○
Urgency: ●●●●●
```

LLM usage (per ARCHITECTURE.md v0.2 AI policy — rules-first):

- Primary parsing is a deterministic rule-based parser (covers common patterns like "every day at [time] remind me to [task]").
- The LLM is invoked only as an enhancement when the rule parser's confidence is low on a field that matters.
- This is the only place an LLM is used in this phase.

Exit criteria:

- User types "remind me to call John tomorrow at 3" → structured reminder created.
- User types "remind me to pay electricity bill on the 10th every month" → recurring reminder created.
- User types "remind me to drink water every hour" → recurring reminder created.
- Confidence scores are visible when the app is unsure.
- The user can edit any field before saving.
- Voice input works on Android.

Explicitly not in this phase:

- No location parsing (that's Phase 5).
- No calendar integration (Phase 4).
- No adaptive delivery (Phase 6).
- No suggestions (Phase 8).

AI agent instructions:

Implement Phase 2 natural language capture. Primary path is the deterministic rule-based parser; use an LLM only for low-confidence enhancement. Build the confirmation screen exactly as described in UX.md section 2.1. Do not add location or calendar parsing yet.

---

## 6. Phase 3 — Time Intelligence & Silent Hours

Goal: Make time smarter. Handle silent hours, quiet modes, and the warning system.

Deliverables:

- Silent hours setting (default 10 PM–7 AM, adjustable).
- Silent-hour conflict detection at creation time.
- Warning UI: "This falls in your silent hours. You won't be reminded then."
- Options: change time, change silent hours, or save anyway.
- If saved anyway: silent notification at set time + normal notification after silent hours end (if not completed).
- Quiet mode toggle (temporarily pause non-critical reminders).
- Per-reminder flexibility setting: exact vs. adaptive.
- Basic urgency escalation: payments get more urgent as deadline nears.

Exit criteria:

- User creates a reminder at 11 PM with silent hours 10 PM–7 AM.
- App warns and offers options.
- If user saves anyway, notification fires silently at 11 PM and normally at 7 AM.
- Urgency changes over time for deadline-driven reminders (visible in reminder detail).
- Quiet mode suppresses non-critical reminders.

Explicitly not in this phase:

- No calendar.
- No location.
- No learning.

AI agent instructions:

Implement Phase 3. Silent hours are core to the product's calm personality. The warning must be shown at creation time, before saving. Escalation logic belongs in the Reminder Intelligence Core, not in the notification layer.

---

## 7. Phase 4 — Calendar & Meeting Awareness

Goal: Know when the user is in a meeting and behave accordingly.

Deliverables:

- Calendar permission request with explanation (per UX.md section 7).
- Calendar reading: active events, upcoming events, busy/free status.
- Context snapshot includes inMeeting: true/false.
- Delivery orchestrator uses meeting context:
  - If in meeting and reminder is not critical: quiet notification (1–2 vibrations, no sound).
  - If not acknowledged by meeting end: normal delivery after meeting.
- Notification action: "Remind after meeting."
- Two-stage reminder plan support (foundation for Phase 5).

Exit criteria:

- User has calendar event 3–4 PM.
- Reminder fires at 3:30 PM.
- App detects meeting, delivers quietly.
- If not acknowledged, reminder re-fires normally at 4 PM (with buffer).
- User can tap "Remind after meeting" to defer explicitly.

Explicitly not in this phase:

- No location.
- No foreground-app detection (Android-only, later).
- No learning.

AI agent instructions:

Implement Phase 4. Use CalendarContract on Android (and EventKit on iOS when the iOS adapter comes online). Handle permission denial gracefully — the app must work without calendar access, just without meeting awareness. The two-stage reminder mechanism should be built here as a reusable plan structure, even if only used for meetings.

---

## 8. Phase 5 — Location Awareness

Goal: Reminders that fire based on where the user is, not just when.

Deliverables:

- Location permission request with explanation.
- Geofencing for home, work, and custom places.
- Place naming: user-defined (Home, Work, Gym, Pharmacy) or learned (with confirmation).
- Location-triggered reminders: "Remind me when I'm near [place]."
- Journey-based reminders: "Remind me on my way home from work."
- Route detection: leaving work, approaching shop, arriving home.
- Voice delivery for driving context.

Exit criteria:

- User creates "remind me to buy milk on the way home from work."
- App adds two reminder stages: leave work, near shop.
- Confirmation shown: "I'll remind you when you leave work, then again when you're near the shop."
- Notification fires on leaving work.
- Voice reminder fires when near the shop.
- Location permission denial works gracefully (fallback to time-based reminder).

Platform notes:

- Android: Geofencing API, activity recognition for driving detection.
- iOS (later): Core Location region monitoring, limited background execution. Driving detection may be less precise.
- If driving detection is unavailable, default to notification with voice option.

Explicitly not in this phase:

- No usage stats / foreground-app detection.
- No complex route learning.
- No doomscroll rescue.

AI agent instructions:

Implement Phase 5. Location is essential to the product's differentiation. Test with real geofences, not simulated ones. The two-stage reminder from Phase 4 must extend naturally here. Voice delivery should use the platform TTS in a calm, neutral tone.

---

## 9. Phase 6 — Delivery Orchestration

Goal: Make delivery decisions smart. Combine reminders, escalate appropriately, and use the intervention budget.

Deliverables:

- Delivery Orchestrator as a standalone component that:
  - Combines multiple low-priority reminders into one notification.
  - Escalates urgency based on deadline and follow-through rules.
  - Uses the intervention budget to avoid over-notifying.
  - Chooses the right channel (silent, gentle, normal, voice) based on context.
- Multi-stage reminder plans fully supported (milk: leave work → near shop).
- Delivery plan is transparent: "Why now?" available on every notification.
- Escalation rules per reminder category:
  - Medication: escalate after 15 min if not acknowledged.
  - Water: gentle, no escalation.
  - Study: one gentle nudge, then wait.
  - Payments: escalate as deadline approaches.

Exit criteria:

- Three low-priority reminders due at 8 PM produce one combined notification.
- Reminder ignored past escalation threshold fires again, stronger.
- "Why now?" shows the reasoning.
- Voice delivery is used when driving context is detected.
- Combined notifications are clear and actionable.

Explicitly not in this phase:

- No learning (Phase 7).
- No proactive suggestions (Phase 8).

AI agent instructions:

Implement Phase 6. The orchestrator must be a separate module, not entangled with the notification layer. Delivery decisions should be testable in isolation (unit tests with mock context snapshots). The intervention budget is a soft limit, not a hard rule — use it to avoid over-notifying, not to suppress critical reminders.

---

## 10. Phase 7 — Behavior Learning

Goal: The app observes how the user responds to reminders and suggests improvements. All learned behavior is user-approved.

Deliverables:

- Response tracking: acknowledged, snoozed, ignored, completed, missed.
- Pattern detection:
  - Best time for this reminder type.
  - Best location (for location-triggered reminders).
  - Most effective delivery channel.
  - Snooze patterns.
- Suggestion generation:
  - "You usually study AWS when you're home. Would you like me to wait until you're home?"
  - "You usually work out around 8:30 PM. Would you like me to move the reminder?"
- Suggestion rate limiting: one suggestion per reminder type per day.
- Learned behaviors view in settings, with undo.
- Observation → Pattern → Suggestion → Approval → Learned Behavior.

Exit criteria:

- After 5 occurrences of ignoring the 8 PM study reminder but studying later at home, the app suggests waiting until home.
- User can accept or decline.
- If accepted, behavior changes. If declined, no repeat in the same week.
- Learned behaviors visible in settings with undo.
- Never silently changes behavior.

Explicitly not in this phase:

- No proactive suggestions (Phase 8).
- No doomscroll rescue.

AI agent instructions:

Implement Phase 7. Learning must never change behavior without user approval. Suggestion wording must be specific, not descriptive (see PRODUCT.md principle 2.17). Pattern detection can use simple statistics — no need for ML.

---

## 11. Phase 8 — Proactive Intelligence

Goal: The app suggests reminders the user didn't ask for, based on calendar, patterns, and context.

Deliverables:

- Calendar-triggered suggestions: dentist appointment → suggest preparation reminder.
- Pattern-triggered suggestions: same one-off task repeated three times → suggest recurring.
- Follow-through-triggered suggestions: after completing something recurring, suggest locking in a standing version.
- Suggestion notifications with Yes/No and a text box.
- Natural language response handling: "yes, at 6pm," "when I'm home," "between 5 and 7."
- Rate limiting and no-nagging rules.
- If user says no, remember and don't re-suggest.

Exit criteria:

- User has "Dentist tomorrow 4 PM" on calendar.
- App suggests: "Would you like a reminder to prepare? At 6 PM / When you're home / Choose a time."
- User responds "yes, when I'm home." Reminder created.
- If user says no, suggestion does not repeat.
- Pattern-based suggestions work for recurring tasks.

Explicitly not in this phase:

- No doomscroll rescue (this is a later "moonshot" feature).
- No Meta Glasses / wearable integration.

AI agent instructions:

Implement Phase 8. Every suggestion is a notification, never an auto-created reminder. Rate-limit to avoid nagging. The text box in suggestion notifications is important — it lets the user respond naturally, consistent with the app's natural language design.

---

## 12. Phase 9 — Insights & Polish

Goal: Give the user a clear view of what they accomplished and what they missed, without guilt. Polish the experience.

Deliverables:

- Insights dashboard:
  - Completed today (count and list).
  - Completed this week.
  - Missed items (neutral language, no red).
  - Trends over time (optional).
- No streaks, no scores, no gamification.
- Home screen refinement.
- Widget for quick capture (home screen and lock screen).
- Share sheet integration (share a link → create reminder).
- Performance optimization.
- Accessibility audit (screen reader, dynamic type, contrast).

Exit criteria:

- User can see their accomplishments without anxiety.
- Missed items are shown neutrally, with options to reschedule or dismiss.
- Widget works on Android.
- TalkBack navigation works.
- No red badges, no "failed" language.

AI agent instructions:

Implement Phase 9. Insights must be calm and non-judgmental. No streaks, no scores, no red. The widget should make capture near-instant. Test on small screens and with accessibility features enabled.

---

## 13. Phase 10 — Release Preparation

Goal: Prepare for public release.

Deliverables:

- Onboarding flow that explains the app's philosophy and requests permissions progressively.
- Privacy policy and terms of service.
- Google Play listing (screenshots, descriptions). App Store listing later with iOS.
- Backend setup (if needed):
  - Cloudflare Pages (web dashboard, optional)
  - Neon (PostgreSQL for cloud sync)
  - Clerk (authentication)
  - Resend (transactional emails)
  - Cloudflare R2 (file storage)
- Analytics: privacy-respecting (no personal data, no third-party trackers).
- Crash reporting.
- Beta testing with a small group.
- Submit to Google Play.

Exit criteria:

- App passes Google Play review.
- Onboarding is clear and calm.
- Privacy policy is live.
- Beta feedback is addressed.

AI agent instructions:

Implement Phase 10. The app is local-first; cloud is optional. Privacy is a foundation, not a feature. Do not add third-party analytics that track user behavior. Use the free stack noted in PRODUCT.md for any cloud services.

---

## 14. What's Explicitly Later (Post-Release)

These are not in any phase above. They are documented here so the AI agent knows not to build them prematurely.

- **Wear OS / Apple Watch.** Smartwatch support is a someday idea. The architecture (delivery orchestrator with "surface" as a parameter) already supports it, but no watch app until the phone experience is validated.
- **Foreground-app detection (Android-only).** Detecting Zoom/Meet open on screen. Permission-heavy, platform-specific, not essential for v1.
- **Doomscroll rescue.** Resurfacing skipped goals during low-value phone time. MVP approach (resurface on next unlock) may be added post-release.
- **Meta Glasses / ambient devices.** Long-term vision. Not in scope.
- **Goal decomposition.** Breaking "Interview Friday" into sub-tasks. Later-stage differentiator.
- **Advanced route learning.** Predicting user's route, suggesting errands along the way. Later-stage.

### 14a. iOS Ramp (added v0.2)

After Phase 6's exit criteria are met on Android and the core loop is validated, bring the iOS adapter online as a dedicated effort before Phase 9:

- **iOS Core.** Build out the iOS platform adapter: local notifications (UNUserNotificationCenter), EventKit calendar, Core Location region monitoring.
- **Known iOS gaps.** No screen-state access, no per-app usage, no exact-alarm permission equivalent. The product degrades gracefully: meeting awareness is calendar-only, and escalation relies on notification engagement signals.
- **iOS testing.** Re-run the golden scenarios (Section 15) on iOS and confirm behavior matches locked rules, adjusting only for platform signal availability.

---

## 15. Testing Strategy

Because the product owner does not code, the AI agent must be responsible for testing.

Unit tests:

- Reminder model validation.
- Orchestrator decisions given mock context snapshots.
- Silent-hour logic.
- Escalation rules.
- Learning pattern detection.
- **Rules-engine test file (added v0.2).** Maintain a plain-text list of `given X → expect Y` cases for the Orchestrator and the rule-based parser. Convert these into automated tests. This is the executable form of PRODUCT.md section 4's locked behaviors.

Integration tests:

- Create → notify → respond → lifecycle transitions.
- Multi-stage reminders.
- Location-triggered reminders (simulated geofences in test environment).

Manual testing checklist per phase:

- Create each scenario from PRODUCT.md section 4.
- Verify behavior matches locked rules.
- Test on Android.
- Test with permissions denied.
- Test with silent hours active.

Golden scenarios (minimum set for regression testing):

1. Exact medication reminder with meeting context.
2. Milk on the way home.
3. Prescription pickup near pharmacy.
4. Return to store with deadline.
5. AWS study with home-based learning.

---

## 16. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| AI coding agent builds features out of order | Phase guardrails + AGENTS.md |
| Platform differences cause behavior drift | Shared core logic, platform adapters for signals only |
| LLM parsing is inaccurate | Rules-first primary parser + confidence scores + editable draft + offline fallback |
| Location battery drain | Use geofences, not continuous tracking |
| Notification overload | Intervention budget + combining |
| User feels surveilled | All learned behavior is confirmed, never silent |
| Scope creep (100% AI, no human coder) | Follow ROADMAP phases strictly; don't skip |

---

## 17. AGENTS.md Template

This file goes in the repo root and is read by the AI coding agent before every session.

```markdown
# AGENTS.md — Persistent Instructions for the AI Coding Agent

## Project
Contextual Reminder System. A calm, intelligent reminder app that understands when
a task can actually be done, not just when the clock says so.

## Constitution (binding)
Read these before making any decision:
- /docs/PRODUCT.md
- /docs/ARCHITECTURE.md
- /docs/UX.md
- /docs/ROADMAP.md

If a build decision conflicts with these documents, the documents win.

## Rules
1. Never skip a ROADMAP phase. Each phase has exit criteria; meet them before moving on.
2. Never add features from a later phase.
3. Calm is the default personality. No exclamation marks, no guilt, no streaks.
4. User intent comes first. Do not redefine what the user asked for.
5. All learned behavior is user-approved. Never silently change behavior.
6. Local-first. The app works offline.
7. Test on Android for every phase (iOS ramp after Phase 6).
8. When in doubt, ask the product owner. Do not guess on product decisions.

## Current Phase
[Update this line each time a phase begins or ends.]
```

---

## 18. Change Log

| Date | Version | Change |
|---|---|---|
| Oct 6, 2026 | 0.1 | Initial roadmap: 10 phases, testing strategy, risks, AGENTS.md template. |
| Oct 6, 2026 | 0.2 | Locked platform decisions: Flutter (not React Native); Android-first through Phase 8; iOS ramp added as Section 14a; AI policy aligned to rules-first (ARCHITECTURE.md v0.2); rules-engine test file added to Section 15. |
| Oct 6, 2026 | 0.3 | App name locked: **Nudge** (applicationId `com.nudge.app.nudge`). Phase 0 CI: `flutter create --org com.nudge.app --project-name nudge`. |

---

*End of ROADMAP.md v0.2*
