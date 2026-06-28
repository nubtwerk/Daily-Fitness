import Foundation
import SwiftData

@MainActor
final class ExerciseSeeder {
    private let seededKey = "exercisesSeeded"

    func seedIfNeeded(context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<ExerciseEntity>())
        if existingCount > 0 {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        guard let url = locateExercisesJSON() else {
            print("ExerciseSeeder: exercises.json not found in app bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ExerciseSeedFile.self, from: data)

        for item in payload.exercises {
            let entity = ExerciseEntity(
                id: item.id,
                name: item.name,
                category: item.category,
                primaryMuscles: item.primaryMuscles,
                equipment: item.equipment,
                imageURL: item.imageURL,
                isCustom: false,
                loggingFields: item.loggingFields
            )
            context.insert(entity)
        }

        try context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
        print("ExerciseSeeder: inserted \(payload.exercises.count) exercises")
    }

    private func locateExercisesJSON() -> URL? {
        if let url = Bundle.main.url(forResource: "exercises", withExtension: "json") {
            return url
        }
        return Bundle.main.url(forResource: "exercises", withExtension: "json", subdirectory: "Exercises")
    }
}

private struct ExerciseSeedFile: Decodable {
    let exercises: [ExerciseSeedItem]
}

private struct ExerciseSeedItem: Decodable {
    let id: UUID
    let name: String
    let category: ExerciseCategory
    let primaryMuscles: [String]
    let equipment: [String]
    let imageURL: String?
    let loggingFields: LoggingFieldMask
}
