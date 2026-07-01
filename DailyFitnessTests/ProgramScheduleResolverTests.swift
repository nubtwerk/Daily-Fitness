import XCTest
@testable import DailyFitness

final class ProgramScheduleResolverTests: XCTestCase {
    // `ProgramDayEntity.dayOfWeek` follows Calendar's weekday convention (Sunday = 1 … Saturday = 7),
    // which is what the resolver compares against and what the seed data uses (e.g. the 3×/week
    // program schedules days 2/4/6 = Mon/Wed/Fri).

    func testFindsTodaysProgramDay() {
        let program = ProgramEntity(name: "Test", category: .strength)
        let day = ProgramDayEntity(weekIndex: 0, dayOfWeek: 3, routineId: UUID(), sortOrder: 0) // Tuesday
        program.days = [day]

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 30
        let tuesday = Calendar.current.date(from: components)! // 2026-06-30 is a Tuesday

        let result = ProgramScheduleResolver.todaysProgramDay(for: program, on: tuesday)
        XCTAssertEqual(result?.id, day.id)
    }

    func testReturnsNilWhenNoMatchingDay() {
        let program = ProgramEntity(name: "Test", category: .strength)
        program.days = [ProgramDayEntity(weekIndex: 0, dayOfWeek: 7, routineId: UUID(), sortOrder: 0)] // Saturday

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        let sunday = Calendar.current.date(from: components)! // 2026-06-28 is a Sunday

        XCTAssertNil(ProgramScheduleResolver.todaysProgramDay(for: program, on: sunday))
    }
}
