import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case strength
    case mobility
    case flexibility
    case yoga
    case cardio
}

enum LoggingFieldMask: String, Codable, Sendable {
    case weightReps
    case duration
    case hold
    case side
}

enum SetType: String, Codable, CaseIterable, Sendable {
    case normal
    case warmup
    case failure
    case dropSet
}

enum BodySide: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case both
}

enum SyncStatus: String, Codable, Sendable {
    case pending
    case synced
    case conflict
}

enum ProgramCategory: String, Codable, CaseIterable, Sendable {
    case strength
    case mobility
    case yoga
    case flexibility
    case hybrid
}

enum WorkoutPhase: String, Codable, Sendable {
    case active
    case resting
}

enum ProgressionAction: String, Codable, Sendable {
    case increase
    case hold
    case decrease
    case deload
}

enum AppTab: Hashable, Sendable {
    case home
    case programs
    case progress
    case profile
}

struct RepRange: Sendable, Equatable {
    var min: Int
    var max: Int
}

struct CompletedWorkingSet: Sendable, Equatable {
    var weightKg: Double
    var reps: Int
    var rir: Int?
    var completedAt: Date
}

struct ProgressionInput: Sendable {
    let exerciseId: UUID
    let history: [CompletedWorkingSet]
    let targets: RepRange
    let rirEnabled: Bool
    let incrementKg: Double
    /// Consecutive prior sessions that stalled (held or regressed) for this exercise.
    let failedAttempts: Int
    /// True when the routine's rep targets changed since the last recommendation — resets the stall streak.
    let targetsChanged: Bool

    init(
        exerciseId: UUID,
        history: [CompletedWorkingSet],
        targets: RepRange,
        rirEnabled: Bool,
        incrementKg: Double,
        failedAttempts: Int = 0,
        targetsChanged: Bool = false
    ) {
        self.exerciseId = exerciseId
        self.history = history
        self.targets = targets
        self.rirEnabled = rirEnabled
        self.incrementKg = incrementKg
        self.failedAttempts = failedAttempts
        self.targetsChanged = targetsChanged
    }
}

struct ProgressionOutput: Sendable, Equatable {
    let targetWeightKg: Double?
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetRir: Int?
    let action: ProgressionAction
    let reason: String
    /// Running count of consecutive stalls after this recommendation (0 after an increase or deload).
    let failedAttempts: Int

    init(
        targetWeightKg: Double?,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetRir: Int?,
        action: ProgressionAction,
        reason: String,
        failedAttempts: Int = 0
    ) {
        self.targetWeightKg = targetWeightKg
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetRir = targetRir
        self.action = action
        self.reason = reason
        self.failedAttempts = failedAttempts
    }
}

enum PersonalRecordType: String, Codable, Sendable {
    case weight
    case reps
    case estimated1RM
    case sessionVolume
}

struct PersonalRecord: Sendable, Equatable, Identifiable {
    let id: UUID
    let exerciseId: UUID
    let type: PersonalRecordType
    let value: Double
    let achievedAt: Date
}
