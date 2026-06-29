import Foundation

enum WorkoutIntentAction: String, Codable {
    case completeSet
    case extendRest
    case endWorkout
}

enum WorkoutIntentBridge {
    private static let actionKey = "pendingWorkoutIntentAction"
    static let darwinNotificationName = "app.dailybase.dailyfitness.workoutIntent" as CFString

    static func post(_ action: WorkoutIntentAction) {
        AppGroup.defaults?.set(action.rawValue, forKey: actionKey)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            darwinNotificationName,
            nil,
            nil,
            true
        )
    }

    static func consumePendingAction() -> WorkoutIntentAction? {
        guard let raw = AppGroup.defaults?.string(forKey: actionKey),
              let action = WorkoutIntentAction(rawValue: raw) else { return nil }
        AppGroup.defaults?.removeObject(forKey: actionKey)
        return action
    }
}

extension Notification.Name {
    static let workoutCompleteSet = Notification.Name("workoutCompleteSet")
    static let workoutExtendRest = Notification.Name("workoutExtendRest")
    static let workoutEnd = Notification.Name("workoutEnd")
    static let workoutIntentFromExtension = Notification.Name("workoutIntentFromExtension")
}
