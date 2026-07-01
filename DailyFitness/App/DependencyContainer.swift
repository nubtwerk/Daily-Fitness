import SwiftUI

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .home
    var activeWorkoutSessionId: UUID?
    var showOnboarding: Bool
    /// Bumped when a Live Activity deep link asks the live workout to scroll to
    /// the current set (LOCK-03 / US-062).
    var scrollToCurrentSetToken = 0

    init(showOnboarding: Bool = false) {
        self.showOnboarding = showOnboarding
    }

    func startWorkout(sessionId: UUID) {
        activeWorkoutSessionId = sessionId
    }

    func endWorkout() {
        activeWorkoutSessionId = nil
    }

    /// Open the live workout from a Live Activity tap and request a scroll to the current set.
    func openWorkoutFromDeepLink(sessionId: UUID) {
        activeWorkoutSessionId = sessionId
        scrollToCurrentSetToken += 1
    }
}

@Observable
@MainActor
final class UserSession {
    var localUserId: UUID
    var supabaseUserId: UUID?
    var isAuthenticated: Bool
    var isPro: Bool
    var syncStatus: SyncStatus = .synced

    init(
        localUserId: UUID = UUID(),
        supabaseUserId: UUID? = nil,
        isAuthenticated: Bool = false,
        isPro: Bool = false
    ) {
        self.localUserId = localUserId
        self.supabaseUserId = supabaseUserId
        self.isAuthenticated = isAuthenticated
        self.isPro = isPro
    }

    var effectiveUserId: UUID {
        supabaseUserId ?? localUserId
    }
}

@Observable
@MainActor
final class DependencyContainer {
    var router: AppRouter
    var userSession: UserSession
    let progressionEngine: ProgressionEngineProtocol
    let exerciseSeeder: ExerciseSeeder
    let programSeeder: ProgramSeeder
    let preferencesRepository: UserPreferencesRepository
    let exerciseRepository: ExerciseRepository
    let progressionService: ProgressionService
    let prService: PRService
    let analyticsService: AnalyticsService
    let workoutCoordinator: WorkoutSessionCoordinator
    let syncEngine: SyncEngine
    let authService: AuthService
    let revenueCatService: RevenueCatService

    init(
        router: AppRouter,
        userSession: UserSession,
        progressionEngine: ProgressionEngineProtocol,
        exerciseSeeder: ExerciseSeeder,
        programSeeder: ProgramSeeder,
        preferencesRepository: UserPreferencesRepository,
        exerciseRepository: ExerciseRepository,
        progressionService: ProgressionService,
        prService: PRService,
        analyticsService: AnalyticsService,
        workoutCoordinator: WorkoutSessionCoordinator,
        syncEngine: SyncEngine,
        authService: AuthService,
        revenueCatService: RevenueCatService
    ) {
        self.router = router
        self.userSession = userSession
        self.progressionEngine = progressionEngine
        self.exerciseSeeder = exerciseSeeder
        self.programSeeder = programSeeder
        self.preferencesRepository = preferencesRepository
        self.exerciseRepository = exerciseRepository
        self.progressionService = progressionService
        self.prService = prService
        self.analyticsService = analyticsService
        self.workoutCoordinator = workoutCoordinator
        self.syncEngine = syncEngine
        self.authService = authService
        self.revenueCatService = revenueCatService
    }

    static func makeDefault() -> DependencyContainer {
        let userSession = UserSession()
        let progressionEngine = ProgressionEngine()
        let preferencesRepository = UserPreferencesRepository()
        let exerciseRepository = ExerciseRepository()
        let progressionService = ProgressionService(engine: progressionEngine)
        let prService = PRService()
        let analyticsService = AnalyticsService()
        let syncEngine = SyncEngine()
        let authService = AuthService(userSession: userSession, syncEngine: syncEngine)
        let revenueCatService = RevenueCatService(userSession: userSession)
        let workoutCoordinator = WorkoutSessionCoordinator(
            syncEngine: syncEngine,
            prService: prService,
            progressionService: progressionService,
            preferencesRepository: preferencesRepository
        )

        return DependencyContainer(
            router: AppRouter(
                showOnboarding: !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            ),
            userSession: userSession,
            progressionEngine: progressionEngine,
            exerciseSeeder: ExerciseSeeder(),
            programSeeder: ProgramSeeder(),
            preferencesRepository: preferencesRepository,
            exerciseRepository: exerciseRepository,
            progressionService: progressionService,
            prService: prService,
            analyticsService: analyticsService,
            workoutCoordinator: workoutCoordinator,
            syncEngine: syncEngine,
            authService: authService,
            revenueCatService: revenueCatService
        )
    }
}
