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
            try? context.save()
        }
        return detected
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
