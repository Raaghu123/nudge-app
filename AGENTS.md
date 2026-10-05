# AGENTS.md — Persistent Instructions for the AI Coding Agent

## Project

**Nudge.** A calm, intelligent reminder app that understands when a task can actually be done — not just when the clock says so.

- Android applicationId: `com.nudge.app.nudge` (CI runs `flutter create --org com.nudge.app --project-name nudge`). Changeable before the first Play listing.

## Constitution (binding)

Read these before making any decision:

- `/docs/PRODUCT.md`
- `/docs/ARCHITECTURE.md`
- `/docs/UX.md`
- `/docs/ROADMAP.md`

If a build decision conflicts with these documents, the documents win.

## Rules

1. Never skip a ROADMAP phase. Each phase has exit criteria; meet them before moving on.
2. Never add features from a later phase.
3. Calm is the default personality. No exclamation marks, no guilt, no streaks.
4. User intent comes first. Do not redefine what the user asked for.
5. All learned behavior is user-approved. Never silently change behavior.
6. Local-first. The app works offline.
7. Android is the only build target through Phase 8 (iOS ramp after Phase 6). Test on Android every phase.
8. Rules-first AI policy: deterministic rule-based parser is primary; LLM is enhancement only (ARCHITECTURE.md section 7).
9. When in doubt, ask the product owner. Do not guess on product decisions.
10. Model usage policy (binding): paid models (deepseek) are for planning and checking work only — commander, planner, reviewer, brainstormer. All coding and heavy lifting runs on the free model (`opencode/muse-spark-1.3-contributor-free`), configured in `~/.config/opencode/micode.json`. Never start coding or heavy lifting with a paid model. If the free model is rate-limited, report it and wait — do not silently fall back to a paid model.

## Current Phase

Phase 0 — Project Foundation (complete): constitution docs, app shell (`lib/main.dart`, `pubspec.yaml`), CI workflow, patch script. Committed and pushed to `https://github.com/Raaghu123/nudge-app` (private, `main`). Next: Phase 1 (per ROADMAP).

## Environment & Build (this machine)

- Flutter is **NOT installed** locally. Do not run `flutter` commands expecting them to work here.
- Verify Flutter code via CI, not locally. CI workflow is written (`.github/workflows/build-apk.yml`, mirrors `hydration_reminder`): `flutter create .` → `patch_android.py` → `pub get` → `analyze` → `build apk --debug`. Repo: `https://github.com/Raaghu123/nudge-app` (private — Actions minutes count against the free-plan 2,000/mo quota shared with other private repos).
- `android/` is never hand-committed; CI regenerates it via `flutter create` then applies a patch script. Do not hand-write manifests.
- This repo lives under `/Users/rapid/Documents/Default Project/reminder-app/`. It is independent from the sibling `together-app` and `hydration_reminder` projects — do not wire into them.

## Directory layout (target, per ROADMAP Phase 0)

```
reminder-app/
├── AGENTS.md
├── README.md
├── docs/            (PRODUCT, ARCHITECTURE, UX, ROADMAP)
├── app/
│   └── lib/
│       ├── core/          (shared logic: models, rules, event bus)
│       ├── components/    (capture, understanding, orchestrator, etc.)
│       ├── adapters/      (android/, ios/)
│       └── ui/            (screens, widgets)
└── tests/
    ├── unit/
    └── integration/
```
