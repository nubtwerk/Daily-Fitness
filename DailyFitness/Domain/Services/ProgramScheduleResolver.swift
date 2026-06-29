import Foundation

enum ProgramScheduleResolver {
    static func todaysProgramDay(for program: ProgramEntity, on date: Date = Date()) -> ProgramDayEntity? {
        let weekday = Calendar.current.component(.weekday, from: date)
        return program.days
            .filter { $0.dayOfWeek == weekday }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .first
    }

    static func routineForToday(
        program: ProgramEntity,
        routines: [RoutineEntity],
        on date: Date = Date()
    ) -> (ProgramDayEntity, RoutineEntity)? {
        guard let day = todaysProgramDay(for: program, on: date),
              let routineId = day.routineId,
              let routine = routines.first(where: { $0.id == routineId }) else {
            return nil
        }
        return (day, routine)
    }
}
