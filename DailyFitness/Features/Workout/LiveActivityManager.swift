import ActivityKit
import Foundation

struct WorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setCurrent: Int
        var setTotal: Int
        var phase: WorkoutPhase
        var restEndsAt: Date?
        var sessionId: UUID
    }

    var workoutName: String
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutAttributes>?

    private init() {}

    func start(sessionName: String, sessionId: UUID, exerciseName: String, setCurrent: Int, setTotal: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutAttributes(workoutName: sessionName)
        let state = WorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            setCurrent: setCurrent,
            setTotal: setTotal,
            phase: .active,
            restEndsAt: nil,
            sessionId: sessionId
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func update(session: WorkoutSessionEntity, phase: WorkoutPhase, restEndsAt: Date?) {
        guard let activity else { return }

        let currentExercise = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).first
        let sets = currentExercise?.sets.sorted(by: { $0.setNumber < $1.setNumber }) ?? []
        let completedCount = sets.filter(\.isCompleted).count
        let exerciseName = "Exercise"

        let state = WorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            setCurrent: min(completedCount + 1, max(sets.count, 1)),
            setTotal: max(sets.count, 1),
            phase: phase,
            restEndsAt: restEndsAt,
            sessionId: session.id
        )

        Task {
            await activity.update(.init(state: state, staleDate: restEndsAt))
        }
    }

    func end() {
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
