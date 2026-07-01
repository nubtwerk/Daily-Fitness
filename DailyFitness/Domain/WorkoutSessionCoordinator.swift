import Foundation
import SwiftData

@MainActor
final class WorkoutSessionCoordinator {
    let syncEngine: SyncEngine
    let prService: PRService
    let progressionService: ProgressionService
    let preferencesRepository: UserPreferencesRepository
    let errorPresenter: ErrorPresenter

    /// Outcome of completing a single set: any new PRs plus the rest deadline the
    /// UI should display (nil when no rest applies).
    struct CompleteSetResult {
        var personalRecords: [PersonalRecord]
        var restEndsAt: Date?
    }

    init(
        syncEngine: SyncEngine,
        prService: PRService,
        progressionService: ProgressionService,
        preferencesRepository: UserPreferencesRepository,
        errorPresenter: ErrorPresenter
    ) {
        self.syncEngine = syncEngine
        self.prService = prService
        self.progressionService = progressionService
        self.preferencesRepository = preferencesRepository
        self.errorPresenter = errorPresenter
    }

    func completeSet(
        _ set: WorkoutSetEntity,
        workoutExercise: WorkoutExerciseEntity,
        session: WorkoutSessionEntity,
        exercise: ExerciseEntity?,
        userId: UUID,
        context: ModelContext
    ) -> CompleteSetResult {
        guard !set.isCompleted else { return CompleteSetResult(personalRecords: [], restEndsAt: nil) }

        set.isCompleted = true
        set.completedAt = Date()

        // One-tap confirm: fill unchanged values from the last working set (US-051).
        if exercise?.loggingFields == .weightReps || exercise == nil {
            let last = LastWorkingSetService.lastPerformance(
                exerciseId: workoutExercise.exerciseId,
                userId: userId,
                excludingSessionId: session.id,
                context: context
            )
            if set.weightKg == nil { set.weightKg = last?.weightKg ?? 0 }
            if set.reps == nil { set.reps = last?.reps ?? 0 }
        }

        session.syncStatus = .pending
        session.updatedAt = Date()
        context.saveOrPresent(
            "completeSet",
            presenter: errorPresenter,
            title: "Couldn’t save your set",
            message: "Your last set may not have been saved. Check your device storage and try logging it again."
        )

        // Warmups never count as PRs (LOG-07 / US-054).
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
        let restSeconds = restSecondsFor(exercise: exercise, workoutExercise: workoutExercise, prefs: prefs)
        let restEndsAt = restSeconds > 0 ? Date().addingTimeInterval(TimeInterval(restSeconds)) : nil

        if prefs.liveActivitiesEnabled {
            LiveActivityManager.shared.update(
                session: session,
                exerciseLookup: { id in exerciseName(for: id, context: context) },
                phase: restSeconds > 0 ? .resting : .active,
                restEndsAt: restEndsAt
            )
        }

        // Rest-end notification fallback (LOCK-06 / US-063).
        if prefs.restEndNotificationEnabled, let restEndsAt {
            NotificationService.shared.scheduleRestEnd(at: restEndsAt)
        } else {
            NotificationService.shared.cancelRestEnd()
        }

        return CompleteSetResult(personalRecords: newPRs, restEndsAt: restEndsAt)
    }

    /// Default rest for a strength set is the per-exercise override or the user's
    /// global default. Mobility/yoga only rests when explicitly configured (US-053).
    private func restSecondsFor(
        exercise: ExerciseEntity?,
        workoutExercise: WorkoutExerciseEntity,
        prefs: UserPreferencesEntity
    ) -> Int {
        if exercise?.category == .strength {
            return workoutExercise.restSecondsOverride ?? prefs.defaultRestSeconds
        }
        return workoutExercise.restSecondsOverride ?? 0
    }

    /// Re-sync the rest state after the user extends or skips rest in-app.
    func syncRest(
        session: WorkoutSessionEntity,
        restEndsAt: Date?,
        userId: UUID,
        context: ModelContext
    ) {
        let prefs = preferencesRepository.loadOrCreate(userId: userId, context: context)
        let resting = (restEndsAt != nil)

        if prefs.liveActivitiesEnabled {
            LiveActivityManager.shared.update(
                session: session,
                exerciseLookup: { id in exerciseName(for: id, context: context) },
                phase: resting ? .resting : .active,
                restEndsAt: restEndsAt
            )
        }

        if prefs.restEndNotificationEnabled, let restEndsAt {
            NotificationService.shared.scheduleRestEnd(at: restEndsAt)
        } else {
            NotificationService.shared.cancelRestEnd()
        }
    }

    func finishSession(
        _ session: WorkoutSessionEntity,
        userId: UUID,
        isPro: Bool,
        context: ModelContext
    ) {
        session.endedAt = Date()
        session.syncStatus = .pending
        session.updatedAt = Date()
        context.saveOrPresent(
            "finishSession",
            presenter: errorPresenter,
            title: "Couldn’t save your workout",
            message: "We hit a problem saving this workout. Check your device storage; your logged sets are still here, so try finishing again."
        )

        prService.recordSessionVolumePR(session: session, userId: userId, context: context)
        // Persist per-exercise notes back to the routine so they pre-fill next time (US-042).
        persistExerciseNotesToRoutine(session: session, context: context)

        progressionService.recomputeAfterSession(session: session, userId: userId, isPro: isPro, context: context)
        syncEngine.enqueue(.upsertSession(session.id))
        NotificationService.shared.cancelRestEnd()
        LiveActivityManager.shared.end()
    }

    func discardSession(_ session: WorkoutSessionEntity, context: ModelContext) {
        let sessionId = session.id

        // PRs are standalone rows keyed by sessionId (no cascade relationship), so
        // delete them explicitly or they'd poison future PR baselines.
        let prDescriptor = FetchDescriptor<PersonalRecordEntity>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        for pr in (try? context.fetch(prDescriptor)) ?? [] {
            context.delete(pr)
        }

        // If any set was flushed mid-session, the session already exists on the
        // server — cancel its pending upserts and queue a server soft-delete (routed to the
        // sessions table) so it isn't resurrected on the next pull.
        syncEngine.cancelPendingSession(id: sessionId)
        syncEngine.enqueue(.deleteEntity(.session, sessionId))

        context.delete(session)
        context.saveOrPresent(
            "discardSession",
            presenter: errorPresenter,
            title: "Couldn’t discard the workout",
            message: "We couldn’t fully remove this workout. It may reappear until you try again."
        )
        NotificationService.shared.cancelRestEnd()
        LiveActivityManager.shared.end()
    }

    private func persistExerciseNotesToRoutine(session: WorkoutSessionEntity, context: ModelContext) {
        guard let routineId = session.routineId else { return }
        let descriptor = FetchDescriptor<RoutineEntity>(predicate: #Predicate { $0.id == routineId })
        guard let routine = try? context.fetch(descriptor).first else { return }
        var changed = false
        for workoutExercise in session.exercises {
            guard let routineExercise = routine.exercises.first(where: { $0.exerciseId == workoutExercise.exerciseId }) else { continue }
            // Mirror the live note onto the routine, including clearing it (US-042).
            let liveNote = workoutExercise.note?.isEmpty == true ? nil : workoutExercise.note
            if routineExercise.note != liveNote {
                routineExercise.note = liveNote
                changed = true
            }
        }
        if changed {
            routine.updatedAt = Date()
            routine.syncStatus = .pending
            syncEngine.enqueue(.upsertRoutine(routine.id))
            context.saveOrLog("persistExerciseNotesToRoutine")
        }
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
