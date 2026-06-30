import Foundation
import SwiftData

@MainActor
final class ProgressionService {
    let engine: ProgressionEngineProtocol
    private let incrementKg = 2.5

    init(engine: ProgressionEngineProtocol) {
        self.engine = engine
    }

    func latestRecommendation(
        exerciseId: UUID,
        userId: UUID,
        context: ModelContext
    ) -> ProgressionRecommendationEntity? {
        let descriptor = FetchDescriptor<ProgressionRecommendationEntity>(
            predicate: #Predicate { $0.userId == userId && $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    /// Applies a recommendation's suggested weight to the remaining (incomplete) sets of an
    /// exercise. Called only when the user explicitly accepts the banner — never silently
    /// (US-080: accept / edit / ignore).
    func applyRecommendation(
        _ recommendation: ProgressionRecommendationEntity,
        to workoutExercise: WorkoutExerciseEntity,
        context: ModelContext
    ) {
        guard let targetWeight = recommendation.targetWeightKg else { return }
        for set in workoutExercise.sets where !set.isCompleted {
            set.weightKg = targetWeight
        }
        try? context.save()
    }

    func recomputeAfterSession(
        session: WorkoutSessionEntity,
        userId: UUID,
        isPro: Bool,
        context: ModelContext
    ) {
        let prefs = UserPreferencesRepository().loadOrCreate(userId: userId, context: context)
        let routine = session.routineId.flatMap { fetchRoutine(id: $0, context: context) }
        var strengthIndex = 0

        for workoutExercise in session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let exercise = fetchExercise(id: workoutExercise.exerciseId, context: context),
                  exercise.category == .strength else { continue }

            let currentIndex = strengthIndex
            strengthIndex += 1

            let routineExercise = routine?.exercises.first(where: { $0.exerciseId == exercise.id })
            let existing = latestRecommendation(exerciseId: exercise.id, userId: userId, context: context)

            // PROG-05: per-exercise progression toggle — remove any stale recommendation.
            if let routineExercise, !routineExercise.progressionEnabled {
                if let existing { context.delete(existing) }
                continue
            }

            // PROG-06: free tier previews progression for the first 2 strength exercises only.
            guard ContentLimitService.canShowProgression(forStrengthIndex: currentIndex, isPro: isPro) else {
                continue
            }

            let targets = repRange(for: routineExercise)
            // US-083: reset the stall streak when the user changes the routine's rep targets.
            let targetsChanged = existing.map {
                $0.targetRepsMin != targets.min || $0.targetRepsMax != targets.max
            } ?? false

            let history = buildHistory(exerciseId: exercise.id, userId: userId, context: context)
            let input = ProgressionInput(
                exerciseId: exercise.id,
                history: history,
                targets: targets,
                rirEnabled: prefs.rirEnabled,
                incrementKg: incrementKg,
                failedAttempts: existing?.failedAttempts ?? 0,
                targetsChanged: targetsChanged
            )
            let output = engine.recommend(input: input)

            if let existing { context.delete(existing) }
            let rec = ProgressionRecommendationEntity(
                userId: userId,
                exerciseId: exercise.id,
                output: output,
                routineExerciseId: routineExercise?.id
            )
            context.insert(rec)
        }
        try? context.save()
    }

    /// The routine's rep targets for an exercise, falling back to a sensible 8–12 default
    /// for blank sessions or exercises without explicit targets (PROG-01).
    private func repRange(for routineExercise: RoutineExerciseEntity?) -> RepRange {
        guard let routineExercise,
              let lo = routineExercise.targetRepsMin,
              let hi = routineExercise.targetRepsMax,
              lo > 0, hi >= lo else {
            return RepRange(min: 8, max: 12)
        }
        return RepRange(min: lo, max: hi)
    }

    private func buildHistory(
        exerciseId: UUID,
        userId: UUID,
        context: ModelContext
    ) -> [CompletedWorkingSet] {
        let sessionDescriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []

        // Collect recent completed working sets (warmups never drive progression — PRD §12),
        // each tagged with a deterministic timestamp + setNumber so the ordering does not
        // depend on SwiftData's (unordered) relationship iteration.
        var candidates: [(date: Date, setNumber: Int, set: CompletedWorkingSet)] = []
        for session in sessions {
            for workoutExercise in session.exercises where workoutExercise.exerciseId == exerciseId {
                for set in workoutExercise.sets where set.isCompleted && set.setType != .warmup {
                    guard let weight = set.weightKg, let reps = set.reps, weight > 0, reps > 0 else { continue }
                    let date = set.completedAt ?? session.startedAt
                    candidates.append((
                        date,
                        set.setNumber,
                        CompletedWorkingSet(weightKg: weight, reps: reps, rir: set.rir, completedAt: date)
                    ))
                }
            }
            // Sessions are newest-first; a few recent data points are enough to pin the latest set.
            if candidates.count >= 6 { break }
        }

        // Chronological order so the engine's `history.last` is the genuine last completed
        // working set (PRD §12 — "last completed working set"); setNumber breaks ties.
        let ordered = candidates.sorted {
            $0.date != $1.date ? $0.date < $1.date : $0.setNumber < $1.setNumber
        }
        return ordered.suffix(3).map(\.set)
    }

    private func fetchExercise(id: UUID, context: ModelContext) -> ExerciseEntity? {
        let descriptor = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchRoutine(id: UUID, context: ModelContext) -> RoutineEntity? {
        let descriptor = FetchDescriptor<RoutineEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
