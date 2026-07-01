# Changelog

All notable changes to DailyFitness are documented here.

## [0.3.0] - 2026-07-01

### Phase F — Ship-readiness (US-120, US-122, PRD §15)

Hardening pass on top of Phases A–D to make the app TestFlight-ready.

**F1 — Error-handling posture**
- No more silent persistence failures: replaced every swallowed `try? context.save()` (25 sites) with
  `ModelContext.saveOrLog` / `saveOrPresent`. Live-workout and user-authored saves surface a calm alert via
  a new `@Observable ErrorPresenter` (mounted at the app root **and** inside the live-workout
  `fullScreenCover`); derived/background saves log via a new `os.Logger` wrapper (`AppLog`). `print`
  diagnostics replaced with structured logging. Account deletion now reports a partial wipe.
- Enabled `SWIFT_STRICT_CONCURRENCY = complete` and fixed what it surfaced (AppIntents `static let title`;
  `@unchecked Sendable` on the stateless MetricKit subscriber). Residual warnings are SwiftData
  predicate-keypath noise only.

**F2 — Accessibility (US-122)**
- WCAG-AA contrast: darkened `SecondaryText` (light) to 4.95:1 on Background; added an `AccentForeground`
  token (5.4–6.0:1) for foreground sage glyphs (rest-timer arc, completed-set check), keeping decorative
  `Accent` fills unchanged. Verified against Background, Surface, and SurfaceElevated.
- VoiceOver: rest-timer ring announces remaining seconds as one element; weight/reps fields carry labels +
  spoken values ("empty" when blank); PRs earn a spoken announcement matching the toast.
- Dynamic Type: set-row entry fields scale with text size instead of clipping.

**F3 — Design assets**
- The calm rest-timer ring and abstract flow/balance mark already shipped in Phase A/D; this phase polished
  the ring for AA contrast + VoiceOver rather than duplicating them.

**F4 — TestFlight / QA (US-120)**
- Feedback channel in Profile (pre-filled mailto with app + OS version).
- Dependency-free MetricKit `CrashDiagnosticsService` for crash/hang visibility.
- `ExportOptions.plist` + `docs/TESTFLIGHT.md` (submission runbook + on-device QA checklist). The physical
  device-QA gate is handed off there.

## [0.2.0] - 2026-06-30

### Phase B — Core logging loop (LOG-01..11, LOCK-01..06)

**Fast logging**
- Haptic feedback on set complete (`.sensoryFeedback`) with a spring row-fill animation.
- Previous performance shown as ghost placeholders and a "Last time: 80 kg × 8" / "Last: 45s hold" label (`LastWorkingSetService`, warmups and the current session excluded).
- Non-destructive prefill: a one-tap complete fills unchanged weight/reps from the last working set instead of overwriting with zeros.

**Set types, supersets, notes**
- Per-row set-type picker (normal / warm-up / failure / drop set).
- Warm-up sets excluded from volume totals, progression math, and PR detection (`WorkoutMetrics`).
- Supersets: pair 2–4 adjacent exercises (reorder-safe), grouped visually in the routine editor and live workout, with set-cycling across the group.
- Session note and per-exercise note editors; routine note + superset group synced.

**Rest timer and summary**
- Skip and +30s rest controls; per-exercise rest override (strength only — mobility/yoga rests only when configured).
- End-of-workout summary: duration, exercises, working-set count, volume / total time, PR highlights, and a note before save.

**Lock Screen & Live Activities**
- End-workout button on the Lock Screen and Dynamic Island, alongside complete-set and the rest countdown.
- One-time permission explainer before the first Live Activity.
- Rest-end local notification fallback (`NotificationService`) when Live Activities are off.
- `widgetURL` deep link opens the app to the current set.

**Offline durability**
- The sync operation queue is persisted and pending entities are re-enqueued at launch.

### Fixed
- Live Activity extension `Info.plist` was missing its `NSExtension` dictionary, which prevented the app (with the embedded extension) from installing on a device or simulator.
- Discarding a workout now deletes its personal records and queues a server delete, so PR baselines aren't corrupted and the session isn't resurrected on sync.
- Routine-started mobility/yoga exercises no longer auto-start a rest timer.
