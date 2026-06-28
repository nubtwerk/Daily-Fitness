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
            to: session,
            in: context,
            setCount: setCount
        )
    }

    @MainActor
    static func addFromRoutineExercise(
        _ routineExercise: RoutineExerciseEntity,
        to session: WorkoutSessionEntity,
        in context: ModelContext
    ) -> WorkoutExerciseEntity {
        addExercise(
            exerciseId: routineExercise.exerciseId,
            to: session,
            in: context,
            setCount: routineExercise.targetSets
        )
    }

    @MainActor
    static func addExercise(
        exerciseId: UUID,
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
            context.insert(set)
            workoutExercise.sets.append(set)
        }

        context.insert(workoutExercise)
        session.exercises.append(workoutExercise)
        return workoutExercise
    }
}
