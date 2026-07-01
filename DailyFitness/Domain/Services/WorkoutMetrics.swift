import Foundation

/// Volume / time aggregation that consistently excludes warmup sets from
/// strength volume (LOG-07 / US-054). Used by the progress heatmap and the
/// end-of-workout summary so the two never disagree.
enum WorkoutMetrics {
    /// A completed set that should count toward strength volume — working sets only.
    static func countsTowardVolume(_ set: WorkoutSetEntity) -> Bool {
        set.isCompleted && set.setType != .warmup
    }

    /// Strength volume (kg) for one logged exercise, warmups excluded.
    static func strengthVolume(for workoutExercise: WorkoutExerciseEntity) -> Double {
        workoutExercise.sets.reduce(0) { partial, set in
            guard countsTowardVolume(set) else { return partial }
            return partial + (set.weightKg ?? 0) * Double(set.reps ?? 0)
        }
    }

    /// Total strength volume (kg) across a whole session, warmups excluded.
    static func totalStrengthVolume(for session: WorkoutSessionEntity) -> Double {
        session.exercises.reduce(0) { $0 + strengthVolume(for: $1) }
    }

    /// Total logged time (seconds) for duration/hold work in a session — counts
    /// completed sets of every type (mobility/yoga has no warmup distinction).
    static func totalTimedSeconds(for session: WorkoutSessionEntity) -> Int {
        session.exercises.reduce(0) { partial, workoutExercise in
            partial + workoutExercise.sets.reduce(0) { inner, set in
                guard set.isCompleted else { return inner }
                return inner + (set.durationSeconds ?? 0) + (set.holdSeconds ?? 0)
            }
        }
    }

    /// Count of exercises with at least one completed set.
    static func completedExerciseCount(for session: WorkoutSessionEntity) -> Int {
        session.exercises.filter { $0.sets.contains(where: \.isCompleted) }.count
    }

    /// Count of completed working sets (warmups excluded) across the session.
    static func completedWorkingSetCount(for session: WorkoutSessionEntity) -> Int {
        session.exercises.reduce(0) { $0 + $1.sets.filter(countsTowardVolume).count }
    }
}
