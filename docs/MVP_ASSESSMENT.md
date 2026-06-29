# DailyFitness — MVP Assessment (Executive Summary)

**Prepared for:** the owner · **Date:** 2026-06-29 · **Scope:** native iOS app (SwiftUI + SwiftData + ActivityKit), Supabase backend, RevenueCat subscriptions.

---

## 1. Headline verdict

> **MODIFY & EXTEND — do not rebuild. Confidence: HIGH.**

The architecture is clean and salvageable, the "does not compile" headline is a **one-token cast**, and "looks horrible" is a **missing design-system layer** (additive work) — not structural rot. A rebuild would throw away ~5,000 LOC of working, tested domain logic (progression engine, PR detection, offline-first sync, SwiftData schema, ActivityKit bridge) to recover essentially nothing the current scaffold lacks. The remaining work — design language, 2,000-exercise dataset, program catalog, paywall triggers, onboarding — is breadth/polish/content that a rebuild would have to do anyway, from the *same* clean foundation that already exists.

---

## 2. Current state (one paragraph)

The app **does not build today**, but only because of a single trivial type mismatch in `DailyFitness/Shared/WorkoutIntentBridge.swift` (a `CFString` passed where `CFNotificationName` is expected) in the Live Activity extension — the main app target already compiles, and a one-token cast unblocks it. It is a **thin but coherent scaffold**: ~5,100 LOC across ~43 Swift files, textbook layered architecture, constructor-based DI, a pure unit-tested progression engine, a working offline-first sync engine, a real ActivityKit Live Activity, and a correct Calm Strength color palette in the asset catalog. **Overall MVP completion is ~49%** against the 40 P0 user stories (per-domain: Logging/Lock Screen 58%, Programs/Library 38%, Progression/Analytics 42%, Account/Sync/Monetization/Onboarding 58%). The two standout gaps are exactly the owner's two complaints: **content** — the exercise library has **149 of the required ≥2,000 exercises (<8%)**, all with null media, and only **3 of 11+ programs** — and **design** — `DesignSystem/CalmStrength.swift` is a ~101-line token stub with **0 shadows, 3 animation calls, 0 haptics**, a flat depthless card, stock `.borderedProminent` buttons, and 4 stock grey `Form` screens, so the app reads as an unfinished Xcode scaffold wearing a green tint despite the palette being correct.

---

## 3. Evidence behind the verdict

| Axis | Finding | Implication |
|------|---------|-------------|
| **Build status** | Builds **NO** — exactly one distinct compile error (`WorkoutIntentBridge.swift:17`, a `CFString`→`CFNotificationName` cast). Main app compiled; only the extension failed. SPM resolves all 8 packages. | The "broken" headline is a one-line fix, not a sign of a rotten codebase. |
| **Architecture salvageability** | Rated **good / salvageability HIGH / recommendation MODIFY**. Clean App/Domain/Data/Services/Features/DesignSystem/Shared layering; `DependencyContainer.makeDefault()` is a real composition root; `ProgressionEngine` is a pure `Sendable` struct behind a protocol with unit tests; coherent `@MainActor` concurrency; sound SwiftData modeling (unique ids, cascade relationships). | The expensive, hard-to-rebuild parts are the parts that are already good. Defects are **localized bugs behind existing seams**, not structural. |
| **Design severity** | **Systemic, effort to fix LARGE — but additive.** The palette is correct; the *language* is missing (no typography scale, no elevation, no motion, no iconography, stock components). Highest-ROI fixes concentrate in one file (`CalmStrength.swift`) plus mechanical view edits. | Fixable in place; a rebuild would still have to build this design system from scratch. |
| **Feature/content gap** | **~49% of P0** complete; biggest holes are content breadth (149/2,000 exercises, 3/11 programs) and polish (paywall triggers, onboarding, haptics, summary screen). | Breadth/content a rebuild cannot avoid — the win is keeping the foundation, not avoiding the work. |
| **Red flags** | Real but **localized**: sync delete hard-coded to `workout_sessions` (`SyncEngine.swift:~327`), RIR operator-precedence bug (`ProgressionEngine.swift:71`), 15 swallowed `try? save()` sites. | Surgical fixes behind existing seams — exactly what modify-in-place handles cheaply. |

---

## 4. What to keep vs. replace

**KEEP (the foundation worth preserving):**
- Layered architecture + constructor-DI composition root (`DependencyContainer`).
- `ProgressionEngine` + protocol (pure, testable) and its tests; `PRDetector` / `PRService`; `WorkoutSessionCoordinator`.
- SwiftData schema (unique ids, cascade relationships, enum↔rawValue bridging).
- Offline-first `SyncEngine` *design*; ActivityKit Live Activity + App Group + Darwin-notification bridge.
- Calm Strength asset-catalog palette; `ContentLimitService`; `AuthService` (Sign in with Apple); Supabase migrations.

**REPLACE / REWORK (body, not role):**
- **`DesignSystem/CalmStrength.swift`** — token stub → real design language (typography, elevation, motion, custom buttons, branded chrome). *Single highest-leverage file for the "horrible" complaint.*
- The 4 stock `Form` screens (Routine/Program/Profile/CustomExercise editors) → one card-based visual language.
- `SyncEngine` correctness gaps (right delete table, conflict resolution, real `updatedAt` cursor, full restore, persistent queue) — harden behind the seams, don't replace.
- Pervasive `try? context.save()` swallowing → logging + user-facing surfacing.

**EXPAND (correct but thin — content, not rework):**
- Exercise library **149 → ≥2,000** via the existing import pipeline (+ media). Program catalog **3 → 11+** (add yoga/flexibility/hybrid).
- Paywall triggers at limit points, 4-screen personalizing onboarding, real app icon + iconography.

*(Full file-by-file inventory in `CODE_DISPOSITION.md`.)*

---

## 5. Recommended path to a working MVP

Six dependency-ordered phases. The owner's two blockers (compile + looks) are pulled to the front.

- **Phase A — Make it build + design-system foundation.** Fix the one-line compile error; rebuild `CalmStrength.swift` into a real design language (typography, elevation, motion, custom buttons, dark Accent); apply it to all tabs + the 4 Form screens; ship a real app icon. *Unblocks the owner on both complaints.*
- **Phase B — Core logging + Lock Screen completeness.** Haptics, "Last time" previous performance, set types (warmup excluded from volume), supersets, notes, rest-timer skip, end-of-workout summary; Live Activity end-button + permission explainer + rest-end notification fallback; durable offline queue.
- **Phase C — Programs + exercise-library scale-up.** Library → ≥2,000 (+ media + taxonomy); catalog → ≥11 across all 5 categories; Exercise Library browse + detail; custom program day-slot builder; fork suggested→custom.
- **Phase D — Progression engine + analytics.** Targets from routine rep ranges; fix RIR precedence bug + 0–5 picker; deload; per-exercise toggle; accept/edit/ignore; charts (reps/volume/e1RM); calendar; muscle volume; mobility/yoga time.
- **Phase E — Account/sync hardening + monetization + onboarding.** Correct sync (delete table, conflict handling, full restore, persistent queue); real remote account deletion; paywall triggered at every limit; 7-day trial + manage-subscription link; 4-screen personalizing onboarding.
- **Phase F — Polish, accessibility, on-device QA, TestFlight.** Kill silent persistence failures; strict concurrency; VoiceOver/Dynamic Type/contrast; iconography + rest-timer ring; physical-device QA (Live Activity, haptics, StoreKit sandbox) → TestFlight.

> **Phases B–E share key files** (`SwiftDataModels.swift`, `CalmStrength.swift`, `LiveWorkoutView.swift`) — run sequentially or coordinate merges. **Every UI phase ends with on-device visual/behavior QA** (`ios-qa` + `ios-design-review`); Live Activity, haptics, and StoreKit trial **require a physical device**.

---

## 6. Detailed docs + immediate next action

The three planning artifacts (relative to repo root):

- **Roadmap:** [`.context/MVP_ROADMAP.md`](./MVP_ROADMAP.md) — phased plan with per-task file targets, Definition of Done, and QA gates.
- **Design-system spec:** [`.context/DESIGN_SYSTEM_SPEC.md`](./DESIGN_SYSTEM_SPEC.md) — full Calm Strength token + component implementation spec.
- **Code disposition:** [`.context/CODE_DISPOSITION.md`](./CODE_DISPOSITION.md) — keep / refactor / replace / expand inventory, file by file.

### Immediate next action

**Start Phase A.** First step: fix the build (one-token cast in `DailyFitness/Shared/WorkoutIntentBridge.swift`), then verify both targets compile:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DailyFitness.xcodeproj -scheme DailyFitness \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/df-build CODE_SIGNING_ALLOWED=NO build
```

Then move straight into the `CalmStrength.swift` design-system overhaul (per the design spec) — this is the single highest-ROI work and addresses the owner's "looks horrible" complaint directly. **Do not ship before the Phase A design language lands**; the current state reads as broken regardless of feature completeness.
