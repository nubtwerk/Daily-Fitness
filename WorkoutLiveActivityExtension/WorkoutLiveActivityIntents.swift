import AppIntents
import Foundation

struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Set"

    func perform() async throws -> some IntentResult {
        WorkoutIntentBridge.post(.completeSet)
        return .result()
    }
}

struct ExtendRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Extend Rest"

    func perform() async throws -> some IntentResult {
        WorkoutIntentBridge.post(.extendRest)
        return .result()
    }
}

struct EndWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Workout"

    func perform() async throws -> some IntentResult {
        WorkoutIntentBridge.post(.endWorkout)
        return .result()
    }
}
