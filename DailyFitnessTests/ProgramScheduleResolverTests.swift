import XCTest
@testable import DailyFitness

final class ProgramScheduleResolverTests: XCTestCase {
    func testFindsTodaysProgramDay() {
        let program = ProgramEntity(name: "Test", category: .strength)
        // dayOfWeek follows Calendar.weekday (Sunday = 1), matching the seeded
        // programs.json and the schedule display. June 30 2026 is a Tuesday = 3.
        let day = ProgramDayEntity(weekIndex: 0, dayOfWeek: 3, routineId: UUID(), sortOrder: 0)
        program.days = [day]

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 30
        let tuesday = Calendar.current.date(from: components)!

        let result = ProgramScheduleResolver.todaysProgramDay(for: program, on: tuesday)
        XCTAssertEqual(result?.id, day.id)
    }

    func testReturnsNilWhenNoMatchingDay() {
        let program = ProgramEntity(name: "Test", category: .strength)
        // Program runs on Sundays (dayOfWeek 1, Calendar.weekday convention).
        program.days = [ProgramDayEntity(weekIndex: 0, dayOfWeek: 1, routineId: UUID(), sortOrder: 0)]

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 27 // June 27 2026 is a Saturday — no scheduled day.
        let saturday = Calendar.current.date(from: components)!

        XCTAssertNil(ProgramScheduleResolver.todaysProgramDay(for: program, on: saturday))
    }
}
