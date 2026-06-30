import Foundation
import Network
import Supabase
import SwiftData

@MainActor
final class SyncEngine {
    enum SyncOperation: Sendable, Codable, Equatable {
        case upsertSession(UUID)
        case upsertRoutine(UUID)
        case upsertProgram(UUID)
        case upsertExercise(UUID)
        case deleteEntity(UUID)
    }

    private static let queueDefaultsKey = "app.dailybase.dailyfitness.syncQueue"

    private var queue: [SyncOperation] = [] {
        didSet { persistQueue() }
    }
    private(set) var isAuthenticated = false
    private(set) var isOnline = true
    private var isFlushing = false
    private var pathMonitor: NWPathMonitor?
    private weak var monitoredContext: ModelContext?

    init() {
        queue = loadPersistedQueue()
    }

    private var client: SupabaseClient {
        SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
    }

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

    var pendingCount: Int { queue.count }

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
                case .deleteEntity(let id):
                    try await deleteEntity(id: id)
                }
            } catch {
                retry.append(operation)
            }
        }

        queue.insert(contentsOf: retry, at: 0)
    }

    func pullRemoteChanges(since: Date?, context: ModelContext) async throws {
        guard isAuthenticated, isOnline else { return }

        struct SessionRow: Decodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let started_at: Date
            let ended_at: Date?
            let routine_id: UUID?
            let program_day_id: UUID?
            let note: String?
        }

        let rows: [SessionRow] = try await client
            .from("workout_sessions")
            .select()
            .order("started_at", ascending: false)
            .limit(100)
            .execute()
            .value

        let existingIds = Set(try context.fetch(FetchDescriptor<WorkoutSessionEntity>()).map(\.id))

        for row in rows {
            guard !existingIds.contains(row.id) else { continue }
            if let since, row.started_at < since { continue }
            let session = WorkoutSessionEntity(
                id: row.id,
                userId: row.user_id,
                name: row.name,
                routineId: row.routine_id
            )
            session.startedAt = row.started_at
            session.endedAt = row.ended_at
            session.programDayId = row.program_day_id
            session.note = row.note
            session.syncStatus = .synced
            context.insert(session)
        }
        try context.save()
    }

    private func upsertSession(id: UUID, context: ModelContext) async throws {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let session = try context.fetch(descriptor).first else { return }

        struct SessionRow: Encodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let started_at: Date
            let ended_at: Date?
            let routine_id: UUID?
            let program_day_id: UUID?
            let note: String?
        }

        let row = SessionRow(
            id: session.id,
            user_id: session.userId,
            name: session.name,
            started_at: session.startedAt,
            ended_at: session.endedAt,
            routine_id: session.routineId,
            program_day_id: session.programDayId,
            note: session.note
        )

        try await client.from("workout_sessions").upsert(row).execute()

        struct SetRow: Encodable {
            let id: UUID
            let user_id: UUID
            let session_id: UUID
            let exercise_id: UUID
            let set_number: Int
            let set_type: String
            let weight_kg: Double?
            let reps: Int?
            let duration_seconds: Int?
            let hold_seconds: Int?
            let side: String?
            let rir: Int?
            let completed_at: Date?
            let is_completed: Bool
        }

        // NOTE: there is no workout_exercises table in the sync payload yet, so a live
        // session's per-exercise note / supersetGroupId / restSecondsOverride are
        // local-only here. For routine-based sessions the note is mirrored onto the
        // routine (see WorkoutSessionCoordinator.persistExerciseNotesToRoutine) and
        // synced via routine_exercises. A dedicated workout_exercises sync is Phase E.
        var setRows: [SetRow] = []
        for workoutExercise in session.exercises {
            for set in workoutExercise.sets {
                setRows.append(SetRow(
                    id: set.id,
                    user_id: session.userId,
                    session_id: session.id,
                    exercise_id: workoutExercise.exerciseId,
                    set_number: set.setNumber,
                    set_type: set.setTypeRaw,
                    weight_kg: set.weightKg,
                    reps: set.reps,
                    duration_seconds: set.durationSeconds,
                    hold_seconds: set.holdSeconds,
                    side: set.sideRaw,
                    rir: set.rir,
                    completed_at: set.completedAt,
                    is_completed: set.isCompleted
                ))
            }
        }

        if !setRows.isEmpty {
            try await client.from("workout_sets").upsert(setRows).execute()
        }

        session.syncStatus = .synced
        try context.save()
    }

    private func upsertRoutine(id: UUID, context: ModelContext) async throws {
        let descriptor = FetchDescriptor<RoutineEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let routine = try context.fetch(descriptor).first else { return }

        struct RoutineRow: Encodable {
            let id: UUID
            let user_id: UUID
            let name: String
        }

        try await client.from("routines").upsert(
            RoutineRow(id: routine.id, user_id: routine.userId, name: routine.name)
        ).execute()

        struct RoutineExerciseRow: Encodable {
            let id: UUID
            let routine_id: UUID
            let user_id: UUID
            let sort_order: Int
            let exercise_id: UUID
            let target_sets: Int
            let target_reps_min: Int?
            let target_reps_max: Int?
            let target_duration_seconds: Int?
            let rest_seconds: Int
            let superset_group_id: UUID?
            let progression_enabled: Bool
            let note: String?
        }

        let rows = routine.exercises.map { item in
            RoutineExerciseRow(
                id: item.id,
                routine_id: routine.id,
                user_id: routine.userId,
                sort_order: item.sortOrder,
                exercise_id: item.exerciseId,
                target_sets: item.targetSets,
                target_reps_min: item.targetRepsMin,
                target_reps_max: item.targetRepsMax,
                target_duration_seconds: item.targetDurationSeconds,
                rest_seconds: item.restSeconds,
                superset_group_id: item.supersetGroupId,
                progression_enabled: item.progressionEnabled,
                note: item.note
            )
        }

        if !rows.isEmpty {
            try await client.from("routine_exercises").upsert(rows).execute()
        }

        routine.syncStatus = .synced
        try context.save()
    }

    private func upsertProgram(id: UUID, context: ModelContext) async throws {
        let descriptor = FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let program = try context.fetch(descriptor).first else { return }

        struct ProgramRow: Encodable {
            let id: UUID
            let user_id: UUID?
            let name: String
            let category: String
            let is_suggested: Bool
            let weeks: Int?
            let is_active: Bool
        }

        try await client.from("programs").upsert(
            ProgramRow(
                id: program.id,
                user_id: program.userId,
                name: program.name,
                category: program.categoryRaw,
                is_suggested: program.isSuggested,
                weeks: program.weeks,
                is_active: program.isActive
            )
        ).execute()
        program.syncStatus = .synced
        try context.save()
    }

    private func upsertExercise(id: UUID, context: ModelContext) async throws {
        let descriptor = FetchDescriptor<ExerciseEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let exercise = try context.fetch(descriptor).first, exercise.isCustom else { return }

        struct ExerciseRow: Encodable {
            let id: UUID
            let user_id: UUID?
            let name: String
            let category: String
            let primary_muscles: [String]
            let equipment: [String]
            let image_url: String?
            let is_custom: Bool
            let logging_fields: String
        }

        try await client.from("exercises").upsert(
            ExerciseRow(
                id: exercise.id,
                user_id: exercise.userId,
                name: exercise.name,
                category: exercise.categoryRaw,
                primary_muscles: exercise.primaryMuscles,
                equipment: exercise.equipment,
                image_url: exercise.imageURL,
                is_custom: true,
                logging_fields: exercise.loggingFieldsRaw
            )
        ).execute()
    }

    private func deleteEntity(id: UUID) async throws {
        try await client.from("workout_sessions").delete().eq("id", value: id.uuidString).execute()
    }
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
