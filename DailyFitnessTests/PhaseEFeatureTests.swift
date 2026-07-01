import XCTest
@testable import DailyFitness

final class ContentLimitServiceTests: XCTestCase {
    func testCustomContentIsCombinedCapOfFive() {
        // PRD §13: 5 programs + routines COMBINED, not 5 of each.
        XCTAssertTrue(ContentLimitService.canCreateCustomContent(routineCount: 2, programCount: 2, isPro: false))  // 4 < 5
        XCTAssertFalse(ContentLimitService.canCreateCustomContent(routineCount: 3, programCount: 2, isPro: false)) // 5, at cap
        XCTAssertFalse(ContentLimitService.canCreateCustomContent(routineCount: 5, programCount: 0, isPro: false)) // routines alone hit it
        XCTAssertFalse(ContentLimitService.canCreateCustomContent(routineCount: 0, programCount: 5, isPro: false)) // programs alone hit it
    }

    func testProUsersAreUncapped() {
        XCTAssertTrue(ContentLimitService.canCreateCustomContent(routineCount: 50, programCount: 50, isPro: true))
        XCTAssertTrue(ContentLimitService.canShowProgression(forStrengthIndex: 99, isPro: true))
    }

    func testProgressionFreeAllowanceIsFirstTwoExercises() {
        XCTAssertTrue(ContentLimitService.canShowProgression(forStrengthIndex: 0, isPro: false))
        XCTAssertTrue(ContentLimitService.canShowProgression(forStrengthIndex: 1, isPro: false))
        XCTAssertFalse(ContentLimitService.canShowProgression(forStrengthIndex: 2, isPro: false))
    }
}

final class PaywallContextTests: XCTestCase {
    /// Every context that highlights a feature must highlight one that actually exists in the
    /// comparison table — otherwise the highlight silently does nothing.
    func testHighlightedFeaturesExistInComparisonTable() {
        let titles = Set(ProFeature.all.map(\.title))
        for context in PaywallContext.allCases {
            if let highlight = context.highlightedFeature {
                XCTAssertTrue(titles.contains(highlight), "\(context) highlights '\(highlight)' with no matching ProFeature row")
            }
        }
    }

    func testEveryContextHasNonEmptyCopy() {
        for context in PaywallContext.allCases {
            XCTAssertFalse(context.headline.isEmpty)
            XCTAssertFalse(context.subheadline.isEmpty)
        }
    }
}

final class WorkoutExportServiceTests: XCTestCase {
    func testCSVHeaderIncludesSetTypeAndNotes() {
        let userId = UUID()
        let exercise = ExerciseEntity(name: "Bench Press", category: .strength)
        let session = WorkoutSessionEntity(userId: userId, name: "Push Day")
        let workoutExercise = WorkoutExerciseEntity(exerciseId: exercise.id, sortOrder: 0)
        workoutExercise.note = "felt strong"
        let set = WorkoutSetEntity(setNumber: 1, setType: .warmup)
        set.weightKg = 60
        set.reps = 5
        set.isCompleted = true
        workoutExercise.sets = [set]
        session.exercises = [workoutExercise]

        guard let url = WorkoutExportService.exportCSV(sessions: [session], exercises: [exercise], userId: userId) else {
            return XCTFail("Expected a CSV file URL")
        }
        let csv = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let lines = csv.split(separator: "\n").map(String.init)

        XCTAssertEqual(
            lines.first,
            "session_id,session_name,started_at,exercise,set_number,set_type,weight_kg,reps,duration_seconds,hold_seconds,notes"
        )
        XCTAssertTrue(csv.contains("warmup"), "set_type should be exported")
        XCTAssertTrue(csv.contains("felt strong"), "exercise note should be exported")
        XCTAssertTrue(csv.contains("Bench Press"))
    }

    func testCSVExcludesOtherUsersAndIncompleteSets() {
        let userId = UUID()
        let otherUserId = UUID()
        let exercise = ExerciseEntity(name: "Squat", category: .strength)

        let mine = WorkoutSessionEntity(userId: userId, name: "Legs")
        let myExercise = WorkoutExerciseEntity(exerciseId: exercise.id, sortOrder: 0)
        let doneSet = WorkoutSetEntity(setNumber: 1)
        doneSet.weightKg = 100; doneSet.reps = 5; doneSet.isCompleted = true
        let pendingSet = WorkoutSetEntity(setNumber: 2)
        pendingSet.isCompleted = false
        myExercise.sets = [doneSet, pendingSet]
        mine.exercises = [myExercise]

        let theirs = WorkoutSessionEntity(userId: otherUserId, name: "Not Mine")

        guard let url = WorkoutExportService.exportCSV(sessions: [mine, theirs], exercises: [exercise], userId: userId) else {
            return XCTFail("Expected a CSV file URL")
        }
        let csv = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let dataRows = csv.split(separator: "\n").dropFirst()

        XCTAssertEqual(dataRows.count, 1, "Only the one completed set from my session should be exported")
        XCTAssertFalse(csv.contains("Not Mine"))
    }
}
