import Foundation
import SwiftData

@MainActor
final class RoutineSeeder {
    private let versionKey = "routineSeedVersion"

    func seedSuggestedIfNeeded(context: ModelContext, exercises: [ExerciseEntity]) throws {
        let targetVersion = 1
        guard UserDefaults.standard.integer(forKey: versionKey) < targetVersion else { return }

        let existing = try context.fetch(FetchDescriptor<RoutineEntity>())
        guard existing.isEmpty else {
            UserDefaults.standard.set(targetVersion, forKey: versionKey)
            return
        }

        let templates: [(String, [(String, Int, Int, Int)])] = [
            ("Full Body A", [
                ("Barbell Back Squat", 3, 8, 12),
                ("Barbell Bench Press", 3, 8, 12),
                ("Barbell Row", 3, 8, 12)
            ]),
            ("Full Body B", [
                ("Romanian Deadlift", 3, 8, 12),
                ("Overhead Press", 3, 8, 12),
                ("Pull-Up", 3, 6, 10)
            ]),
            ("Mobility Flow", [
                ("90/90 Hip Switch", 2, 60, 60),
                ("World's Greatest Stretch", 2, 60, 60),
                ("Cat-Cow", 2, 60, 60)
            ])
        ]

        for (index, template) in templates.enumerated() {
            let routine = RoutineEntity(userId: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, name: template.0)
            routine.syncStatus = .synced

            for (sortOrder, item) in template.1.enumerated() {
                guard let exercise = exercises.first(where: { $0.name == item.0 }) else { continue }
                let isStrength = exercise.category == .strength
                let routineExercise = RoutineExerciseEntity(
                    sortOrder: sortOrder,
                    exerciseId: exercise.id,
                    targetSets: item.1,
                    targetRepsMin: isStrength ? item.2 : nil,
                    targetRepsMax: isStrength ? item.3 : nil,
                    targetDurationSeconds: isStrength ? nil : item.2,
                    restSeconds: isStrength ? 90 : 30
                )
                context.insert(routineExercise)
                routine.exercises.append(routineExercise)
            }

            context.insert(routine)
            if index == 0 { _ = routine.id }
        }

        try context.save()
        UserDefaults.standard.set(targetVersion, forKey: versionKey)
    }
}
