# DailyFitness — Code Disposition Inventory

**Decision context:** MODIFY & EXTEND (high confidence). The architecture is clean and salvageable;
the build break is a one-token cast; "looks horrible" is a missing design-system *layer* (additive
work), not structural rot. This document is the keep / refactor / replace / expand inventory that
flows from that decision.

**Legend**
- **KEEP** — sound; touch only incidentally. The foundation worth preserving.
- **REFACTOR** — keep the design/seam, fix localized bugs or move misplaced logic.
- **REPLACE** — rewrite this file's body (interface/role survives, implementation does not).
- **EXPAND** — correct but thin; the work is breadth/content, not rework.

**TL;DR — high-value assets to preserve:** the layered architecture + constructor-DI composition
root (`DependencyContainer`), the pure **ProgressionEngine** behind its protocol, **PRDetector /
PRService**, the **SwiftData schema** (unique ids + cascade relationships), the **offline-first
SyncEngine design**, the **ActivityKit Live Activity + Darwin-notification bridge**, the
**Calm Strength asset-catalog palette**, **ContentLimitService**, **AuthService** (Sign in with
Apple), and the **Supabase migrations**. The single biggest *rework* target is
`DesignSystem/CalmStrength.swift` (token stub → real design language); the single biggest *content*
target is the exercise library (149 → ≥2,000) and program catalog (3 → 11+).

---

## App/

| File | Disposition | Reason |
|------|-------------|--------|
| `App/DependencyContainer.swift` | **KEEP** | Clean constructor-based composition root; `makeDefault()` (lines 96–130) wires everything with no globals — the textbook DI shape the architecture audit rated "good." |
| `App/DailyFitnessApp.swift` | **REFACTOR** | Schema/DI/in-memory fallback are sound (KEEP that), but the `.task` seeding→restore→pull→flush chain only `print()`s / `try?`s errors; add logging + surfacing so a mid-chain failure doesn't degrade silently. |
| `App/MainTabView.swift` | **REFACTOR** | Correct 4-tab IA + full-screen-cover live workout (IA §11 done); only chrome needs work — stock `TabView` with bare `.tint` should get branded tab/nav appearance. |

---

## DesignSystem/

| File | Disposition | Reason |
|------|-------------|--------|
| `DesignSystem/CalmStrength.swift` | **REPLACE** (body) | Highest-leverage file for the "horrible" verdict: a ~101-line token stub (spacing + radius + 5 colors + one flat depthless `DFCard` + stock `.borderedProminent`/`.bordered` buttons). Rewrite into a real design language — typography scale (medium-weight headings, line spacing), elevation/shadow tokens + elevated card, custom `ButtonStyle` (primary/secondary/tertiary) with spring press states, a `Motion` namespace. Keep the enum namespace + `Color` extension; replace the components. |

---

## Features/

| File | Disposition | Reason |
|------|-------------|--------|
| `Features/Home/HomeView.swift` | **REFACTOR** | UI/quick-start (LOG-01 done) stays, but `startRoutine` (105–136) builds the whole session, fetches all exercises, prefills, and enqueues sync *inside the View* — move that into a coordinator/service. |
| `Features/Workout/LiveWorkoutView.swift` | **REFACTOR + EXPAND** | Core live loop works (delegates to coordinator); fragile bits (Darwin observer lifecycle, only-while-alive completion) need hardening, and missing P0s — haptics (LOG-04), previous-performance "Last time" (LOG-06), skip-rest (LOG-05), end-of-workout summary (LOG-10), notes (LOG-09) — must be added. |
| `Features/Workout/WorkoutSessionCoordinator.swift` *(under Domain/, listed here for the workout feature)* | **KEEP + REFACTOR** | Genuine domain coordinator keeping side-effects (PR, progression, sync, live-activity, rest timer) out of views — preserve the role; bump `updatedAt` on mutations and stop swallowing `try?` saves. |
| `Features/Workout/SetRowFactory.swift` | **REFACTOR + EXPAND** | Category-driven rows (LOG-03) are right; restyle stock `.roundedBorder`/`Stepper` inputs to the card system, add set-complete spring feedback, swap the free-text RIR field for a 0–5 picker (PROG-02), and surface set-type selection (LOG-07). |
| `Features/Workout/WorkoutExerciseFactory.swift` | **KEEP** | Per-category default logging fields are correct; only needs warmup/set-type support when LOG-07 lands. |
| `Features/Workout/ProgressionBanner.swift` | **REFACTOR** | Reason text + PR toast work (PROG-03 partial); restyle to the new design system and add the missing accept/edit/ignore flow + tap-to-expand. |
| `Features/Workout/LiveActivityManager.swift` | **KEEP (carefully)** | Real, working ActivityKit driver (LOCK-01/02/04 done). Fragile (fire-and-forget Tasks) — treat with care; no rewrite warranted. |
| `Features/Home`,`Programs`,`Progress`,`Profile` empty/Form states | (see below) | — |
| `Features/Programs/ProgramsView.swift` | **REFACTOR + EXPAND** | List + start flow OK; replace the bare "Free limit reached / OK" alert with a paywall trigger (US-112) and add goal-based browse (PRG-01). |
| `Features/Programs/ProgramDetailView.swift` | **REPLACE (Form) + EXPAND** | Start-program (PRG-03) is the most complete piece — keep it; the embedded `ProgramEditorView` is a stub (no day→routine assignment, PRG-04) and the stock `Form` clashes with card screens; needs metadata fields (level/days-week/equipment/description, PRG-02) and fork support (PRG-06). |
| `Features/Programs/RoutineEditorView.swift` | **REFACTOR (restyle)** | Routine builder logic is genuinely done (PRG-05); only the stock `Form` look needs replacing with the DFCard/section system. |
| `Features/Progress/ProgressTabView.swift` | **REFACTOR + EXPAND** | History/PR/heatmap exist (AN-01 done) but `dataPoints`/`volumeByMuscle` run FetchDescriptors + O(n) aggregation in computed view props (perf + layering risk) — move to a service/precompute; warmup sets aren't excluded; add calendar (AN-06), category filter, reps/volume/e1RM charting (AN-02/04), and wire export to a paywall not a disabled button. |
| `Features/Profile/ProfileView.swift` | **REPLACE (Form) + REFACTOR** | Settings are correct & persisted (US-110/031 done); the stock `Form` should be restyled, and account-deletion currently only signs out + wipes local (US-010 not truly met — needs remote delete). |
| `Features/Profile/PaywallView.swift` | **REFACTOR + EXPAND** | Functional RevenueCat purchase/restore in isolation; must be wired to trigger at every limit point with context-relevant benefits (US-112), add 7-day trial + manage-subscription link (US-111). |
| `Features/Onboarding/OnboardingView.swift` | **EXPAND** | 3-screen stub; training-type selection is captured but never persisted/used (dead state). Add the suggested-program picker + Lock-Screen opt-in screens and actually persist/personalize (US-030). |
| `Features/Exercises/ExercisePickerView.swift` | **KEEP + EXPAND** | Combinable name/muscle/equipment search + filters work (LIB-03 mostly done); add an equipment filter chip and reuse for a standalone Library browse screen. |
| `Features/Exercises/CustomExerciseEditorView.swift` | **REPLACE (Form) + REFACTOR** | Create path works (LIB-04 partial) but news up its own `ExerciseRepository()` instead of using the injected one, uses stock `Form`, and has no edit/delete UI (US-022). |
| *(missing)* Exercise Detail view (US-023) | **EXPAND (new)** | No detail screen exists at all — net-new work, not a rewrite. |

---

## Domain/

| File | Disposition | Reason |
|------|-------------|--------|
| `Domain/Models/DomainTypes.swift` | **KEEP** | Pure `Sendable`/`Equatable` value types — clean domain boundary; only add enum cases as features land (e.g. deload action). |
| `Domain/Progression/ProgressionEngine.swift` | **KEEP (design) + REFACTOR (bug)** | High-value pure, unit-tested strength engine behind `ProgressionEngineProtocol` — exactly what to preserve. Fix the RIR operator-precedence bug (line 71: `targets.min + targets.max / 2 + 2` parses as `min + (max/2) + 2`, making predictedMax unreachable) and add the deload branch (PROG-04). |
| `Domain/Services/ProgressionService.swift` | **REFACTOR** | Correct orchestration but: hardcodes `RepRange(8,12)` instead of reading routine targets (PROG-01), news up its own `UserPreferencesRepository()` bypassing DI, never reads `progressionEnabled` (PROG-05), and includes warmup sets in history. |
| `Domain/Services/PRDetector.swift` | **KEEP + EXPAND** | Solid pure PR/e1RM math; emit the defined-but-unused `sessionVolume` PR (AN-03) and surface e1RM (AN-04). |
| `Domain/Services/PRService.swift` | **KEEP** | Clean `recordIfPR`/`recentPRs`; wired correctly through the workout loop. |
| `Domain/Services/ProgramScheduleResolver.swift` | **KEEP** | Pure, unit-tested "today's session" resolver; no changes needed. |
| `Domain/Services/ContentLimitService.swift` | **KEEP + REFACTOR** | Centralized, testable free/Pro gating (good pattern); reconcile limit *values* with PRD §13 (5 combined vs 5+5; invented 20-exercise cap; 7d-vs-30d window). |
| `Domain/WorkoutSessionCoordinator.swift` | **KEEP + REFACTOR** | See workout section — preserve the coordinator role; fix `updatedAt` bumping and swallowed saves. |

---

## Data/

| File | Disposition | Reason |
|------|-------------|--------|
| `Data/Persistence/SwiftDataModels.swift` | **KEEP** | High-value asset: `@Attribute(.unique)` ids, proper `.cascade` `@Relationship` chains, consistent enum↔rawValue bridging, centralized schema. Add only the missing fields (program description/level/days-week/equipment) as features need them. |
| `Data/Repositories/ExerciseRepository.swift` | **KEEP + EXPAND** | `createCustom`/`customExerciseCount` are fine; add edit/delete and ensure all callers use the injected instance (LIB-04). |
| `Data/Repositories/UserPreferencesRepository.swift` | **REFACTOR** | Correct shape; stop swallowing saves with `try?` and ensure it's always the injected instance. |
| `Data/Sync/SyncEngine.swift` | **REFACTOR (heavy) — highest-risk file** | Offline-first *design* is right and worth keeping (per-row `SyncStatus`, op queue, `NWPathMonitor` flush, `isFlushing` guard), but it has real data-loss bugs to fix in place: delete hard-coded to `workout_sessions` regardless of entity (line ~327), no conflict resolution (`.conflict` never set/read), unreliable `updatedAt` cursor, child rows pushed as full blobs, `ProgramDay` never pushed, restore pulls only sessions (≤100), and the queue is in-memory only (lost on cold start, LOG-11). Harden behind the existing seams — do **not** replace. |
| `Data/Persistence/ExerciseSeeder.swift` | **KEEP** | Batch loader works correctly; the gap is the dataset size, not the seeder. |
| `Data/Persistence/ProgramSeeder.swift` | **KEEP** | Seeding machinery is fine; expand the JSON catalog, not this code. |
| `Data/Persistence/RoutineSeeder.swift` | **KEEP** | Same — mechanically sound. |

---

## Services/

| File | Disposition | Reason |
|------|-------------|--------|
| `Services/AuthService.swift` | **KEEP + REFACTOR** | Real Sign in with Apple → Supabase flow with `nonisolated` delegate hops (hard problem, solved — preserve). Refactor: stop reconstructing `SupabaseClient` on every property access; make deletion delete *remote* data (US-010). |
| `Services/RevenueCatService.swift` | **KEEP + EXPAND** | Configure/purchase/restore/entitlements work; add 7-day trial handling + manage-subscription link (US-111). |
| `Services/WorkoutExportService.swift` | **EXPAND** | CSV writer works and escapes; add the required `set_type` and `notes` columns (US-012). |

---

## Shared/ (App-Group + Live Activity bridge)

| File | Disposition | Reason |
|------|-------------|--------|
| `Shared/WorkoutIntentBridge.swift` | **REFACTOR (one-line build fix)** | **The build blocker:** `darwinNotificationName` is declared `CFString` (line 11) but passed to `CFNotificationCenterPostNotification` which wants `CFNotificationName` (line 17). One-token cast (`as CFNotificationName`) unblocks the WorkoutLiveActivityExtension target. |
| `Shared/WorkoutIntentObserver.swift` | **KEEP (carefully)** | Works but fragile (raw `CFNotificationCenter` + `Unmanaged.passUnretained`); concurrency hotspot — preserve, refactor only with care. |
| `Shared/WorkoutSessionState.swift` | **KEEP** | Cross-process state model for the Live Activity; sound. |
| `Shared/AppGroup.swift` | **KEEP** | Thin App-Group defaults accessor; fine as-is. |

---

## Resources/

| File | Disposition | Reason |
|------|-------------|--------|
| `Resources/Assets.xcassets/*.colorset` (Background/Primary/Accent/Surface/SecondaryText) | **KEEP + REFACTOR** | The Calm Strength palette is correctly defined (light+dark) — the design weakness is the SwiftUI layer, not the palette. One fix: `Accent.colorset` lacks a dark-appearance variant (the others have one) — add it. |
| `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | **REPLACE** | Empty 177-byte placeholder, no image — ship a real abstract (non-barbell) app icon per PRD §6. |
| `Resources/Exercises/exercises.json` (+ manifest) | **EXPAND** | 149 of ≥2,000 exercises (<8% of LIB-01), all with `imageURL=null` (LIB-05). The single biggest content gap — scale via the existing import pipeline; add media. |
| `Resources/Programs/programs.json` | **EXPAND** | 3 of 11+ programs (PRG-07); no yoga/flexibility/hybrid. Fill the catalog — the loader already works. |
| *(missing)* iconography / hero imagery assets | **EXPAND (new)** | 0 image assets, 0 gradients (PRD §6 demands abstract flow/balance marks + soft natural imagery) — net-new design assets. |

---

## WorkoutLiveActivityExtension/

| File | Disposition | Reason |
|------|-------------|--------|
| `WorkoutLiveActivityExtension/WorkoutLiveActivityBundle.swift` | **KEEP + EXPAND** | Genuine Live Activity (lock screen + Dynamic Island, LOCK-01/02/04 done) — preserve. Add the missing End-workout button (`EndWorkoutIntent` is defined but never placed in the UI, LOCK-05) and a calm rest-timer ring. |
| `WorkoutLiveActivityExtension/WorkoutLiveActivityIntents.swift` | **KEEP** | `CompleteSet`/`ExtendRest`/`EndWorkout` intents are defined correctly; `EndWorkout` just needs to be surfaced (above). |

---

## supabase/

| File | Disposition | Reason |
|------|-------------|--------|
| `supabase/migrations/20260627000000_initial_schema.sql` | **KEEP + EXPAND** | RLS-backed schema is real and backs cloud backup; add tables/columns as SyncEngine fixes land (e.g. program-day push, restore of sets/routines/programs/custom exercises). |
| `supabase/migrations/20260628000000_personal_records.sql` | **KEEP** | PR table migration is sound; no rework needed. |

---

## Config/ (note, not a code module)

`Config/Secrets.xcconfig` is **missing** (only `Secrets.example.xcconfig` exists); `Debug.xcconfig`
& `Release.xcconfig` `#include` it, so the project will not build until it's created (gitignored).
This is **config setup**, not a code disposition — create it from the example before building.

---

## Cross-cutting reworks (not file-scoped)

- **Error handling posture:** 15 `try? context.save()` sites swallow persistence failures with no
  logging or user surface (esp. the live-workout path) — REFACTOR across the affected files.
- **DI consistency:** several hot paths (`ProgressionService`, `CustomExerciseEditorView`) new up
  repositories instead of using injected ones — REFACTOR to use the container's instances.
- **Strict concurrency:** no strict-concurrency flag is set, so the uniform `@MainActor` discipline
  is convention-only — turn on strict checking early to prevent drift (risk mitigation).
- **Business logic in views:** `HomeView.startRoutine` and `ProgressTabView` aggregation should
  move into services/coordinators — REFACTOR for layering + performance.
