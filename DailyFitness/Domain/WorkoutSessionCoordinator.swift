import Foundation
import SwiftData

@MainActor
final class WorkoutSessionCoordinator {
    let syncEngine: SyncEngine
    let prService: PRService
    let progressionService: ProgressionService
    let preferencesRepository: UserPreferencesRepository

    init(
        syncEngine: SyncEngine,
        prService: PRService,
        progressionService: ProgressionService,
        preferencesRepository: UserPreferencesRepository
    ) {
        self.syncEngine = syncEngine
        self.prService = prService
        self.progressionService = progressionService
        self.preferencesRepository = preferencesRepository
    }

    func completeSet(
        _ set: WorkoutSetEntity,
        workoutExercise: WorkoutExerciseEntity,
        session: WorkoutSessionEntity,
        exercise: ExerciseEntity?,
        userId: UUID,
        context: ModelContext
    ) -> [PersonalRecord] {
        guard !set.isCompleted else { return [] }

        set.isCompleted = true
        set.completedAt = Date()

        if exercise?.loggingFields == .weightReps || exercise == nil {
            if set.weightKg == nil { set.weightKg = 0 }
            if set.reps == nil { set.reps = 0 }
        }

        session.syncStatus = .pending
        try? context.save()

        var newPRs: [PersonalRecord] = []
        if exercise?.category == .strength,
           set.setType != .warmup,
           let weight = set.weightKg,
           let reps = set.reps,
           weight > 0, reps > 0 {
            newPRs = prService.recordIfPR(
                set: CompletedWorkingSet(weightKg: weight, reps: reps, rir: set.rir, completedAt: set.completedAt ?? Date()),
                exerciseId: workoutExercise.exerciseId,
                sessionId: session.id,
                setId: set.id,
                userId: userId,
                context: context
            )
        }

        syncEngine.enqueue(.upsertSession(session.id))

        let prefs = preferencesRepository.loadOrCreate(userId: userId, context: context)
        let restSeconds = exercise?.category == .strength ? prefs.defaultRestSeconds : 0
        let restEndsAt = restSeconds > 0 ? Date().addingTimeInterval(TimeInterval(restSeconds)) : nil

        if prefs.liveActivitiesEnabled {
            LiveActivityManager.shared.update(
                session: session,
                exerciseLookup: { id in exerciseName(for: id, context: context) },
                phase: restSeconds > 0 ? .resting : .active,
                restEndsAt: restEndsAt
            )
        }

        return newPRs
    }

    func finishSession(
        _ session: WorkoutSessionEntity,
        userId: UUID,
        isPro: Bool,
        context: ModelContext
    ) {
        session.endedAt = Date()
        session.syncStatus = .pending
        try? context.save()

        prService.recordSessionVolumePR(session: session, userId: userId, context: context)
        progressionService.recomputeAfterSession(session: session, userId: userId, isPro: isPro, context: context)
        syncEngine.enqueue(.upsertSession(session.id))
        LiveActivityManager.shared.end()
    }

    func discardSession(_ session: WorkoutSessionEntity, context: ModelContext) {
        context.delete(session)
        try? context.save()
        LiveActivityManager.shared.end()
    }

    func startLiveActivityIfEnabled(
        session: WorkoutSessionEntity,
        userId: UUID,
        context: ModelContext
    ) {
        let prefs = preferencesRepository.loadOrCreate(userId: userId, context: context)
        guard prefs.liveActivitiesEnabled else { return }

        let sorted = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
        guard let first = sorted.first else { return }
        let sets = first.sets.sorted(by: { $0.setNumber < $1.setNumber })
        let name = exerciseName(for: first.exerciseId, context: context)

        LiveActivityManager.shared.start(
            sessionName: session.name,
            sessionId: session.id,
            exerciseName: name,
            setCurrent: 1,
            setTotal: max(sets.count, 1)
        )
        let completed = sets.filter(\.isCompleted).count
        WorkoutSessionState.save(snapshot: WorkoutSessionState.Snapshot(
            sessionId: session.id,
            workoutName: session.name,
            exerciseName: name,
            setCurrent: min(completed + 1, max(sets.count, 1)),
            setTotal: max(sets.count, 1),
            phase: .active,
            restEndsAt: nil
        ))
    }

    private func exerciseName(for id: UUID, context: ModelContext) -> String {
        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first?.name) ?? "Exercise"
    }
}
