import Foundation
import SwiftData

@MainActor
final class ProgramSeeder {
    private let versionKey = "programSeedVersion"

    func seedIfNeeded(context: ModelContext, routines: [RoutineEntity]) throws {
        let targetVersion = 2
        let currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        if currentVersion >= targetVersion { return }

        guard let url = locateProgramsJSON() else {
            print("ProgramSeeder: programs.json not found")
            return
        }

        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ProgramSeedFile.self, from: data)

        let existingIds = Set(try context.fetch(FetchDescriptor<ProgramEntity>()).map(\.id))

        for item in payload.programs {
            if existingIds.contains(item.id) { continue }
            let program = ProgramEntity(
                id: item.id,
                name: item.name,
                category: item.category,
                isSuggested: true,
                weeks: item.weeks,
                programDescription: item.description,
                level: item.level.flatMap { ProgramLevel(rawValue: $0) },
                daysPerWeek: item.daysPerWeek,
                equipment: item.equipment ?? []
            )
            for day in item.days {
                let routineId = day.routineName.flatMap { name in
                    routines.first(where: { $0.name == name })?.id
                }
                let dayEntity = ProgramDayEntity(
                    id: day.id,
                    weekIndex: day.weekIndex,
                    dayOfWeek: day.dayOfWeek,
                    routineId: routineId,
                    sortOrder: day.sortOrder
                )
                context.insert(dayEntity)
                program.days.append(dayEntity)
            }
            context.insert(program)
        }

        try context.save()
        UserDefaults.standard.set(targetVersion, forKey: versionKey)
    }

    private func locateProgramsJSON() -> URL? {
        Bundle.main.url(forResource: "programs", withExtension: "json")
            ?? Bundle.main.url(forResource: "programs", withExtension: "json", subdirectory: "Programs")
    }
}

private struct ProgramSeedFile: Decodable {
    let programs: [ProgramSeedItem]
}

private struct ProgramSeedItem: Decodable {
    let id: UUID
    let name: String
    let category: ProgramCategory
    let weeks: Int?
    let description: String?
    let level: String?
    let daysPerWeek: Int?
    let equipment: [String]?
    let days: [ProgramDaySeedItem]
}

private struct ProgramDaySeedItem: Decodable {
    let id: UUID
    let weekIndex: Int
    let dayOfWeek: Int
    let routineName: String?
    let sortOrder: Int
}
