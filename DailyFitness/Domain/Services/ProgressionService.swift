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

    func prefillSessionFromRecommendations(
        session: WorkoutSessionEntity,
        userId: UUID,
        isPro: Bool,
        context: ModelContext
    ) {
        let prefs = UserPreferencesRepository().loadOrCreate(userId: userId, context: context)
        var strengthIndex = 0

        for workoutExercise in session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let exercise = fetchExercise(id: workoutExercise.exerciseId, context: context),
                  exercise.category == .strength else { continue }

            if !isPro && strengthIndex >= 2 { break }
            strengthIndex += 1

            guard let rec = latestRecommendation(exerciseId: exercise.id, userId: userId, context: context),
                  let targetWeight = rec.targetWeightKg else { continue }

            for set in workoutExercise.sets where !set.isCompleted {
                set.weightKg = targetWeight
            }
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
        var strengthIndex = 0

        for workoutExercise in session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let exercise = fetchExercise(id: workoutExercise.exerciseId, context: context),
                  exercise.category == .strength else { continue }

            if !isPro && strengthIndex >= 2 { continue }
            strengthIndex += 1

            let history = buildHistory(exerciseId: exercise.id, userId: userId, context: context)
            let targets = RepRange(min: 8, max: 12)
            let input = ProgressionInput(
                exerciseId: exercise.id,
                history: history,
                targets: targets,
                rirEnabled: prefs.rirEnabled,
                incrementKg: incrementKg
            )
            let output = engine.recommend(input: input)

            let existing = latestRecommendation(exerciseId: exercise.id, userId: userId, context: context)
            if let existing {
                context.delete(existing)
            }

            let rec = ProgressionRecommendationEntity(
                userId: userId,
                exerciseId: exercise.id,
                output: output
            )
            context.insert(rec)
        }
        try? context.save()
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

        var history: [CompletedWorkingSet] = []
        for session in sessions {
            for workoutExercise in session.exercises where workoutExercise.exerciseId == exerciseId {
                for set in workoutExercise.sets where set.isCompleted {
                    guard let weight = set.weightKg, let reps = set.reps, weight > 0, reps > 0 else { continue }
                    history.append(CompletedWorkingSet(
                        weightKg: weight,
                        reps: reps,
                        rir: set.rir,
                        completedAt: set.completedAt ?? session.startedAt
                    ))
                }
            }
            if history.count >= 3 { break }
        }
        return history.reversed()
    }

    private func fetchExercise(id: UUID, context: ModelContext) -> ExerciseEntity? {
        let descriptor = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
