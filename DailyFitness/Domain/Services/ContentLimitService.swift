import Foundation

enum ContentLimitService {
    static let maxFreeCustomExercises = 20
    static let maxFreeRoutines = 5
    static let maxFreePrograms = 5
    static let maxFreeProgressionExercises = 2

    static func canCreateCustomExercise(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < maxFreeCustomExercises
    }

    static func canCreateRoutine(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < maxFreeRoutines
    }

    static func canCreateProgram(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < maxFreePrograms
    }

    static func canShowProgression(forStrengthIndex index: Int, isPro: Bool) -> Bool {
        isPro || index < maxFreeProgressionExercises
    }
}
