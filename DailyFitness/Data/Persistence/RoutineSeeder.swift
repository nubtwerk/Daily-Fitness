import Foundation
import SwiftData

@MainActor
final class RoutineSeeder {
    private let versionKey = "routineSeedVersion"
    private let seedUserId = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    /// (sets, a, b): strength uses a=minReps, b=maxReps; other categories use a=durationSeconds.
    typealias Item = (String, Int, Int, Int)

    func seedSuggestedIfNeeded(context: ModelContext, exercises: [ExerciseEntity]) throws {
        let targetVersion = 2
        guard UserDefaults.standard.integer(forKey: versionKey) < targetVersion else { return }

        let existingNames = Set(try context.fetch(FetchDescriptor<RoutineEntity>()).map(\.name))
        let exercisesByName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        for (name, items) in Self.templates {
            guard !existingNames.contains(name) else { continue }
            let routine = RoutineEntity(userId: seedUserId, name: name, isSuggested: true)
            routine.syncStatus = .synced

            for (sortOrder, item) in items.enumerated() {
                guard let exercise = exercisesByName[item.0] else { continue }
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

            // Skip routines whose exercises all failed to resolve.
            guard !routine.exercises.isEmpty else { continue }
            context.insert(routine)
        }

        try context.save()
        UserDefaults.standard.set(targetVersion, forKey: versionKey)
    }

    // Routine names here are referenced by Resources/Programs/programs.json. Every
    // exercise name is verified present in the seeded library.
    static let templates: [(String, [Item])] = [
        // --- Strength ---
        ("Full Body A", [
            ("Barbell Back Squat", 3, 8, 12), ("Barbell Bench Press", 3, 8, 12),
            ("Seated Cable Row", 3, 8, 12), ("Plank", 3, 45, 45)
        ]),
        ("Full Body B", [
            ("Romanian Deadlift", 3, 8, 12), ("Barbell Overhead Press", 3, 8, 12),
            ("Pull-Up", 3, 6, 10), ("Hanging Leg Raise", 3, 10, 15)
        ]),
        ("Upper Body A", [
            ("Barbell Bench Press", 4, 6, 10), ("Underhand Barbell Bent-Over Row", 4, 6, 10),
            ("Barbell Overhead Press", 3, 8, 12), ("Lat Pulldown", 3, 10, 12),
            ("Dumbbell Bicep Curl", 3, 10, 15), ("Triceps Pushdown", 3, 10, 15)
        ]),
        ("Lower Body A", [
            ("Barbell Back Squat", 4, 6, 10), ("Romanian Deadlift", 3, 8, 12),
            ("Leg Press", 3, 10, 15), ("Seated Leg Curl", 3, 10, 15),
            ("Standing Calf Raise", 4, 12, 20)
        ]),
        ("Upper Body B", [
            ("Incline Dumbbell Bench Press", 4, 8, 12), ("Seated Cable Row", 4, 8, 12),
            ("Seated Dumbbell Overhead Press", 3, 8, 12), ("Chin-Up", 3, 6, 10),
            ("Dumbbell Hammer Curl", 3, 10, 15), ("Triceps Pushdown", 3, 10, 15)
        ]),
        ("Lower Body B", [
            ("Barbell Front Squat", 4, 6, 10), ("Barbell Deadlift", 3, 5, 8),
            ("Bulgarian Split Squat", 3, 10, 12), ("Standing Calf Raise", 4, 12, 20),
            ("Hanging Leg Raise", 3, 10, 15)
        ]),
        ("Push Day", [
            ("Barbell Bench Press", 4, 6, 10), ("Barbell Overhead Press", 3, 8, 12),
            ("Incline Dumbbell Bench Press", 3, 8, 12), ("Dumbbell Lateral Raise", 3, 12, 20),
            ("Triceps Pushdown", 3, 10, 15)
        ]),
        ("Pull Day", [
            ("Pull-Up", 4, 6, 10), ("Seated Cable Row", 4, 8, 12),
            ("Lat Pulldown", 3, 10, 12), ("Face Pull", 3, 12, 20),
            ("Dumbbell Bicep Curl", 3, 10, 15)
        ]),
        ("Leg Day", [
            ("Barbell Back Squat", 4, 6, 10), ("Romanian Deadlift", 3, 8, 12),
            ("Leg Press", 3, 10, 15), ("Seated Leg Curl", 3, 10, 15),
            ("Standing Calf Raise", 4, 12, 20)
        ]),
        ("Beginner Full Body A", [
            ("Leg Press", 3, 10, 12), ("Barbell Bench Press", 3, 8, 10),
            ("Lat Pulldown", 3, 10, 12), ("Plank", 3, 30, 30)
        ]),
        ("Beginner Full Body B", [
            ("Barbell Back Squat", 3, 8, 10), ("Seated Dumbbell Overhead Press", 3, 8, 12),
            ("Seated Cable Row", 3, 10, 12), ("Standing Calf Raise", 3, 12, 15)
        ]),

        // --- Mobility / flexibility ---
        ("Daily Mobility Flow", [
            ("Cat-Cow", 1, 60, 0), ("World's Greatest Stretch", 1, 60, 0),
            ("90/90 Hip Switch", 1, 60, 0), ("Hip Circles", 1, 45, 0),
            ("Thoracic Rotation", 1, 45, 0), ("Bird Dog", 1, 45, 0),
            ("Ankle Dorsiflexion Rock", 1, 45, 0), ("Inchworm", 1, 45, 0)
        ]),
        ("Post-Lift Stretch", [
            ("Standing Hamstring Stretch", 1, 45, 0), ("Couch Stretch", 1, 45, 0),
            ("Figure-Four Glute Stretch", 1, 45, 0), ("Doorway Chest Stretch", 1, 45, 0),
            ("Cross-Body Shoulder Stretch", 1, 30, 0), ("Child's Pose", 1, 60, 0)
        ]),
        ("Hip & Ankle Opener", [
            ("90/90 Hip Switch", 2, 45, 0), ("Cossack Squat", 2, 45, 0),
            ("Deep Squat Hold", 1, 60, 0), ("Ankle Dorsiflexion Rock", 2, 45, 0),
            ("Ankle CARs", 1, 45, 0), ("Frog Pose", 1, 60, 0), ("Hip Circles", 1, 45, 0)
        ]),
        ("Shoulder Recovery", [
            ("Shoulder CARs", 2, 45, 0), ("Wall Slides", 2, 45, 0),
            ("Band Pull-Apart", 2, 45, 0), ("Cross-Body Shoulder Stretch", 1, 30, 0),
            ("Doorway Chest Stretch", 1, 45, 0), ("Sleeper Stretch", 1, 30, 0)
        ]),

        // --- Yoga ---
        ("Morning Yoga Flow", [
            ("Mountain Pose", 1, 30, 0), ("Downward-Facing Dog", 1, 45, 0),
            ("Warrior I", 1, 45, 0), ("Warrior II", 1, 45, 0),
            ("Tree Pose", 1, 30, 0), ("Cobra Pose", 1, 30, 0), ("Child's Pose", 1, 60, 0)
        ]),
        ("Recovery Yoga", [
            ("Child's Pose", 1, 60, 0), ("Pigeon Pose", 1, 60, 0),
            ("Bridge Pose", 1, 45, 0), ("Cat-Cow", 1, 45, 0),
            ("Reclined Butterfly Stretch", 1, 60, 0), ("Corpse Pose", 1, 120, 0)
        ]),
    ]
}
