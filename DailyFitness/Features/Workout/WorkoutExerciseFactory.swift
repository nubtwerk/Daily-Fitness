import Foundation
import SwiftData

enum WorkoutExerciseFactory {
    @MainActor
    static func addExercise(
        _ exercise: ExerciseEntity,
        to session: WorkoutSessionEntity,
        in context: ModelContext,
        setCount: Int = 3
    ) -> WorkoutExerciseEntity {
        addExercise(
            exerciseId: exercise.id,
            loggingFields: exercise.loggingFields,
            to: session,
            in: context,
            setCount: setCount
        )
    }

    @MainActor
    static func addFromRoutineExercise(
        _ routineExercise: RoutineExerciseEntity,
        to session: WorkoutSessionEntity,
        in context: ModelContext,
        category: ExerciseCategory,
        loggingFields: LoggingFieldMask = .weightReps
    ) -> WorkoutExerciseEntity {
        let workoutExercise = addExercise(
            exerciseId: routineExercise.exerciseId,
            loggingFields: loggingFields,
            to: session,
            in: context,
            setCount: routineExercise.targetSets
        )
        // Carry routine configuration into the live session (LOG-08/09, US-041/042/053).
        workoutExercise.supersetGroupId = routineExercise.supersetGroupId
        workoutExercise.note = routineExercise.note
        // Only strength rests by default; mobility/yoga must be explicitly configured
        // (US-053), so non-strength exercises start with no rest override.
        workoutExercise.restSecondsOverride = category == .strength ? routineExercise.restSeconds : nil
        return workoutExercise
    }

    @MainActor
    static func addExercise(
        exerciseId: UUID,
        loggingFields: LoggingFieldMask,
        to session: WorkoutSessionEntity,
        in context: ModelContext,
        setCount: Int
    ) -> WorkoutExerciseEntity {
        let sortOrder = (session.exercises.map(\.sortOrder).max() ?? -1) + 1
        let workoutExercise = WorkoutExerciseEntity(
            exerciseId: exerciseId,
            sortOrder: sortOrder
        )

        for index in 0..<setCount {
            let set = WorkoutSetEntity(setNumber: index + 1)
            applyDefaults(to: set, loggingFields: loggingFields)
            context.insert(set)
            workoutExercise.sets.append(set)
        }

        context.insert(workoutExercise)
        session.exercises.append(workoutExercise)
        return workoutExercise
    }

    private static func applyDefaults(to set: WorkoutSetEntity, loggingFields: LoggingFieldMask) {
        switch loggingFields {
        case .weightReps:
            break
        case .duration:
            set.durationSeconds = 60
        case .hold, .side:
            set.holdSeconds = 30
            if loggingFields == .side {
                set.side = .both
            }
        }
    }
}
