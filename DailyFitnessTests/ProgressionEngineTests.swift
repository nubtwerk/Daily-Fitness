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

    // MARK: - RIR branch (PROG-02; US-082)

    /// Regression test for the precedence bug: predictedMax = (8 + 12) / 2 + 2 = 12.
    /// effectiveMax = 10 reps + 2 RIR = 12 ≥ 12 → increase. The old `min + max/2 + 2`
    /// (= 16) would have wrongly held here.
    func testRIRExceedingTargetIncreasesWeight() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 10, rir: 2, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: true,
            incrementKg: 2.5
        ))

        XCTAssertEqual(output.action, .increase)
        XCTAssertEqual(output.targetWeightKg!, 82.5, accuracy: 0.01)
        XCTAssertEqual(output.targetRir, 2)
    }

    func testRIRBelowTargetHolds() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 8, rir: 2, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: true,
            incrementKg: 2.5
        ))

        XCTAssertEqual(output.action, .hold)
        XCTAssertEqual(output.targetWeightKg!, 80, accuracy: 0.01)
    }

    /// RIR enabled but not logged on the latest set → falls back to the rep-range model.
    func testRIREnabledButMissingFallsBackToReps() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 12, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: true,
            incrementKg: 2.5
        ))

        XCTAssertEqual(output.action, .increase)
        XCTAssertEqual(output.targetWeightKg!, 82.5, accuracy: 0.01)
    }

    // MARK: - Deload + stall streak (PROG-04; US-083)

    func testStallIncrementsFailedAttempts() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 10, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5,
            failedAttempts: 0
        ))

        XCTAssertEqual(output.action, .hold)
        XCTAssertEqual(output.failedAttempts, 1)
    }

    func testThreeStallsTriggersDeload() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 10, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5,
            failedAttempts: 2
        ))

        XCTAssertEqual(output.action, .deload)
        XCTAssertEqual(output.targetWeightKg!, 72, accuracy: 0.01) // 80 * 0.9
        XCTAssertEqual(output.failedAttempts, 0) // streak resets after a deload
    }

    func testIncreaseResetsFailedAttempts() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 12, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5,
            failedAttempts: 2
        ))

        XCTAssertEqual(output.action, .increase)
        XCTAssertEqual(output.failedAttempts, 0)
    }

    func testChangingTargetsResetsStreakAndAvoidsDeload() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 10, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5,
            failedAttempts: 5,
            targetsChanged: true
        ))

        XCTAssertEqual(output.action, .hold) // not deload — streak was reset
        XCTAssertEqual(output.failedAttempts, 1)
    }

    /// Pins the deload boundary: a SECOND stall must hold (streak 2), not deload at 3-threshold.
    func testTwoStallsHoldWithoutDeload() {
        let output = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [
                CompletedWorkingSet(weightKg: 80, reps: 10, rir: nil, completedAt: Date())
            ],
            targets: RepRange(min: 8, max: 12),
            rirEnabled: false,
            incrementKg: 2.5,
            failedAttempts: 1
        ))

        XCTAssertEqual(output.action, .hold)
        XCTAssertEqual(output.failedAttempts, 2)
    }

    /// Proves targets are read from the routine (not hardcoded): with RepRange(5,8),
    /// predictedMax = (5+8)/2 + 2 = 8, so 6 reps + 2 RIR increases but 5 + 2 holds —
    /// both would behave differently if predictedMax were hardcoded to the old 8–12 value.
    func testRIRTargetsAreReadNotHardcoded() {
        let increase = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [CompletedWorkingSet(weightKg: 60, reps: 6, rir: 2, completedAt: Date())],
            targets: RepRange(min: 5, max: 8),
            rirEnabled: true,
            incrementKg: 2.5
        ))
        XCTAssertEqual(increase.action, .increase)
        XCTAssertEqual(increase.targetRepsMin, 5)
        XCTAssertEqual(increase.targetRepsMax, 8)

        let hold = engine.recommend(input: ProgressionInput(
            exerciseId: UUID(),
            history: [CompletedWorkingSet(weightKg: 60, reps: 5, rir: 2, completedAt: Date())],
            targets: RepRange(min: 5, max: 8),
            rirEnabled: true,
            incrementKg: 2.5
        ))
        XCTAssertEqual(hold.action, .hold)
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

    func testDetectsSessionVolumePR() {
        let pr = PRDetector.detectSessionVolume(volume: 5000, previousBest: 4000, at: Date())
        XCTAssertEqual(pr?.type, .sessionVolume)
        XCTAssertEqual(pr?.value, 5000)
    }

    func testFirstSessionVolumeIsAlwaysPR() {
        XCTAssertNotNil(PRDetector.detectSessionVolume(volume: 100, previousBest: nil, at: Date()))
    }

    func testNoSessionVolumePRWhenNotExceeded() {
        XCTAssertNil(PRDetector.detectSessionVolume(volume: 3000, previousBest: 4000, at: Date()))
    }

    func testEstimated1RMUsesEpley() {
        // 100kg × 10 reps → 100 × (1 + 10/30) ≈ 133.3
        XCTAssertEqual(PRDetector.estimated1RM(weightKg: 100, reps: 10), 133.33, accuracy: 0.01)
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
