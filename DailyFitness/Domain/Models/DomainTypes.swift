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

    var displayName: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.cooldown"
        case .yoga: return "figure.mind.and.body"
        case .flexibility: return "figure.flexibility"
        case .hybrid: return "figure.strengthtraining.functional"
        }
    }
}

enum ProgramLevel: String, Codable, CaseIterable, Sendable {
    case beginner
    case beginnerIntermediate = "beginner_intermediate"
    case intermediate
    case advanced
    case all

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .beginnerIntermediate: return "Beginner–Intermediate"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .all: return "All levels"
        }
    }
}

enum WorkoutPhase: String, Codable, Sendable {
    case active
    case resting
}

enum ProgressionAction: String, Codable, Sendable {
    case increase
    case hold
    case decrease
}

enum AppTab: Hashable, Sendable {
    case home
    case library
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
}

struct ProgressionOutput: Sendable, Equatable {
    let targetWeightKg: Double?
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetRir: Int?
    let action: ProgressionAction
    let reason: String
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
