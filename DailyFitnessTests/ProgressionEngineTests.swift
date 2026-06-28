import XCTest
@testable import DailyFitness

final class ProgressionEngineTests: XCTestCase {
    let engine = ProgressionEngine()

    func testFirstSessionReturnsHoldWithTargets() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5
        ))

        XCTAssertEqual(output.action, .hold)
        XCTAssertEqual(output.targetRepsMin, 8)
        XCTAssertEqual(output.targetRepsMax, 12)
    }

    func testHittingRepMaxIncreasesWeight() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 12, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5
        ))

        XCTAssertEqual(output.action, .increase)
        XCTAssertEqual(output.targetWeightKg, 82.5)
    }

    func testBelowMinRepsDecreasesWeight() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 100, reps: 5, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5
        ))

        XCTAssertEqual(output.action, .decrease)
        XCTAssertEqual(output.targetWeightKg!, 95, accuracy: 0.01)
    }
}

final class PRDetectorTests: XCTestCase {
    func testDetectsWeightPR() {
        let set = CompletedWorkingSet(weightKg: 100, reps: 5, rir: nil, completedAt: Date())
        let records = PRDetector.detect(
            set: set,
            exerciseId: UUID(),
            previousBestWeight: 90,
            previousBestReps: 10,
            previousBestE1RM: 110
        )

        XCTAssertTrue(records.contains { $0.type == .weight && $0.value == 100 })
    }
}

final class WeightFormatterTests: XCTestCase {
    func testKgDisplay() {
        XCTAssertEqual(WeightFormatter.display(kg: 80, usePounds: false), "80.0 kg")
    }

    func testLbDisplay() {
        let result = WeightFormatter.display(kg: 80, usePounds: true)
        XCTAssertTrue(result.contains("lb"))
    }
}
