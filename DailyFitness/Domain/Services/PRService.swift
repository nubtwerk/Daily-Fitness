import Foundation
import SwiftData

@MainActor
final class PRService {
    func recordIfPR(
        set: CompletedWorkingSet,
        exerciseId: UUID,
        sessionId: UUID,
        setId: UUID,
        userId: UUID,
        context: ModelContext
    ) -> [PersonalRecord] {
        let (bestWeight, bestReps, bestE1RM) = fetchPreviousBests(exerciseId: exerciseId, userId: userId, context: context)
        let detected = PRDetector.detect(
            set: set,
            exerciseId: exerciseId,
            previousBestWeight: bestWeight,
            previousBestReps: bestReps,
            previousBestE1RM: bestE1RM
        )

        for pr in detected {
            let entity = PersonalRecordEntity(
                id: pr.id,
                userId: userId,
                exerciseId: exerciseId,
                type: pr.type,
                value: pr.value,
                achievedAt: pr.achievedAt,
                sessionId: sessionId,
                setId: setId
            )
            context.insert(entity)
        }
        if !detected.isEmpty {
            context.saveOrLog("recordIfPR")
        }
        return detected
    }

    /// Detects and records a session-volume PR (AN-03; US-091). Volume counts completed,
    /// non-warmup working sets across the session. Returns the PR if one was set.
    @discardableResult
    func recordSessionVolumePR(
        session: WorkoutSessionEntity,
        userId: UUID,
        context: ModelContext
    ) -> PersonalRecord? {
        let volume = sessionWorkingVolume(session)
        let previousBest = fetchBestSessionVolume(userId: userId, context: context)
        guard let pr = PRDetector.detectSessionVolume(
            volume: volume,
            previousBest: previousBest,
            at: session.endedAt ?? Date()
        ) else { return nil }

        let entity = PersonalRecordEntity(
            id: pr.id,
            userId: userId,
            exerciseId: pr.exerciseId,
            type: .sessionVolume,
            value: pr.value,
            achievedAt: pr.achievedAt,
            sessionId: session.id,
            setId: PRDetector.sessionWideId
        )
        context.insert(entity)
        context.saveOrLog("recordSessionVolumePR")
        return pr
    }

    private func sessionWorkingVolume(_ session: WorkoutSessionEntity) -> Double {
        var total = 0.0
        for workoutExercise in session.exercises {
            for set in workoutExercise.sets where set.isCompleted && set.setType != .warmup {
                if let weight = set.weightKg, let reps = set.reps, weight > 0, reps > 0 {
                    total += weight * Double(reps)
                }
            }
        }
        return total
    }

    private func fetchBestSessionVolume(userId: UUID, context: ModelContext) -> Double? {
        let volumeRaw = PersonalRecordType.sessionVolume.rawValue
        let descriptor = FetchDescriptor<PersonalRecordEntity>(
            predicate: #Predicate { $0.userId == userId && $0.typeRaw == volumeRaw }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map(\.value).max()
    }

    func records(forSession sessionId: UUID, context: ModelContext) -> [PersonalRecordEntity] {
        let descriptor = FetchDescriptor<PersonalRecordEntity>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func recentPRs(userId: UUID, limit: Int, context: ModelContext) -> [PersonalRecordEntity] {
        var descriptor = FetchDescriptor<PersonalRecordEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchPreviousBests(
        exerciseId: UUID,
        userId: UUID,
        context: ModelContext
    ) -> (Double?, Int?, Double?) {
        let descriptor = FetchDescriptor<PersonalRecordEntity>(
            predicate: #Predicate { $0.userId == userId && $0.exerciseId == exerciseId }
        )
        let records = (try? context.fetch(descriptor)) ?? []

        let bestWeight = records.filter { $0.type == .weight }.map(\.value).max()
        let bestReps = records.filter { $0.type == .reps }.map(\.value).map(Int.init).max()
        let bestE1RM = records.filter { $0.type == .estimated1RM }.map(\.value).max()
        return (bestWeight, bestReps, bestE1RM)
    }
}
