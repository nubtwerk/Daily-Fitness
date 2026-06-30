# Changelog

All notable changes to DailyFitness are documented here.

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
