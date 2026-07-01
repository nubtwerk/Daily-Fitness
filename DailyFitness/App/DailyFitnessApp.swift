import SwiftUI
import SwiftData

@main
struct DailyFitnessApp: App {
    @State private var dependencies = DependencyContainer.makeDefault()
    @State private var seedingState = SeedingState()
    @Environment(\.scenePhase) private var scenePhase
    private let sharedModelContainer = ModelContainerFactory.make()

    init() {
        // Brand the system nav/tab bars before any UIKit view exists (no flash).
        AppearanceConfigurator.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies, seedingState: seedingState)
                .modelContainer(sharedModelContainer)
                .task {
                    CrashDiagnosticsService.shared.start()
                    dependencies.revenueCatService.configure()
                    let context = sharedModelContainer.mainContext
                    dependencies.syncEngine.startMonitoring(context: context)
                    do {
                        try dependencies.exerciseSeeder.seedIfNeeded(context: context, state: seedingState)
                        let allExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                        try RoutineSeeder().seedSuggestedIfNeeded(context: context, exercises: allExercises)
                        let routines = try context.fetch(FetchDescriptor<RoutineEntity>())
                        try dependencies.programSeeder.seedIfNeeded(context: context, routines: routines)
                    } catch {
                        AppLog.seeding.error("Seeding failed: \(String(describing: error), privacy: .public)")
                        dependencies.errorPresenter.present(
                            title: "Some content didn’t load",
                            message: "We couldn’t finish setting up your exercise library and programs. Restart the app to try again."
                        )
                    }
                    await dependencies.authService.restoreSession()
                    do {
                        // Flush local changes before pulling so our edits win where appropriate.
                        try await dependencies.syncEngine.flush(context: context)
                        try await dependencies.syncEngine.pullRemoteChanges(context: context)
                    } catch {
                        AppLog.sync.error("Initial sync failed: \(String(describing: error), privacy: .public)")
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            let context = sharedModelContainer.mainContext
                            do {
                                try await dependencies.syncEngine.flush(context: context)
                            } catch {
                                AppLog.sync.error("Foreground sync flush failed: \(String(describing: error), privacy: .public)")
                            }
                        }
                    }
                }
                .onOpenURL { url in
                    // Live Activity tap fallback (LOCK-03 / US-062). The `dailyfitness`
                    // scheme is registered in CFBundleURLTypes (project.yml) so the tap
                    // reliably routes here and opens the active workout's current set.
                    if let sessionId = WorkoutDeepLink.sessionId(from: url) {
                        dependencies.router.openWorkoutFromDeepLink(sessionId: sessionId)
                    }
                }
        }
    }
}

enum ModelContainerFactory {
    static func make() -> ModelContainer {
        let schema = Schema(DailyFitnessSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLog.app.error("SwiftData container failed (\(String(describing: error), privacy: .public)). Retrying in-memory store.")
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}

struct RootView: View {
    let dependencies: DependencyContainer
    let seedingState: SeedingState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Group {
                if dependencies.router.showOnboarding {
                    OnboardingView(dependencies: dependencies)
                } else {
                    MainTabView(dependencies: dependencies)
                }
            }
            .background(Color.dfBackground)

            if seedingState.isSeeding {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: CalmStrength.Spacing.md) {
                    ProgressView()
                    Text(seedingState.message)
                        .dfFont(.callout)
                        .foregroundStyle(.white)
                }
                .padding(CalmStrength.Spacing.lg)
                .background(Color.dfPrimary.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous))
            }
        }
        .dfErrorAlert(dependencies.errorPresenter)
        #if DEBUG
        .onAppear(perform: applyUITestLaunchArgumentsIfNeeded)
        #endif
    }

    #if DEBUG
    /// Lets QA/screenshot tooling jump straight to a screen via `simctl launch` args,
    /// e.g. `-uitestSkipOnboarding YES -uitestTab progress -uitestPro YES`. Debug-only.
    private func applyUITestLaunchArgumentsIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "uitestSkipOnboarding") {
            dependencies.router.showOnboarding = false
        }
        if defaults.bool(forKey: "uitestPro") {
            dependencies.userSession.isPro = true
        }
        switch defaults.string(forKey: "uitestTab") {
        case "home": dependencies.router.selectedTab = .home
        case "programs": dependencies.router.selectedTab = .programs
        case "progress": dependencies.router.selectedTab = .progress
        case "profile": dependencies.router.selectedTab = .profile
        default: break
        }
        if defaults.bool(forKey: "uitestBlankWorkout") {
            let session = WorkoutSessionEntity(
                userId: dependencies.userSession.effectiveUserId,
                name: "Session"
            )
            modelContext.insert(session)
            modelContext.saveOrLog("uitestBlankWorkout")
            dependencies.router.startWorkout(sessionId: session.id)
        }
    }
    #endif
}
