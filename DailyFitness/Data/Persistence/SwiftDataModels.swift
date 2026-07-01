import Foundation
import SwiftData

@Model
final class ExerciseEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var primaryMuscles: [String]
    var equipment: [String]
    var imageURL: String?
    var isCustom: Bool
    var userId: UUID?
    var loggingFieldsRaw: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .strength }
        set { categoryRaw = newValue.rawValue }
    }

    var loggingFields: LoggingFieldMask {
        get { LoggingFieldMask(rawValue: loggingFieldsRaw) ?? .weightReps }
        set { loggingFieldsRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        primaryMuscles: [String] = [],
        equipment: [String] = [],
        imageURL: String? = nil,
        isCustom: Bool = false,
        userId: UUID? = nil,
        loggingFields: LoggingFieldMask = .weightReps
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.primaryMuscles = primaryMuscles
        self.equipment = equipment
        self.imageURL = imageURL
        self.isCustom = isCustom
        self.userId = userId
        self.loggingFieldsRaw = loggingFields.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class RoutineEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var isSuggested: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \RoutineExerciseEntity.routine)
    var exercises: [RoutineExerciseEntity]
    var createdAt: Date
    var updatedAt: Date
    var syncStatusRaw: String
    var deletedAt: Date?

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), userId: UUID, name: String, isSuggested: Bool = false) {
        self.id = id
        self.userId = userId
        self.name = name
        self.isSuggested = isSuggested
        self.exercises = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatusRaw = SyncStatus.pending.rawValue
    }
}

@Model
final class RoutineExerciseEntity {
    var id: UUID
    var sortOrder: Int
    var exerciseId: UUID
    var targetSets: Int
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    var targetDurationSeconds: Int?
    var restSeconds: Int
    var supersetGroupId: UUID?
    var progressionEnabled: Bool
    var note: String?
    var routine: RoutineEntity?

    init(
        id: UUID = UUID(),
        sortOrder: Int,
        exerciseId: UUID,
        targetSets: Int = 3,
        targetRepsMin: Int? = 8,
        targetRepsMax: Int? = 12,
        targetDurationSeconds: Int? = nil,
        restSeconds: Int = 90,
        progressionEnabled: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.exerciseId = exerciseId
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetDurationSeconds = targetDurationSeconds
        self.restSeconds = restSeconds
        self.progressionEnabled = progressionEnabled
        self.note = note
    }
}

@Model
final class ProgramEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var name: String
    var categoryRaw: String
    var isSuggested: Bool
    var sourceTemplateId: UUID?
    var weeks: Int?
    var isActive: Bool
    var programDescription: String?
    var levelRaw: String?
    var daysPerWeek: Int?
    var equipment: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \ProgramDayEntity.program)
    var days: [ProgramDayEntity]
    var createdAt: Date
    var updatedAt: Date
    var syncStatusRaw: String

    var category: ProgramCategory {
        get { ProgramCategory(rawValue: categoryRaw) ?? .strength }
        set { categoryRaw = newValue.rawValue }
    }

    var level: ProgramLevel? {
        get { levelRaw.flatMap { ProgramLevel(rawValue: $0) } }
        set { levelRaw = newValue?.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        category: ProgramCategory,
        isSuggested: Bool = false,
        weeks: Int? = nil,
        programDescription: String? = nil,
        level: ProgramLevel? = nil,
        daysPerWeek: Int? = nil,
        equipment: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.categoryRaw = category.rawValue
        self.isSuggested = isSuggested
        self.weeks = weeks
        self.programDescription = programDescription
        self.levelRaw = level?.rawValue
        self.daysPerWeek = daysPerWeek
        self.equipment = equipment
        self.isActive = false
        self.days = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatusRaw = SyncStatus.pending.rawValue
    }
}

@Model
final class ProgramDayEntity {
    var id: UUID
    var weekIndex: Int
    var dayOfWeek: Int
    var routineId: UUID?
    var sortOrder: Int
    var program: ProgramEntity?

    init(
        id: UUID = UUID(),
        weekIndex: Int = 0,
        dayOfWeek: Int,
        routineId: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.dayOfWeek = dayOfWeek
        self.routineId = routineId
        self.sortOrder = sortOrder
    }
}

@Model
final class WorkoutSessionEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var routineId: UUID?
    var programDayId: UUID?
    var note: String?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntity.session)
    var exercises: [WorkoutExerciseEntity]
    var syncStatusRaw: String

    var isActive: Bool { endedAt == nil }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), userId: UUID, name: String, routineId: UUID? = nil) {
        self.id = id
        self.userId = userId
        self.name = name
        self.startedAt = Date()
        self.exercises = []
        self.syncStatusRaw = SyncStatus.pending.rawValue
    }
}

@Model
final class WorkoutExerciseEntity {
    var id: UUID
    var exerciseId: UUID
    var sortOrder: Int
    var supersetGroupId: UUID?
    var note: String?
    /// Per-exercise rest override (seconds). Falls back to the user's default rest when nil.
    var restSecondsOverride: Int?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetEntity.workoutExercise)
    var sets: [WorkoutSetEntity]
    var session: WorkoutSessionEntity?

    init(id: UUID = UUID(), exerciseId: UUID, sortOrder: Int) {
        self.id = id
        self.exerciseId = exerciseId
        self.sortOrder = sortOrder
        self.sets = []
    }
}

@Model
final class WorkoutSetEntity {
    var id: UUID
    var setNumber: Int
    var setTypeRaw: String
    var weightKg: Double?
    var reps: Int?
    var durationSeconds: Int?
    var holdSeconds: Int?
    var sideRaw: String?
    var rir: Int?
    var completedAt: Date?
    var isCompleted: Bool
    var workoutExercise: WorkoutExerciseEntity?

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .normal }
        set { setTypeRaw = newValue.rawValue }
    }

    var side: BodySide? {
        get { sideRaw.flatMap { BodySide(rawValue: $0) } }
        set { sideRaw = newValue?.rawValue }
    }

    init(id: UUID = UUID(), setNumber: Int, setType: SetType = .normal) {
        self.id = id
        self.setNumber = setNumber
        self.setTypeRaw = setType.rawValue
        self.isCompleted = false
    }
}

@Model
final class ProgressionRecommendationEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var exerciseId: UUID
    var routineExerciseId: UUID?
    var targetWeightKg: Double?
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetRir: Int?
    var reason: String
    var actionRaw: String = ProgressionAction.hold.rawValue
    var failedAttempts: Int = 0
    var computedAt: Date

    var action: ProgressionAction {
        get { ProgressionAction(rawValue: actionRaw) ?? .hold }
        set { actionRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        exerciseId: UUID,
        output: ProgressionOutput,
        routineExerciseId: UUID? = nil
    ) {
        self.id = id
        self.userId = userId
        self.exerciseId = exerciseId
        self.routineExerciseId = routineExerciseId
        self.targetWeightKg = output.targetWeightKg
        self.targetRepsMin = output.targetRepsMin
        self.targetRepsMax = output.targetRepsMax
        self.targetRir = output.targetRir
        self.reason = output.reason
        self.actionRaw = output.action.rawValue
        self.failedAttempts = output.failedAttempts
        self.computedAt = Date()
    }
}

@Model
final class PersonalRecordEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var exerciseId: UUID
    var typeRaw: String
    var value: Double
    var achievedAt: Date
    var sessionId: UUID
    var setId: UUID

    var type: PersonalRecordType {
        get { PersonalRecordType(rawValue: typeRaw) ?? .weight }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        exerciseId: UUID,
        type: PersonalRecordType,
        value: Double,
        achievedAt: Date,
        sessionId: UUID,
        setId: UUID
    ) {
        self.id = id
        self.userId = userId
        self.exerciseId = exerciseId
        self.typeRaw = type.rawValue
        self.value = value
        self.achievedAt = achievedAt
        self.sessionId = sessionId
        self.setId = setId
    }
}

@Model
final class UserPreferencesEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var usePounds: Bool
    var defaultRestSeconds: Int
    var rirEnabled: Bool
    var liveActivitiesEnabled: Bool
    var restEndNotificationEnabled: Bool

    init(userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.usePounds = Locale.current.measurementSystem != .metric
        self.defaultRestSeconds = 90
        self.rirEnabled = false
        self.liveActivitiesEnabled = true
        self.restEndNotificationEnabled = false
    }
}

enum DailyFitnessSchema {
    static var models: [any PersistentModel.Type] {
        [
            ExerciseEntity.self,
            RoutineEntity.self,
            RoutineExerciseEntity.self,
            ProgramEntity.self,
            ProgramDayEntity.self,
            WorkoutSessionEntity.self,
            WorkoutExerciseEntity.self,
            WorkoutSetEntity.self,
            ProgressionRecommendationEntity.self,
            PersonalRecordEntity.self,
            UserPreferencesEntity.self
        ]
    }
}
