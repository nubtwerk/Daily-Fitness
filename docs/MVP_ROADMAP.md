# DailyFitness — MVP Roadmap (scaffold → shippable v1.0)

**Decision honored:** MODIFY & EXTEND (confidence: high). The architecture is clean and salvageable;
the build break is one line; "looks horrible" is a missing design-system layer (additive work). We keep
the layered architecture, DI composition root, ProgressionEngine, PRDetector, SyncEngine design, SwiftData
schema, and the ActivityKit/Darwin bridge — and we fill breadth/polish/content on top of that foundation.

**Source of truth:** PRD §9.1 (P0 features), §9.2 (program catalog), §6 (Calm Strength), §15 (phases);
USER_STORIES.md (40 P0 stories); plus the verified assessment in this repo's brief.

---

## 0. Current state (verified)

| Dimension | Status |
|-----------|--------|
| **Builds?** | **NO.** Single blocking compile error in `DailyFitness/Shared/WorkoutIntentBridge.swift` (line 11 declares `darwinNotificationName` as `CFString`; line 17 passes it to `CFNotificationCenterPostNotification` which wants `CFNotificationName`). One-token cast fixes it. Main app target already compiled; only `WorkoutLiveActivityExtension` fails. |
| **Config** | `Config/Secrets.xcconfig` now exists (created from example, placeholder values, gitignored). `Debug/Release.xcconfig` `#include` it. SPM resolves 8 packages (Supabase 2.48, RevenueCat 5.80, etc.). |
| **Toolchain** | Xcode at `/Applications/Xcode.app`; `xcode-select` points at CommandLineTools. **Prefix all Xcode commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.** SDK iPhoneSimulator 26.5, deployment target iOS 17.0. |
| **Scale** | ~5,100 LOC, 41 Swift files (+2 extension files). Clean layered scaffold. |
| **Design** | Calm Strength palette correct in asset catalog. `DesignSystem/CalmStrength.swift` is a ~101-line token stub: 0 shadows, 3 animation calls, 0 haptics, flat `DFCard`, stock `.borderedProminent` buttons, 4 stock `Form` screens, no typography scale, no motion, no iconography, empty `AppIcon` set. |
| **Content** | Exercises: **149 / 2,000+** (PRD LIB-01) — under 8%, all `imageURL=null`. Programs: **3 / 11+** (PRD §9.2). |
| **Overall completion vs P0** | **~49%** (per-domain: Logging/Lock 58%, Programs/Library 38%, Progression/Analytics 42%, Account/Sync/Monetization/Onboarding 58%). |

### Files that already exist and we modify in place

App: `App/DailyFitnessApp.swift`, `App/DependencyContainer.swift`, `App/MainTabView.swift`
Design: `DesignSystem/CalmStrength.swift` (the single highest-leverage file)
Domain: `Domain/Progression/ProgressionEngine.swift`, `Domain/WorkoutSessionCoordinator.swift`,
`Domain/Services/{ProgressionService,PRDetector,PRService,ContentLimitService,ProgramScheduleResolver}.swift`,
`Domain/Models/DomainTypes.swift`
Data: `Data/Persistence/{SwiftDataModels,ExerciseSeeder,ProgramSeeder,RoutineSeeder}.swift`,
`Data/Repositories/{ExerciseRepository,UserPreferencesRepository}.swift`, `Data/Sync/SyncEngine.swift`
Services: `Services/{AuthService,RevenueCatService,WorkoutExportService}.swift`
Features: `Features/Home/HomeView.swift`, `Features/Workout/{LiveWorkoutView,SetRowFactory,WorkoutExerciseFactory,ProgressionBanner,LiveActivityManager}.swift`,
`Features/Programs/{ProgramsView,ProgramDetailView,RoutineEditorView}.swift`, `Features/Progress/ProgressTabView.swift`,
`Features/Profile/{ProfileView,PaywallView}.swift`, `Features/Exercises/{ExercisePickerView,CustomExerciseEditorView}.swift`,
`Features/Onboarding/OnboardingView.swift`
Shared: `Shared/{WorkoutIntentBridge,WorkoutIntentObserver,WorkoutSessionState,AppGroup}.swift`
Extension: `WorkoutLiveActivityExtension/{WorkoutLiveActivityBundle,WorkoutLiveActivityIntents}.swift`
Data assets: `Resources/Exercises/{exercises.json,exercises-manifest.json}`, `Resources/Programs/programs.json`
Scripts: `scripts/import-exercises.py` (documented pipeline — LIB-01), `scripts/run-simulator.sh`
Migrations: `supabase/migrations/2026062700*.sql`

---

## Target MVP — Definition of Done (P0 = 40 user stories / PRD §9.1)

The MVP is shippable when **all of these are true** (each maps to PRD IDs / user stories):

1. **Compiles & runs** on simulator and a physical device; crash-free core loop
   (onboarding → program → log workout → Lock Screen → summary → history). (US-120)
2. **Looks designed**, not scaffolded — Calm Strength as a real design language: typography scale,
   elevation, motion, custom buttons, branded chrome, real app icon. (US-001, PRD §6)
3. **Logging loop complete**: start ≤2 taps, strength + mobility/yoga fields, set-complete with **haptic**,
   **"Last time" previous performance**, set types (warmup excluded from volume), supersets, notes,
   rest timer (skip + extend), **end-of-workout summary**. (LOG-01..11, US-050..055)
4. **Lock Screen complete**: Live Activity with rest countdown, complete-set, **end-workout button**,
   permission explainer, **local-notification fallback** at rest end. (LOCK-01..06, US-060..063)
5. **Programs & library**: ≥11 suggested programs across all 5 categories, program detail w/ metadata,
   start/fork/custom builder with day-slot assignment, custom routine builder, **≥2,000 exercises**,
   exercise detail view, custom-exercise create/edit/delete. (PRG-01..07, LIB-01..06, US-020..023, US-070..073)
6. **Progression & analytics**: targets from routine rep ranges, RIR path fixed (0–5 picker), deload,
   per-exercise toggle, accept/edit/ignore, PRs (incl. volume), e1RM shown, charts (weight/reps/volume),
   calendar, muscle volume, mobility/yoga time. (PROG-01..07, AN-01..07, US-080..083, US-090..093)
7. **Account/sync/monetization/onboarding**: Sign in with Apple as primary auth + real account deletion,
   full cloud restore (not just sessions), correct sync (right delete table, conflict handling, persistent
   queue), paywall triggered at all limit points, 7-day trial + manage-subscription link, 4-screen
   onboarding that personalizes. (ACC-01..03, MON, ONB, US-010..012, US-030/031, US-110..112)
8. **Quality basics**: VoiceOver labels on live-workout controls, Dynamic Type, 44pt targets, WCAG-AA
   contrast; persistence errors logged/surfaced (no silent `try?`). (US-122)

P0 stories explicitly OUT of phase-by-default but kept on the critical path: US-112 (paywall triggers) is
labeled Phase 3 in the stories but is a **must** for the freemium model — it lands in Phase E here.

---

## Phasing strategy

Ordered by **dependency** and **ROI**, with the owner's two blockers (compile + looks) pulled to the front.

```
Phase A  Make it build + design-system foundation        ← unblocks owner; everything else inherits the look
Phase B  Core logging + Lock Screen completeness         ← the product's reason to exist
Phase C  Programs + exercise-library scale-up            ← content breadth (149→2,000, 3→11)
Phase D  Progression engine + analytics                  ← correctness + Premium value
Phase E  Account/sync hardening + monetization + onboarding
Phase F  Polish, accessibility, on-device QA, TestFlight
```

Each phase ends with a **visual/on-device QA gate** where noted — those checks CANNOT be verified headlessly
and must run the app via the `ios-qa` / `ios-design-review` skills.

---

## Phase A — Make it build + design-system foundation

**Goal:** App compiles, runs, and reads as *intentionally designed* (Calm Strength). This unblocks the owner
on both complaints. Highest ROI per hour.

### A1. Fix the build (BLOCKER) — LOG/LOCK infra
- **Touch** `Shared/WorkoutIntentBridge.swift`: change line 11/17 so the value passed to
  `CFNotificationCenterPostNotification` is a `CFNotificationName` (e.g. declare
  `static let darwinNotificationName = CFNotificationName("app.dailybase.dailyfitness.workoutIntent" as CFString)`).
- **Verify**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project DailyFitness.xcodeproj -scheme DailyFitness -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/df-build CODE_SIGNING_ALLOWED=NO build` exits 0 for **both** targets. Run the existing test target.
- Note: `xcodegen generate` rewrites `project.pbxproj` + entitlements; regenerate before building if `project.yml` changed.

### A2. Design-system overhaul — `DesignSystem/CalmStrength.swift` (US-001, PRD §6)
This is the single highest-leverage file. Add, in one pass:
- **Typography**: `DFTypography` / `DFText` tokens (display/title/heading/body/caption) on SF Pro,
  **medium-weight headings**, explicit `.lineSpacing`. Replace ad-hoc `.font(.headline/.subheadline/...)`.
- **Elevation**: shadow tokens + an **elevated `DFCard`** (soft shadow ~`black.opacity(0.06)`, radius 12, y 4;
  1px hairline stroke for dark mode). Fix surface-vs-stone contrast.
- **Buttons**: custom `ButtonStyle` — primary (filled forest, spring press scale ~0.97, subtle shadow),
  secondary (tinted/ghost), tertiary (text) — replace stock `.borderedProminent`/`.bordered`.
- **Motion**: `CalmStrength.Motion` namespace (e.g. `.spring(response:0.4, dampingFraction:0.85)`).
- **Color**: add a **dark-appearance variant to `Accent.colorset`** (currently universal-only).

### A3. Apply the system to existing screens (mechanical)
- **Touch** the 4 stock `Form` screens — `Features/Programs/RoutineEditorView.swift`,
  `Features/Programs/ProgramDetailView.swift` (ProgramEditorView), `Features/Profile/ProfileView.swift`,
  `Features/Exercises/CustomExerciseEditorView.swift` — either `.scrollContentBackground(.hidden)` +
  `Color.dfBackground` + custom section headers, or migrate to `DFCard`/section system so the app is one language.
- **Touch** `App/MainTabView.swift` + the 4 `navigationTitle` sites (HomeView, ProgramsView, ProgressTabView,
  ProfileView): branded `UINavigationBar`/`UITabBar` appearance, medium-weight title, warm-stone background.
- Migrate the most-visible views (`HomeView`, `LiveWorkoutView`, `ProgressTabView` cards) to the new
  typography + elevated card + custom buttons.

### A4. App icon + empty-state art seed (PRD §6)
- Replace the empty 177-byte `AppIcon.appiconset` with a real **abstract flow/balance** icon (no barbell).
- Give `DFEmptyState` an abstract SF Symbol/mark + a CTA slot (cheapest place to introduce brand iconography).

**Definition of done (Phase A):** both targets build; test target passes; `CalmStrength.swift` has typography
+ elevation + motion + custom button styles + dark Accent; all 4 tabs + 4 Form screens read as one Calm Strength
language; real app icon ships.

**Requires simulator / on-device visual QA:** A2/A3/A4 — **YES** (this is the "looks horrible" fix).
Run `ios-design-review` in light + dark mode across all 4 tabs, live workout, and one Form screen. A1 verifiable headlessly.

---

## Phase B — Core logging + Lock Screen completeness

**Goal:** Close the P0 gaps in the product's core loop (Logging 58% → done; Lock 58% → done).

### B1. Fast logging gaps (LOG-02/04/06; US-051/052)
- **Haptics** on set complete (`UINotificationFeedbackGenerator` / `.sensoryFeedback`) — currently 0 in app.
  Touch `Features/Workout/SetRowFactory.swift` + `Domain/WorkoutSessionCoordinator.swift`.
- **Previous-performance "Last time: 80kg × 8" / "Last: 45s hold"** as ghost text on set rows. New helper
  in `Domain/Services` (last-completed working set per exercise) + render in `SetRowFactory.swift`. Make prefill
  a *placeholder*, not a destructive overwrite of `weightKg`.
- Spring + row-fill completion animation on set complete (uses Phase-A Motion).

### B2. Set types, supersets, notes (LOG-07/08/09; US-054/041/042)
- **Set-type picker** per row (normal/warmup/failure/drop) in `SetRowFactory.swift`; **exclude warmup from
  volume + progression** (touch `ProgressionService.buildHistory`, `PRDetector`, `ProgressTabView` volume).
- **Supersets**: wire `supersetGroupId` (already on models) — grouping UI in `RoutineEditorView.swift` and
  cycling in `LiveWorkoutView.swift`.
- **Notes**: session-level + per-exercise note editors in `LiveWorkoutView.swift` (fields already on models).

### B3. Rest timer + summary (LOG-05/10; US-053/055)
- Add **skip** control (only extend exists) and per-exercise rest override
  (`routineExercise.restSeconds`) in `LiveWorkoutView.swift`.
- **End-of-workout summary screen** (new `Features/Workout/WorkoutSummaryView.swift`): duration, volume/total
  time, exercises completed, PR highlights, add-note-before-save. Wire from `WorkoutSessionCoordinator.finishSession`.

### B4. Lock Screen completeness (LOCK-05/06; US-060/062/063)
- Place the **End-workout button** (existing `EndWorkoutIntent`) into `WorkoutLiveActivityBundle.swift`
  `LockScreenWorkoutView` (currently defined but never rendered).
- **Permission explainer** before requesting Live Activities (touch start path in
  `WorkoutSessionCoordinator.startLiveActivityIfEnabled`).
- **Rest-end local notification fallback**: import `UserNotifications`, schedule on rest start when
  `restEndNotificationEnabled` (currently a dead toggle). New small `Services/NotificationService.swift`.
- **Deep-link/widgetURL fallback**: tapping the Live Activity opens app to the set row when interactive
  buttons are unavailable / app suspended.

### B5. Offline queue durability (LOG-11; US-011)
- Persist the sync op queue (currently in-memory only in `SyncEngine.swift`) and **re-enqueue pending
  entities at launch** so offline-then-killed edits resync. (Deeper sync correctness is Phase E.)

**Definition of done (Phase B):** every LOG-/LOCK- acceptance criterion met; haptic + previous-performance +
summary present; warmup excluded from math; Live Activity has complete-set + end + rest countdown; rest-end
notification fires when Live Activities off.

**Requires simulator / on-device visual QA:** B1 (haptics), B4 (Live Activity on Lock Screen + Dynamic Island)
— **YES, physical device required** for Live Activity interactivity and haptics. Use `ios-qa`. B2/B3/B5 mostly
verifiable in simulator; summary screen wants a design pass via `ios-design-review`.

---

## Phase C — Programs + exercise-library scale-up (content breadth)

**Goal:** Programs 38% → done; Library to ≥2,000. This is breadth/content the rebuild would not have avoided.

### C1. Exercise library to ≥2,000 (LIB-01/02/05/06; US-020) — DATA WORK
- Use **`scripts/import-exercises.py`** (the documented pipeline; it accepts an input JSON and normalizes to
  `Resources/Exercises/exercises.json` + `exercises-manifest.json`). Source a licensable open dataset
  (PRD names ExerciseDB) + curated yoga/mobility records, run the importer, regenerate the manifest.
  Note: there are two scripts in `scripts/` — `import-exercises.py` is the authoritative one; reconcile/delete
  the smaller `import_exercises.py` to avoid confusion.
- Attach **media**: at minimum a per-category placeholder so `imageURL` is never null and views render an
  image (LIB-05); wire `AsyncImage`/asset rendering (currently 0 image rendering anywhere).
- Add a **canonical muscle/equipment taxonomy** (enum) so seeded data and the custom-exercise editor agree
  (LIB-06) — touch `CustomExerciseEditorView.swift` hardcoded `muscleOptions`.
- **Validation**: spot-check top 500 metadata (PRD §16 risk). Confirm search renders <300ms on-device (US-021).

### C2. Exercise library browse + detail (LIB-03/04; US-022/023)
- New **standalone Exercise Library** browse screen + **Exercise Detail view** (name, category, muscles,
  equipment, illustration, add-to-routine, "Last: 80kg × 8" history snippet). Currently exercises are only
  reachable through `ExercisePickerView` inside the routine editor.
- Add an **equipment filter chip** (currently equipment is free-text only).
- Custom exercise **edit + delete** UI (only create exists) in `Features/Exercises/`.

### C3. Program catalog to ≥11 (PRG-01/07; US-070) — DATA WORK
- Author the missing programs in `Resources/Programs/programs.json` to cover PRD §9.2:
  Upper/Lower, PPL, Full Body 3×, Beginner Strength; Daily Mobility 10, Post-Lift Stretch, Hip & Ankle
  Opener, Shoulder Recovery Flow; Morning Flow 20, Recovery Yoga, Strength+Yoga Hybrid. Include
  **yoga/flexibility/hybrid** (currently none).
- Add **goal-based browse** (category filter) in `ProgramsView.swift` (currently a flat list).

### C4. Program model + detail + builder + fork (PRG-02/04/06; US-071/072/073)
- Extend `ProgramEntity` (`SwiftDataModels.swift`) with **description, level, daysPerWeek, equipment**;
  show them in `ProgramDetailView.swift` (PRG-02). Add **pause/leave program**.
- **Custom program builder**: add **routine-to-day-slot assignment** in the ProgramEditor (currently captures
  only name/category/weeks — programs save with zero days). This is the defining PRG-04 criterion.
- **Fork suggested → custom**: "Duplicate & edit" action, "Based on [Program]" label, editable copy
  (PRG-06). Surface the `sourceTemplateId` already set on start-copy.

**Definition of done (Phase C):** `exercises-manifest.json` count ≥2,000 with non-null media; ≥11 programs
spanning all 5 categories; Exercise Library + Detail screens exist; custom program builder assigns routines to
days; fork works; program detail shows full metadata.

**Requires simulator / on-device visual QA:** C2/C3/C4 — **YES** (browse, detail, builder are UI). C1 is mostly
data/script work (verify search performance on-device). Run `ios-qa` on the picker/library and `ios-design-review`
on program detail + library cards.

---

## Phase D — Progression engine + analytics

**Goal:** Progression/Analytics 42% → done; restores Premium value and engine correctness.

### D1. Progression engine correctness (PROG-01/02/05; US-080/082/083; PRD §12)
- **Use routine rep targets**: `ProgressionService` (line ~68) hardcodes `RepRange(8,12)` — read
  `targetRepsMin/targetRepsMax` from the routine instead, and reset state when targets change (PROG-01).
- **Fix RIR precedence bug**: `ProgressionEngine.swift:71` `targets.min + targets.max / 2 + 2` evaluates wrong
  (Swift precedence → always hold). Add the missing parentheses and a unit test for the RIR branch.
- Replace the free-text **RIR input with a 0–5 picker** (`SetRowFactory.swift`), shown only when RIR enabled.
- **Per-exercise progression toggle** (PROG-05): read `RoutineExerciseEntity.progressionEnabled` in the
  service/engine (currently written but never read) + add a UI toggle in routine settings.
- **Accept/edit/ignore recommendation flow** (US-080): stop silently overwriting set weights; make the banner
  actionable.

### D2. Deload (PROG-04; US-083)
- Track failed progression attempts; add a **deload case** to `ProgressionAction` (`DomainTypes.swift`) and a
  non-blocking deload banner after 3 failures. Currently entirely absent.

### D3. Analytics gaps (AN-02/03/04/05/06/07; US-090/091/092/093)
- **Charts**: plot reps + volume + **e1RM** (e1RM is computed in `PRDetector` but never displayed); free =
  90 days, Premium = all-time with upgrade prompt at the boundary (touch `ProgressTabView.swift`
  ExerciseChartView). Fix that charts are currently fully Pro-gated (contradicts AN-02 free 90-day).
- **Volume PRs**: `PersonalRecordType.sessionVolume` is defined but never produced — emit it in `PRDetector`.
- **Calendar view** (AN-06) with completed sessions + **category filter** on history list (neither exists).
- **Muscle volume**: 30-day free window (currently 7), exclude warmup sets, all-time + trends for Premium (AN-05).
- **Mobility/yoga time tracking** in Progress tab (AN-07) — absent today.
- **Move heavy aggregation out of view computed properties** (ProgressTabView ExerciseChartView/MuscleHeatmap
  run O(sessions×exercises×sets) on every render) into a service / precomputed store.

**Definition of done (Phase D):** recommendations derive from routine targets; RIR branch correct + tested +
0–5 picker; deload banner; per-exercise toggle works; charts show weight/reps/volume/e1RM with correct
free/Premium gating; calendar + category filter; volume PRs; warmup excluded everywhere; mobility/yoga time shown.

**Requires simulator / on-device visual QA:** D3 charts/calendar/heatmap — **YES** (visual + interaction).
Engine/PR logic (D1/D2) is unit-testable headlessly — extend the existing `ProgressionEngineTests` /
PR-detector tests. Run `ios-qa` on the Progress tab.

---

## Phase E — Account/sync hardening + monetization + onboarding

**Goal:** Account/Sync/Monetization/Onboarding 58% → done; make the freemium model real and data safe.

### E1. Sync correctness (LOG-11/ACC-02; US-011) — DATA-LOSS RISK, do deliberately
- **Route `deleteEntity` to the correct table per entity type** (currently hard-coded to `workout_sessions`
  in `SyncEngine.swift:~327`) and propagate soft-deletes.
- **Conflict resolution**: `SyncStatus.conflict` is declared but never set/read; `pullRemoteChanges` skips rows
  that exist locally (drops remote edits). Add a real `updatedAt` cursor and bump `updatedAt` on every mutation
  (only ~6 sites bump it today — e.g. `completeSet`/`finishSession` don't).
- **Full cloud restore**: pull `workout_sets`, routines, programs, ProgramDay rows, and custom exercises — not
  just `workout_sessions` (capped at 100). Push ProgramDay rows (never pushed today). Remove the 100-row cap.
- Construct **one** `SupabaseClient` (both `SyncEngine`/`AuthService` rebuild it on every property access).

### E2. Account (ACC-01/03; US-010/012)
- Make **Sign in with Apple the primary auth surface** (welcome/auth screen, not just a Profile row); prompt
  cloud sync after first saved workout.
- **Real account deletion** (server-side delete function via Supabase) — currently only signs out + wipes local.
- **CSV export**: add `set_type` + `notes` columns; for free users show **upgrade prompt, not a disabled button**.

### E3. Monetization (MON; US-111/112)
- **Trigger the paywall at all limit points** (US-112): 6th routine/program, 3rd progression exercise, 90+ day
  history, CSV export. Today the limit shows a bare alert and `PaywallView` is reachable only from one Profile
  button. Wire `PaywallView` with context-relevant benefits at each site.
- **Reconcile limit values to PRD §13**: "5 custom programs/routines **combined**" (code uses separate 5+5);
  drop the invented 20-custom-exercise cap; muscle-volume window 30-day free (not 7).
- **7-day free trial** (RevenueCat intro offer) + **manage/cancel subscription** App Store link + feature
  comparison in the upgrade flow (all missing today).

### E4. Onboarding (ONB; US-030/031)
- Expand `OnboardingView.swift` to **4 screens**: welcome → training-types (and actually **persist + use** the
  selection, currently dead state) → **suggested-program picker filtered by selections** → **Lock Screen
  opt-in** → Home with "Start first session" CTA. (US-031 locale defaults already done.)

**Definition of done (Phase E):** sync deletes/edits/restore correct and durable; account deletion truly
deletes remote; paywall fires at every limit with relevant benefits; trial + manage-subscription present;
onboarding is 4 screens and personalizes Home.

**Requires simulator / on-device visual QA:** E2/E3/E4 (auth flow, paywall presentation, onboarding) — **YES**;
StoreKit/trial best validated on-device/TestFlight sandbox. E1 sync correctness — write integration tests +
verify with a second simulator/device restore. Run `ios-qa` on onboarding + paywall.

---

## Phase F — Polish, accessibility, on-device QA, TestFlight

**Goal:** Ship-readiness (US-120/122; PRD §15 Phase 2–3).

### F1. Error-handling posture (project-wide)
- Replace the 15 swallowed `try? context.save()` sites (esp. `WorkoutSessionCoordinator`, `ProgressionService`,
  `UserPreferencesRepository`, and the `DailyFitnessApp` `.task` seeding chain) with logging + user-facing
  failure surfacing, especially on the live-workout save path.
- Turn on **strict-concurrency checking** (currently no flag; @MainActor discipline is convention-only).

### F2. Accessibility (US-122)
- VoiceOver labels on all live-workout interactive controls; Dynamic Type without layout breakage; 44pt targets
  on set-complete + primary actions; WCAG-AA contrast audit of Calm Strength (esp. the new elevated cards).

### F3. Phase-2 design assets (PRD §6, deferred from Phase A)
- Abstract flow/balance **iconography** set (vector); **soft natural hero imagery** for onboarding/program
  cards/empty states; **calm circular rest-timer ring** (replace bare number, sage, no red/flashing).

### F4. On-device QA + TestFlight (US-120)
- Full core-loop pass on a **physical device** (Live Activity, haptics, Dynamic Island, StoreKit sandbox).
- Crash-free ≥99%; feedback channel in Profile; submit TestFlight.

**Definition of done (Phase F):** no silent persistence failures; strict concurrency on; accessibility criteria
met; rest-timer ring + iconography landed; TestFlight build of the full loop passes on hardware.

**Requires simulator / on-device visual QA:** **ALL of F** — this phase IS the device QA gate. Use `ios-qa`
(behavior) + `ios-design-review` (final visual sign-off) on physical hardware.

---

## How to execute this roadmap

- **Run each phase as its own follow-up Workflow.** Phases are dependency-ordered: A unblocks everything;
  B/C/D/E are largely parallelizable *after* A but share files (`SwiftDataModels.swift`, `CalmStrength.swift`,
  `LiveWorkoutView.swift`) so run them sequentially or coordinate merges carefully. F is last.
- **Always prefix Xcode commands** with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Regenerate
  with `xcodegen generate` after any `project.yml` change; build with `-scheme DailyFitness -destination
  'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`.
- **Visual + on-device verification cannot be done headlessly.** At the end of every phase with a UI surface,
  the main loop must run the **`ios-qa`** skill (live-device behavior) and **`ios-design-review`** skill
  (Calm Strength visual audit, light + dark). Live Activity, haptics, Dynamic Island, and StoreKit trial
  REQUIRE a physical device / sandbox — note these explicitly in each phase's QA gate above.
- **Two big content tracks can start early and run in the background of B–E:** (1) library 149→2,000 via
  `scripts/import-exercises.py` + media + taxonomy (Phase C1); (2) program catalog 3→11 in `programs.json`
  (Phase C3). Neither blocks code work, but both are required for the MVP definition-of-done and are easy to
  under-scope — track them as first-class deliverables, not afterthoughts.
- **Suggested commit discipline:** one phase = one feature branch off `main`; commit/push only when asked.
```
