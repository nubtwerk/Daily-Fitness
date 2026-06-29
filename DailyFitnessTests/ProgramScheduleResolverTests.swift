import XCTest
@testable import DailyFitness

final class ProgramScheduleResolverTests: XCTestCase {
    func testFindsTodaysProgramDay() {
        let program = ProgramEntity(name: "Test", category: .strength)
        let day = ProgramDayEntity(weekIndex: 0, dayOfWeek: 2, routineId: UUID(), sortOrder: 0)
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
        program.days = [ProgramDayEntity(weekIndex: 0, dayOfWeek: 1, routineId: UUID(), sortOrder: 0)]

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        let saturday = Calendar.current.date(from: components)!

        XCTAssertNil(ProgramScheduleResolver.todaysProgramDay(for: program, on: saturday))
    }
}
