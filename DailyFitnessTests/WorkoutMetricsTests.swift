import XCTest
import SwiftData
@testable import DailyFitness

@MainActor
final class WorkoutMetricsTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(DailyFitnessSchema.models), configurations: [config])
        return ModelContext(container)
    }

    private func strengthSet(_ number: Int, weight: Double, reps: Int, type: SetType, completed: Bool) -> WorkoutSetEntity {
        let set = WorkoutSetEntity(setNumber: number, setType: type)
        set.weightKg = weight
        set.reps = reps
        set.isCompleted = completed
        return set
    }

    func testStrengthVolumeExcludesWarmupsAndIncompleteSets() throws {
        let context = try makeContext()
        let session = WorkoutSessionEntity(userId: UUID(), name: "Test")
        let exercise = WorkoutExerciseEntity(exerciseId: UUID(), sortOrder: 0)
        exercise.sets = [
            strengthSet(1, weight: 50, reps: 10, type: .warmup, completed: true),   // excluded (warmup)
            strengthSet(2, weight: 100, reps: 5, type: .normal, completed: true),    // 500
            strengthSet(3, weight: 100, reps: 5, type: .failure, completed: true),   // 500 (failure still counts)
            strengthSet(4, weight: 100, reps: 5, type: .normal, completed: false)    // excluded (incomplete)
        ]
        session.exercises = [exercise]
        context.insert(session)

        XCTAssertEqual(WorkoutMetrics.strengthVolume(for: exercise), 1000)
        XCTAssertEqual(WorkoutMetrics.totalStrengthVolume(for: session), 1000)
        XCTAssertEqual(WorkoutMetrics.completedWorkingSetCount(for: session), 2)
        XCTAssertEqual(WorkoutMetrics.completedExerciseCount(for: session), 1)
    }

    func testCountsTowardVolumeFlags() throws {
        let warmup = strengthSet(1, weight: 50, reps: 10, type: .warmup, completed: true)
        let working = strengthSet(2, weight: 100, reps: 5, type: .normal, completed: true)
        let incomplete = strengthSet(3, weight: 100, reps: 5, type: .normal, completed: false)

        XCTAssertFalse(WorkoutMetrics.countsTowardVolume(warmup))
        XCTAssertTrue(WorkoutMetrics.countsTowardVolume(working))
        XCTAssertFalse(WorkoutMetrics.countsTowardVolume(incomplete))
    }

    func testTotalTimedSecondsSumsDurationAndHold() throws {
        let context = try makeContext()
        let session = WorkoutSessionEntity(userId: UUID(), name: "Mobility")
        let exercise = WorkoutExerciseEntity(exerciseId: UUID(), sortOrder: 0)
        let durationSet = WorkoutSetEntity(setNumber: 1)
        durationSet.durationSeconds = 60
        durationSet.isCompleted = true
        let holdSet = WorkoutSetEntity(setNumber: 2)
        holdSet.holdSeconds = 45
        holdSet.isCompleted = true
        let incompleteHold = WorkoutSetEntity(setNumber: 3)
        incompleteHold.holdSeconds = 30
        incompleteHold.isCompleted = false
        exercise.sets = [durationSet, holdSet, incompleteHold]
        session.exercises = [exercise]
        context.insert(session)

        XCTAssertEqual(WorkoutMetrics.totalTimedSeconds(for: session), 105)
    }
}
