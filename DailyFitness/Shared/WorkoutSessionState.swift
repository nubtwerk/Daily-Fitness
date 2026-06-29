import Foundation

enum WorkoutSessionState {
    private static let sessionKey = "activeWorkoutSession"

    struct Snapshot: Codable {
        var sessionId: UUID
        var workoutName: String
        var exerciseName: String
        var setCurrent: Int
        var setTotal: Int
        var phase: WorkoutPhase
        var restEndsAt: Date?
    }

    static func save(snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults?.set(data, forKey: sessionKey)
    }

    static func load() -> Snapshot? {
        guard let data = AppGroup.defaults?.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func clear() {
        AppGroup.defaults?.removeObject(forKey: sessionKey)
    }
}
