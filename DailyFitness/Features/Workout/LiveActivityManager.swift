import ActivityKit
import Foundation
import SwiftData

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutAttributes>?
    private var liveActivitiesEnabled = true

    private init() {}

    func setEnabled(_ enabled: Bool) {
        liveActivitiesEnabled = enabled
        if !enabled { end() }
    }

    func start(sessionName: String, sessionId: UUID, exerciseName: String, setCurrent: Int, setTotal: Int) {
        guard liveActivitiesEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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

    func update(
        session: WorkoutSessionEntity,
        exerciseLookup: (UUID) -> String,
        phase: WorkoutPhase,
        restEndsAt: Date?
    ) {
        guard liveActivitiesEnabled, let activity else { return }

        let sortedExercises = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
        let currentExercise = sortedExercises.first { exercise in
            exercise.sets.contains { !$0.isCompleted }
        } ?? sortedExercises.first

        guard let currentExercise else { return }

        let sets = currentExercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
        let completedCount = sets.filter(\.isCompleted).count
        let exerciseName = exerciseLookup(currentExercise.exerciseId)

        let state = WorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            setCurrent: min(completedCount + 1, max(sets.count, 1)),
            setTotal: max(sets.count, 1),
            phase: phase,
            restEndsAt: restEndsAt,
            sessionId: session.id
        )

        WorkoutSessionState.save(snapshot: WorkoutSessionState.Snapshot(
            sessionId: session.id,
            workoutName: session.name,
            exerciseName: exerciseName,
            setCurrent: min(completedCount + 1, max(sets.count, 1)),
            setTotal: max(sets.count, 1),
            phase: phase,
            restEndsAt: restEndsAt
        ))

        Task {
            await activity.update(.init(state: state, staleDate: restEndsAt))
        }
    }

    func end() {
        guard let activity else { return }
        WorkoutSessionState.clear()
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}

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
