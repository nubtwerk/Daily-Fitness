import Foundation
import Network
import Supabase
import SwiftData

/// Which table a sync operation targets. Carrying the type with the operation is what lets
/// `deleteEntity` route to the correct table — previously deletes were hard-coded to
/// `workout_sessions`, so deleting a routine/program/custom-exercise hit the wrong table.
enum SyncEntityType: String, Sendable, CaseIterable, Codable, Equatable {
    case session
    case routine
    case program
    case exercise

    var table: String {
        switch self {
        case .session: return "workout_sessions"
        case .routine: return "routines"
        case .program: return "programs"
        case .exercise: return "exercises"
        }
    }
}

/// Pure decision for reconciling one local row against its remote counterpart during a pull.
/// Extracted so the conflict / last-writer-wins logic is unit-testable without a live backend.
enum SyncDecision: Equatable, Sendable {
    case insert        // no local row; create from remote
    case applyRemote   // remote is newer and local was already synced — remote wins
    case keepLocal     // local is newer or equal — nothing to do
    case deleteLocal   // remote tombstoned (deleted_at set) — remove local
    case conflict      // both sides changed; remote wins by recency but flag it
}

enum SyncResolver {
    static func decide(
        localExists: Bool,
        localPending: Bool,
        localUpdatedAt: Date?,
        remoteUpdatedAt: Date,
        remoteDeleted: Bool
    ) -> SyncDecision {
        guard localExists else {
            // Nothing local. Only materialise live rows; ignore tombstones we never had.
            return remoteDeleted ? .keepLocal : .insert
        }

        if remoteDeleted {
            // Remote says deleted. Keep local only if it has a strictly newer unsynced edit
            // (the user changed it locally and that push hasn't landed yet).
            if localPending, let local = localUpdatedAt, local > remoteUpdatedAt {
                return .keepLocal
            }
            return .deleteLocal
        }

        guard let local = localUpdatedAt else { return .applyRemote }

        if remoteUpdatedAt > local {
            // Remote is newer. If we also have an unsynced local edit, that's a true conflict;
            // resolve last-writer-wins (remote, since it is newer) but surface it.
            return localPending ? .conflict : .applyRemote
        }
        return .keepLocal
    }
}

// MARK: - Pull decode shapes (file-scope so helpers can reference them)

private struct PSession: Decodable {
    let id: UUID; let user_id: UUID; let name: String
    let started_at: Date; let ended_at: Date?; let routine_id: UUID?
    let program_day_id: UUID?; let note: String?
    let updated_at: Date; let deleted_at: Date?
}
private struct PSet: Decodable {
    let id: UUID; let session_id: UUID; let exercise_id: UUID
    let set_number: Int; let set_type: String
    let weight_kg: Double?; let reps: Int?; let duration_seconds: Int?
    let hold_seconds: Int?; let side: String?; let rir: Int?
    let completed_at: Date?; let is_completed: Bool
}
private struct PRoutine: Decodable {
    let id: UUID; let user_id: UUID; let name: String
    let updated_at: Date; let deleted_at: Date?
}
private struct PRoutineExercise: Decodable {
    let id: UUID; let routine_id: UUID; let sort_order: Int; let exercise_id: UUID
    let target_sets: Int; let target_reps_min: Int?; let target_reps_max: Int?
    let target_duration_seconds: Int?; let rest_seconds: Int; let progression_enabled: Bool
    let superset_group_id: UUID?; let note: String?
}
private struct PProgram: Decodable {
    let id: UUID; let user_id: UUID?; let name: String; let category: String
    let is_suggested: Bool; let weeks: Int?; let is_active: Bool
    let updated_at: Date; let deleted_at: Date?
}
private struct PProgramDay: Decodable {
    let id: UUID; let program_id: UUID; let week_index: Int
    let day_of_week: Int; let routine_id: UUID?; let sort_order: Int
}
private struct PExercise: Decodable {
    let id: UUID; let name: String; let category: String
    let primary_muscles: [String]; let equipment: [String]; let image_url: String?
    let logging_fields: String; let updated_at: Date; let deleted_at: Date?
}

@MainActor
final class SyncEngine {
    enum SyncOperation: Sendable, Codable, Equatable {
        case upsertSession(UUID)
        case upsertRoutine(UUID)
        case upsertProgram(UUID)
        case upsertExercise(UUID)
        case deleteEntity(SyncEntityType, UUID)
    }

    private static let queueDefaultsKey = "app.dailybase.dailyfitness.syncQueue"

    private var queue: [SyncOperation] = [] {
        didSet { persistQueue() }
    }
    private(set) var isAuthenticated = false
    private(set) var isOnline = true
    private(set) var conflictsResolved = 0
    private var isFlushing = false
    private var pathMonitor: NWPathMonitor?
    private weak var monitoredContext: ModelContext?

    private let client: SupabaseClient
    private static let cursorKey = "syncPullCursor"

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
        queue = loadPersistedQueue()
    }

    // MARK: - Cursor

    /// Server `updated_at` high-water mark of the last successful pull. Incremental pulls only
    /// fetch rows newer than this, so we never re-walk the whole table.
    private var pullCursor: Date? {
        get {
            let raw = UserDefaults.standard.double(forKey: Self.cursorKey)
            return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.cursorKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.cursorKey)
            }
        }
    }

    /// Clears the cursor so the next pull is a full restore. Used after account deletion.
    func resetSyncState() {
        pullCursor = nil
        conflictsResolved = 0
        queue.removeAll()
    }

    private static let cursorFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Lifecycle

    func setAuthenticated(_ value: Bool) {
        isAuthenticated = value
    }

    func startMonitoring(context: ModelContext) {
        monitoredContext = context
        reenqueuePendingEntities(context: context)
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let online = path.status == .satisfied
                let wasOffline = !self.isOnline
                self.isOnline = online
                if online, wasOffline, let ctx = self.monitoredContext {
                    try? await self.flush(context: ctx)
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.dailybase.dailyfitness.sync"))
        pathMonitor = monitor
    }

    func enqueue(_ operation: SyncOperation) {
        guard !queue.contains(operation) else { return }
        queue.append(operation)
    }

    /// Drop any pending upserts for a session that is being discarded.
    func cancelPendingSession(id: UUID) {
        queue.removeAll { $0 == .upsertSession(id) }
    }

    /// Drop a specific queued upsert. Used after a pull resolves a conflict remote-wins: the
    /// local row has been overwritten with the remote value, so re-pushing the (now moot) local
    /// edit would just clobber the queue and re-write data that already lost the conflict.
    private func cancelPendingUpsert(_ operation: SyncOperation) {
        queue.removeAll { $0 == operation }
    }

    var pendingCount: Int { queue.count }

    /// Clears the "resolved a conflict" notice once the user has seen it.
    func acknowledgeConflicts() {
        conflictsResolved = 0
    }

    // MARK: - Durable queue (LOG-11 / US-011)

    private func persistQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: Self.queueDefaultsKey)
        }
    }

    private func loadPersistedQueue() -> [SyncOperation] {
        guard let data = UserDefaults.standard.data(forKey: Self.queueDefaultsKey),
              let ops = try? JSONDecoder().decode([SyncOperation].self, from: data) else {
            return []
        }
        return ops
    }

    /// Re-enqueue any locally pending entities at launch, in case ops were lost
    /// (e.g. a crash before the queue persisted) — defensive durability for
    /// offline logging.
    func reenqueuePendingEntities(context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.syncStatusRaw == "pending" }
        ))) ?? []
        for session in sessions { enqueue(.upsertSession(session.id)) }

        let routines = (try? context.fetch(FetchDescriptor<RoutineEntity>(
            predicate: #Predicate { $0.syncStatusRaw == "pending" }
        ))) ?? []
        for routine in routines { enqueue(.upsertRoutine(routine.id)) }

        let programs = (try? context.fetch(FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.syncStatusRaw == "pending" }
        ))) ?? []
        for program in programs { enqueue(.upsertProgram(program.id)) }
    }

    // MARK: - Flush (push)

    func flush(context: ModelContext) async throws {
        guard isAuthenticated, isOnline, !AppConfig.supabaseAnonKey.isEmpty else { return }
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        let pending = queue
        queue.removeAll()
        var retry: [SyncOperation] = []

        for operation in pending {
            do {
                switch operation {
                case .upsertSession(let id):
                    try await upsertSession(id: id, context: context)
                case .upsertRoutine(let id):
                    try await upsertRoutine(id: id, context: context)
                case .upsertProgram(let id):
                    try await upsertProgram(id: id, context: context)
                case .upsertExercise(let id):
                    try await upsertExercise(id: id, context: context)
                case .deleteEntity(let type, let id):
                    try await deleteEntity(type: type, id: id)
                }
            } catch {
                retry.append(operation)
            }
        }

        queue.insert(contentsOf: retry, at: 0)
    }

    // MARK: - Push payloads

    private struct SessionRow: Encodable {
        let id: UUID; let user_id: UUID; let name: String
        let started_at: Date; let ended_at: Date?; let routine_id: UUID?
        let program_day_id: UUID?; let note: String?
        let updated_at: Date; let deleted_at: Date?
    }
    private struct SetRow: Encodable {
        let id: UUID; let user_id: UUID; let session_id: UUID; let exercise_id: UUID
        let set_number: Int; let set_type: String
        let weight_kg: Double?; let reps: Int?; let duration_seconds: Int?
        let hold_seconds: Int?; let side: String?; let rir: Int?
        let completed_at: Date?; let is_completed: Bool; let updated_at: Date
    }
    private struct RoutineRow: Encodable {
        let id: UUID; let user_id: UUID; let name: String
        let updated_at: Date; let deleted_at: Date?
    }
    private struct RoutineExerciseRow: Encodable {
        let id: UUID; let routine_id: UUID; let user_id: UUID; let sort_order: Int
        let exercise_id: UUID; let target_sets: Int; let target_reps_min: Int?
        let target_reps_max: Int?; let target_duration_seconds: Int?
        let rest_seconds: Int; let superset_group_id: UUID?
        let progression_enabled: Bool; let note: String?
    }
    private struct ProgramRow: Encodable {
        let id: UUID; let user_id: UUID?; let name: String; let category: String
        let is_suggested: Bool; let weeks: Int?; let is_active: Bool
        let updated_at: Date; let deleted_at: Date?
    }
    private struct ProgramDayRow: Encodable {
        let id: UUID; let program_id: UUID; let user_id: UUID?
        let week_index: Int; let day_of_week: Int; let routine_id: UUID?; let sort_order: Int
    }
    private struct ExerciseRow: Encodable {
        let id: UUID; let user_id: UUID?; let name: String; let category: String
        let primary_muscles: [String]; let equipment: [String]; let image_url: String?
        let is_custom: Bool; let logging_fields: String
        let updated_at: Date; let deleted_at: Date?
    }
    private struct SoftDelete: Encodable {
        let deleted_at: Date
        let updated_at: Date
    }

    private func upsertSession(id: UUID, context: ModelContext) async throws {
        guard let session = try fetchSession(id, context) else { return }

        let row = SessionRow(
            id: session.id, user_id: session.userId, name: session.name,
            started_at: session.startedAt, ended_at: session.endedAt, routine_id: session.routineId,
            program_day_id: session.programDayId, note: session.note,
            updated_at: session.updatedAt, deleted_at: session.deletedAt
        )
        try await client.from("workout_sessions").upsert(row).execute()

        // NOTE: there is no workout_exercises table in the payload yet, so a live session's
        // per-exercise note / supersetGroupId / restSecondsOverride are local-only. Sets carry
        // `updated_at` so the pull cursor sees them.
        let setRows: [SetRow] = session.exercises.flatMap { workoutExercise in
            workoutExercise.sets.map { set in
                SetRow(
                    id: set.id, user_id: session.userId, session_id: session.id,
                    exercise_id: workoutExercise.exerciseId, set_number: set.setNumber,
                    set_type: set.setTypeRaw, weight_kg: set.weightKg, reps: set.reps,
                    duration_seconds: set.durationSeconds, hold_seconds: set.holdSeconds,
                    side: set.sideRaw, rir: set.rir, completed_at: set.completedAt,
                    is_completed: set.isCompleted, updated_at: session.updatedAt
                )
            }
        }
        if !setRows.isEmpty {
            try await client.from("workout_sets").upsert(setRows).execute()
        }

        session.syncStatus = .synced
        try context.save()
    }

    private func upsertRoutine(id: UUID, context: ModelContext) async throws {
        guard let routine = try fetchRoutine(id, context) else { return }

        try await client.from("routines").upsert(
            RoutineRow(id: routine.id, user_id: routine.userId, name: routine.name,
                       updated_at: routine.updatedAt, deleted_at: routine.deletedAt)
        ).execute()

        let rows = routine.exercises.map { item in
            RoutineExerciseRow(
                id: item.id, routine_id: routine.id, user_id: routine.userId, sort_order: item.sortOrder,
                exercise_id: item.exerciseId, target_sets: item.targetSets,
                target_reps_min: item.targetRepsMin, target_reps_max: item.targetRepsMax,
                target_duration_seconds: item.targetDurationSeconds,
                rest_seconds: item.restSeconds,
                superset_group_id: item.supersetGroupId,
                progression_enabled: item.progressionEnabled,
                note: item.note
            )
        }
        // Replace the child set so removed exercises don't linger remotely.
        try await client.from("routine_exercises").delete().eq("routine_id", value: routine.id.uuidString).execute()
        if !rows.isEmpty {
            try await client.from("routine_exercises").upsert(rows).execute()
        }

        routine.syncStatus = .synced
        try context.save()
    }

    private func upsertProgram(id: UUID, context: ModelContext) async throws {
        guard let program = try fetchProgram(id, context) else { return }

        try await client.from("programs").upsert(
            ProgramRow(id: program.id, user_id: program.userId, name: program.name,
                       category: program.categoryRaw, is_suggested: program.isSuggested,
                       weeks: program.weeks, is_active: program.isActive,
                       updated_at: program.updatedAt, deleted_at: program.deletedAt)
        ).execute()

        // ProgramDay rows were never pushed before — schedules silently failed to sync.
        let dayRows = program.days.map { day in
            ProgramDayRow(id: day.id, program_id: program.id, user_id: program.userId,
                          week_index: day.weekIndex, day_of_week: day.dayOfWeek,
                          routine_id: day.routineId, sort_order: day.sortOrder)
        }
        try await client.from("program_days").delete().eq("program_id", value: program.id.uuidString).execute()
        if !dayRows.isEmpty {
            try await client.from("program_days").upsert(dayRows).execute()
        }

        program.syncStatus = .synced
        try context.save()
    }

    private func upsertExercise(id: UUID, context: ModelContext) async throws {
        guard let exercise = try fetchExercise(id, context), exercise.isCustom else { return }

        try await client.from("exercises").upsert(
            ExerciseRow(id: exercise.id, user_id: exercise.userId, name: exercise.name,
                        category: exercise.categoryRaw, primary_muscles: exercise.primaryMuscles,
                        equipment: exercise.equipment, image_url: exercise.imageURL, is_custom: true,
                        logging_fields: exercise.loggingFieldsRaw,
                        updated_at: exercise.updatedAt, deleted_at: exercise.deletedAt)
        ).execute()
    }

    /// Soft-deletes the remote row (sets `deleted_at`) for the correct table. Soft deletes keep
    /// an audit trail and let *other* devices observe the tombstone via the `updated_at` cursor
    /// and remove their local copy.
    private func deleteEntity(type: SyncEntityType, id: UUID) async throws {
        let now = Date()
        try await client
            .from(type.table)
            .update(SoftDelete(deleted_at: now, updated_at: now))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Pull

    /// Pull rows changed since the stored cursor and reconcile them into the local store.
    func pullRemoteChanges(context: ModelContext) async throws {
        try await pull(since: pullCursor, context: context)
    }

    /// Full restore: re-materialise the user's entire cloud dataset locally (used right after a
    /// fresh sign-in / on a new device). Walks every table with no row cap.
    func restoreFromCloud(context: ModelContext) async throws {
        try await pull(since: nil, context: context)
    }

    private func pull(since: Date?, context: ModelContext) async throws {
        guard isAuthenticated, isOnline, !AppConfig.supabaseAnonKey.isEmpty else { return }

        var maxSeen = since ?? .distantPast
        func cursorString(_ date: Date) -> String { Self.cursorFormatter.string(from: date) }

        // ---- Sessions + sets ----
        var sessionQuery = client.from("workout_sessions").select()
        if let since { sessionQuery = sessionQuery.gt("updated_at", value: cursorString(since)) }
        let sessions: [PSession] = try await sessionQuery.order("updated_at", ascending: true).execute().value
        let setsBySession = try await fetchChildren(
            ids: sessions.filter { $0.deleted_at == nil }.map { $0.id.uuidString },
            table: "workout_sets", parentColumn: "session_id", type: PSet.self, parentId: { $0.session_id }
        )
        for row in sessions {
            maxSeen = max(maxSeen, row.updated_at)
            let local = try fetchSession(row.id, context)
            switch decide(local: local, remoteUpdatedAt: row.updated_at, remoteDeleted: row.deleted_at != nil) {
            case .keepLocal: continue
            case .deleteLocal: if let local { context.delete(local) }
            case .insert:
                let session = WorkoutSessionEntity(id: row.id, userId: row.user_id, name: row.name, routineId: row.routine_id)
                applySession(row, to: session)
                context.insert(session)
                rebuildSets(setsBySession[row.id] ?? [], on: session, context: context)
            case .upsert(let isConflict):
                guard let local else { continue }
                applySession(row, to: local)
                rebuildSets(setsBySession[row.id] ?? [], on: local, context: context)
                local.syncStatus = isConflict ? .conflict : .synced
                if isConflict {
                    conflictsResolved += 1
                    cancelPendingUpsert(.upsertSession(row.id))
                }
            }
        }

        // ---- Routines + routine_exercises ----
        var routineQuery = client.from("routines").select()
        if let since { routineQuery = routineQuery.gt("updated_at", value: cursorString(since)) }
        let routines: [PRoutine] = try await routineQuery.order("updated_at", ascending: true).execute().value
        let exByRoutine = try await fetchChildren(
            ids: routines.filter { $0.deleted_at == nil }.map { $0.id.uuidString },
            table: "routine_exercises", parentColumn: "routine_id", type: PRoutineExercise.self, parentId: { $0.routine_id }
        )
        for row in routines {
            maxSeen = max(maxSeen, row.updated_at)
            let local = try fetchRoutine(row.id, context)
            switch decide(local: local, remoteUpdatedAt: row.updated_at, remoteDeleted: row.deleted_at != nil) {
            case .keepLocal: continue
            case .deleteLocal: if let local { context.delete(local) }
            case .insert:
                let routine = RoutineEntity(id: row.id, userId: row.user_id, name: row.name)
                routine.updatedAt = row.updated_at
                routine.syncStatus = .synced
                context.insert(routine)
                rebuildRoutineExercises(exByRoutine[row.id] ?? [], on: routine, context: context)
            case .upsert(let isConflict):
                guard let local else { continue }
                local.name = row.name
                local.updatedAt = row.updated_at
                rebuildRoutineExercises(exByRoutine[row.id] ?? [], on: local, context: context)
                local.syncStatus = isConflict ? .conflict : .synced
                if isConflict {
                    conflictsResolved += 1
                    cancelPendingUpsert(.upsertRoutine(row.id))
                }
            }
        }

        // ---- Programs + program_days (own, non-suggested only) ----
        var programQuery = client.from("programs").select().eq("is_suggested", value: false)
        if let since { programQuery = programQuery.gt("updated_at", value: cursorString(since)) }
        let programs: [PProgram] = try await programQuery.order("updated_at", ascending: true).execute().value
        let daysByProgram = try await fetchChildren(
            ids: programs.filter { $0.deleted_at == nil }.map { $0.id.uuidString },
            table: "program_days", parentColumn: "program_id", type: PProgramDay.self, parentId: { $0.program_id }
        )
        for row in programs {
            maxSeen = max(maxSeen, row.updated_at)
            let local = try fetchProgram(row.id, context)
            switch decide(local: local, remoteUpdatedAt: row.updated_at, remoteDeleted: row.deleted_at != nil) {
            case .keepLocal: continue
            case .deleteLocal: if let local { context.delete(local) }
            case .insert:
                let program = ProgramEntity(id: row.id, userId: row.user_id, name: row.name,
                                            category: ProgramCategory(rawValue: row.category) ?? .strength,
                                            isSuggested: false, weeks: row.weeks)
                program.isActive = row.is_active
                program.updatedAt = row.updated_at
                program.syncStatus = .synced
                context.insert(program)
                rebuildProgramDays(daysByProgram[row.id] ?? [], on: program, context: context)
            case .upsert(let isConflict):
                guard let local else { continue }
                local.name = row.name
                local.category = ProgramCategory(rawValue: row.category) ?? .strength
                local.weeks = row.weeks
                local.isActive = row.is_active
                local.updatedAt = row.updated_at
                rebuildProgramDays(daysByProgram[row.id] ?? [], on: local, context: context)
                local.syncStatus = isConflict ? .conflict : .synced
                if isConflict {
                    conflictsResolved += 1
                    cancelPendingUpsert(.upsertProgram(row.id))
                }
            }
        }

        // ---- Custom exercises ----
        var exerciseQuery = client.from("exercises").select().eq("is_custom", value: true)
        if let since { exerciseQuery = exerciseQuery.gt("updated_at", value: cursorString(since)) }
        let exercises: [PExercise] = try await exerciseQuery.order("updated_at", ascending: true).execute().value
        for row in exercises {
            maxSeen = max(maxSeen, row.updated_at)
            let local = try fetchExercise(row.id, context)
            // Custom exercises don't carry a syncStatus, so they never register as "pending".
            switch decide(local: local, localPending: false, remoteUpdatedAt: row.updated_at, remoteDeleted: row.deleted_at != nil) {
            case .keepLocal: continue
            case .deleteLocal: if let local { local.deletedAt = row.deleted_at; local.updatedAt = row.updated_at }
            case .insert:
                let exercise = ExerciseEntity(
                    id: row.id, name: row.name,
                    category: ExerciseCategory(rawValue: row.category) ?? .strength,
                    primaryMuscles: row.primary_muscles, equipment: row.equipment,
                    imageURL: row.image_url, isCustom: true, userId: nil,
                    loggingFields: LoggingFieldMask(rawValue: row.logging_fields) ?? .weightReps
                )
                exercise.updatedAt = row.updated_at
                exercise.deletedAt = row.deleted_at
                context.insert(exercise)
            case .upsert:
                guard let local else { continue }
                local.name = row.name
                local.category = ExerciseCategory(rawValue: row.category) ?? .strength
                local.primaryMuscles = row.primary_muscles
                local.equipment = row.equipment
                local.loggingFields = LoggingFieldMask(rawValue: row.logging_fields) ?? .weightReps
                local.updatedAt = row.updated_at
                local.deletedAt = row.deleted_at
            }
        }

        try context.save()
        if maxSeen > .distantPast { pullCursor = maxSeen }
    }

    // MARK: - Pull helpers

    /// A pulled-row decision. `.upsert(isConflict:)` merges "apply remote" and "conflict
    /// resolved (remote wins)" into one branch so each entity's switch stays compact;
    /// `isConflict` flags whether to mark the local row `.conflict`.
    private enum PullOutcome {
        case insert
        case upsert(isConflict: Bool)
        case keepLocal
        case deleteLocal
    }

    private func decide(
        local: (any HasSyncFields)?,
        localPending: Bool? = nil,
        remoteUpdatedAt: Date,
        remoteDeleted: Bool
    ) -> PullOutcome {
        let pending = localPending ?? (local?.syncStatusValue == .pending)
        let decision = SyncResolver.decide(
            localExists: local != nil,
            localPending: pending,
            localUpdatedAt: local?.updatedAtValue,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeleted: remoteDeleted
        )
        switch decision {
        case .insert: return .insert
        case .applyRemote: return .upsert(isConflict: false)
        case .keepLocal: return .keepLocal
        case .deleteLocal: return .deleteLocal
        case .conflict: return .upsert(isConflict: true)
        }
    }

    private func fetchSession(_ id: UUID, _ context: ModelContext) throws -> WorkoutSessionEntity? {
        try context.fetch(FetchDescriptor<WorkoutSessionEntity>(predicate: #Predicate { $0.id == id })).first
    }
    private func fetchRoutine(_ id: UUID, _ context: ModelContext) throws -> RoutineEntity? {
        try context.fetch(FetchDescriptor<RoutineEntity>(predicate: #Predicate { $0.id == id })).first
    }
    private func fetchProgram(_ id: UUID, _ context: ModelContext) throws -> ProgramEntity? {
        try context.fetch(FetchDescriptor<ProgramEntity>(predicate: #Predicate { $0.id == id })).first
    }
    private func fetchExercise(_ id: UUID, _ context: ModelContext) throws -> ExerciseEntity? {
        try context.fetch(FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchChildren<C: Decodable>(
        ids: [String], table: String, parentColumn: String, type: C.Type, parentId: (C) -> UUID
    ) async throws -> [UUID: [C]] {
        guard !ids.isEmpty else { return [:] }
        let rows: [C] = try await client.from(table).select().in(parentColumn, values: ids).execute().value
        return Dictionary(grouping: rows, by: parentId)
    }

    private func applySession(_ row: PSession, to session: WorkoutSessionEntity) {
        session.userId = row.user_id
        session.name = row.name
        session.startedAt = row.started_at
        session.endedAt = row.ended_at
        session.routineId = row.routine_id
        session.programDayId = row.program_day_id
        session.note = row.note
        session.updatedAt = row.updated_at
        session.deletedAt = row.deleted_at
    }

    /// The DB stores sets flat (no `workout_exercises` table). Reconstruct the local
    /// session→exercise→set graph by grouping sets by `exercise_id`, preserving the order in
    /// which each exercise first appears (by set number). Superset grouping / per-exercise notes
    /// aren't persisted remotely, so they aren't restored — set data (the load-bearing part) is.
    private func rebuildSets(_ rows: [PSet], on session: WorkoutSessionEntity, context: ModelContext) {
        for workoutExercise in session.exercises { context.delete(workoutExercise) }
        session.exercises.removeAll()
        guard !rows.isEmpty else { return }

        let sorted = rows.sorted { $0.set_number < $1.set_number }
        var order: [UUID: Int] = [:]
        var nextOrder = 0
        var grouped: [UUID: [PSet]] = [:]
        for r in sorted {
            if order[r.exercise_id] == nil { order[r.exercise_id] = nextOrder; nextOrder += 1 }
            grouped[r.exercise_id, default: []].append(r)
        }
        for (exerciseId, sets) in grouped.sorted(by: { (order[$0.key] ?? 0) < (order[$1.key] ?? 0) }) {
            let workoutExercise = WorkoutExerciseEntity(exerciseId: exerciseId, sortOrder: order[exerciseId] ?? 0)
            context.insert(workoutExercise)
            for r in sets {
                let set = WorkoutSetEntity(setNumber: r.set_number, setType: SetType(rawValue: r.set_type) ?? .normal)
                set.id = r.id
                set.weightKg = r.weight_kg
                set.reps = r.reps
                set.durationSeconds = r.duration_seconds
                set.holdSeconds = r.hold_seconds
                set.sideRaw = r.side
                set.rir = r.rir
                set.completedAt = r.completed_at
                set.isCompleted = r.is_completed
                context.insert(set)
                workoutExercise.sets.append(set)
            }
            session.exercises.append(workoutExercise)
        }
    }

    private func rebuildRoutineExercises(_ rows: [PRoutineExercise], on routine: RoutineEntity, context: ModelContext) {
        for item in routine.exercises { context.delete(item) }
        routine.exercises.removeAll()
        for r in rows.sorted(by: { $0.sort_order < $1.sort_order }) {
            let item = RoutineExerciseEntity(
                id: r.id, sortOrder: r.sort_order, exerciseId: r.exercise_id,
                targetSets: r.target_sets, targetRepsMin: r.target_reps_min, targetRepsMax: r.target_reps_max,
                targetDurationSeconds: r.target_duration_seconds, restSeconds: r.rest_seconds,
                progressionEnabled: r.progression_enabled, note: r.note
            )
            item.supersetGroupId = r.superset_group_id
            context.insert(item)
            routine.exercises.append(item)
        }
    }

    private func rebuildProgramDays(_ rows: [PProgramDay], on program: ProgramEntity, context: ModelContext) {
        for day in program.days { context.delete(day) }
        program.days.removeAll()
        for r in rows.sorted(by: { $0.sort_order < $1.sort_order }) {
            let day = ProgramDayEntity(id: r.id, weekIndex: r.week_index, dayOfWeek: r.day_of_week,
                                       routineId: r.routine_id, sortOrder: r.sort_order)
            context.insert(day)
            program.days.append(day)
        }
    }
}

/// Minimal read-only view of the sync-relevant fields so `decide` can treat the four entity
/// types uniformly without a generic `#Predicate` fetch.
protocol HasSyncFields {
    var updatedAtValue: Date? { get }
    var syncStatusValue: SyncStatus? { get }
}
extension WorkoutSessionEntity: HasSyncFields {
    var updatedAtValue: Date? { updatedAt }
    var syncStatusValue: SyncStatus? { syncStatus }
}
extension RoutineEntity: HasSyncFields {
    var updatedAtValue: Date? { updatedAt }
    var syncStatusValue: SyncStatus? { syncStatus }
}
extension ProgramEntity: HasSyncFields {
    var updatedAtValue: Date? { updatedAt }
    var syncStatusValue: SyncStatus? { syncStatus }
}
extension ExerciseEntity: HasSyncFields {
    var updatedAtValue: Date? { updatedAt }
    var syncStatusValue: SyncStatus? { nil }
}

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString)
        else {
            return URL(string: "https://placeholder.supabase.co")!
        }
        return url
    }

    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    static var revenueCatAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
    }
}
