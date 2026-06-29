import Foundation
import SwiftData

@Observable
@MainActor
final class SeedingState {
    var isSeeding = false
    var message = ""
}

@MainActor
final class ExerciseSeeder {
    private let versionKey = "exerciseSeedVersion"
    private let batchSize = 500

    func seedIfNeeded(context: ModelContext, state: SeedingState? = nil) throws {
        let manifest = loadManifest()
        let targetVersion = manifest?.version ?? 1
        let currentVersion = UserDefaults.standard.integer(forKey: versionKey)

        if currentVersion >= targetVersion {
            return
        }

        guard let url = locateExercisesJSON() else {
            print("ExerciseSeeder: exercises.json not found in app bundle")
            return
        }

        state?.isSeeding = true
        state?.message = "Loading exercise library…"
        defer {
            state?.isSeeding = false
            state?.message = ""
        }

        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ExerciseSeedFile.self, from: data)

        let existingIds = Set(
            try context.fetch(FetchDescriptor<ExerciseEntity>())
                .filter { !$0.isCustom }
                .map(\.id)
        )

        var inserted = 0
        var batchCount = 0

        for item in payload.exercises {
            if existingIds.contains(item.id) { continue }
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
            inserted += 1
            batchCount += 1

            if batchCount >= batchSize {
                try context.save()
                batchCount = 0
                state?.message = "Loaded \(inserted) exercises…"
            }
        }

        if batchCount > 0 || currentVersion == 0 {
            try context.save()
        }

        UserDefaults.standard.set(targetVersion, forKey: versionKey)
        print("ExerciseSeeder: upserted \(inserted) exercises (version \(targetVersion))")
    }

    func needsSeeding() -> Bool {
        let manifest = loadManifest()
        let targetVersion = manifest?.version ?? 1
        let currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        return currentVersion < targetVersion
    }

    private func loadManifest() -> ExerciseManifest? {
        guard let url = Bundle.main.url(forResource: "exercises-manifest", withExtension: "json")
            ?? Bundle.main.url(forResource: "exercises-manifest", withExtension: "json", subdirectory: "Exercises")
        else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ExerciseManifest.self, from: data)
    }

    private func locateExercisesJSON() -> URL? {
        Bundle.main.url(forResource: "exercises", withExtension: "json")
            ?? Bundle.main.url(forResource: "exercises", withExtension: "json", subdirectory: "Exercises")
    }
}

private struct ExerciseManifest: Decodable {
    let version: Int
    let count: Int
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
