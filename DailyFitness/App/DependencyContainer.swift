import SwiftUI

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .home
    var activeWorkoutSessionId: UUID?
    var showOnboarding: Bool

    init(showOnboarding: Bool = false) {
        self.showOnboarding = showOnboarding
    }

    func startWorkout(sessionId: UUID) {
        activeWorkoutSessionId = sessionId
    }

    func endWorkout() {
        activeWorkoutSessionId = nil
    }
}

@Observable
@MainActor
final class UserSession {
    var localUserId: UUID
    var isAuthenticated: Bool
    var isPro: Bool

    init(localUserId: UUID = UUID(), isAuthenticated: Bool = false, isPro: Bool = false) {
        self.localUserId = localUserId
        self.isAuthenticated = isAuthenticated
        self.isPro = isPro
    }
}

@Observable
@MainActor
final class DependencyContainer {
    var router: AppRouter
    var userSession: UserSession
    let progressionEngine: ProgressionEngineProtocol
    let exerciseSeeder: ExerciseSeeder

    init(
        router: AppRouter,
        userSession: UserSession,
        progressionEngine: ProgressionEngineProtocol,
        exerciseSeeder: ExerciseSeeder
    ) {
        self.router = router
        self.userSession = userSession
        self.progressionEngine = progressionEngine
        self.exerciseSeeder = exerciseSeeder
    }

    static func makeDefault() -> DependencyContainer {
        DependencyContainer(
            router: AppRouter(
                showOnboarding: !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            ),
            userSession: UserSession(),
            progressionEngine: ProgressionEngine(),
            exerciseSeeder: ExerciseSeeder()
        )
    }
}
