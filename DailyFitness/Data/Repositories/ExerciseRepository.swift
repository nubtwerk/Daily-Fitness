import Foundation
import SwiftData

@MainActor
final class ExerciseRepository {
    func customExerciseCount(userId: UUID, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.isCustom == true && $0.userId == userId && $0.deletedAt == nil }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func createCustom(
        name: String,
        category: ExerciseCategory,
        primaryMuscles: [String],
        equipment: [String],
        loggingFields: LoggingFieldMask,
        userId: UUID,
        context: ModelContext
    ) throws -> ExerciseEntity {
        let entity = ExerciseEntity(
            name: name,
            category: category,
            primaryMuscles: primaryMuscles,
            equipment: equipment,
            isCustom: true,
            userId: userId,
            loggingFields: loggingFields
        )
        context.insert(entity)
        try context.save()
        return entity
    }

    func softDelete(_ exercise: ExerciseEntity, context: ModelContext) throws {
        exercise.deletedAt = Date()
        exercise.updatedAt = Date()
        try context.save()
    }
}
