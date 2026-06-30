import Foundation
import SwiftData

/// Previous-performance lookup for fast logging (LOG-06 / US-051 / US-052).
///
/// Resolves the most recent *working* set (warmups excluded) an athlete logged
/// for a given exercise in a prior, completed session. Used to render ghost
/// placeholders ("Last time: 80kg × 8" / "Last: 45s hold") and to fill in
/// unchanged values on a one-tap set complete.
enum LastWorkingSetService {
    struct Performance: Equatable {
        var weightKg: Double?
        var reps: Int?
        var durationSeconds: Int?
        var holdSeconds: Int?
        var side: BodySide?
        var date: Date
    }

    /// Most recent completed working set for `exerciseId` from a prior session.
    /// Excludes the in-progress session (`excludingSessionId`) and warmup sets.
    @MainActor
    static func lastPerformance(
        exerciseId: UUID,
        userId: UUID,
        excludingSessionId: UUID? = nil,
        context: ModelContext
    ) -> Performance? {
        var descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        // Ghost text is a convenience hint — bound the scan to recent sessions
        // rather than the entire history on every card render.
        descriptor.fetchLimit = 40
        let sessions = (try? context.fetch(descriptor)) ?? []

        for session in sessions {
            if let excludingSessionId, session.id == excludingSessionId { continue }
            for workoutExercise in session.exercises where workoutExercise.exerciseId == exerciseId {
                let working = workoutExercise.sets
                    .filter { $0.isCompleted && $0.setType != .warmup }
                    .sorted(by: { $0.setNumber < $1.setNumber })
                guard let last = working.last else { continue }
                return Performance(
                    weightKg: last.weightKg,
                    reps: last.reps,
                    durationSeconds: last.durationSeconds,
                    holdSeconds: last.holdSeconds,
                    side: last.side,
                    date: last.completedAt ?? session.startedAt
                )
            }
        }
        return nil
    }
}

extension LastWorkingSetService.Performance {
    /// Short human label for the exercise card, e.g. "Last time: 80kg × 8" or "Last: 45s hold".
    func summary(loggingFields: LoggingFieldMask, usePounds: Bool) -> String? {
        switch loggingFields {
        case .weightReps:
            guard let reps else { return nil }
            if let weightKg {
                return "Last time: \(WeightFormatter.display(kg: weightKg, usePounds: usePounds)) × \(reps)"
            }
            return "Last time: \(reps) reps"
        case .duration:
            guard let durationSeconds else { return nil }
            return "Last: \(durationSeconds)s"
        case .hold, .side:
            guard let holdSeconds else { return nil }
            if let side, loggingFields == .side, side != .both {
                return "Last: \(holdSeconds)s hold (\(side.rawValue))"
            }
            return "Last: \(holdSeconds)s hold"
        }
    }
}
