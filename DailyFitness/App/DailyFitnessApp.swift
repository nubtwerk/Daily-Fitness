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
        CalmStrength.configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies, seedingState: seedingState)
                .modelContainer(sharedModelContainer)
                .task {
                    dependencies.revenueCatService.configure()
                    let context = sharedModelContainer.mainContext
                    dependencies.syncEngine.startMonitoring(context: context)
                    do {
                        let exercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                        try dependencies.exerciseSeeder.seedIfNeeded(context: context, state: seedingState)
                        let allExercises = try context.fetch(FetchDescriptor<ExerciseEntity>())
                        try RoutineSeeder().seedSuggestedIfNeeded(context: context, exercises: allExercises)
                        let routines = try context.fetch(FetchDescriptor<RoutineEntity>())
                        try dependencies.programSeeder.seedIfNeeded(context: context, routines: routines)
                    } catch {
                        print("Seeding failed: \(error)")
                    }
                    await dependencies.authService.restoreSession()
                    try? await dependencies.syncEngine.pullRemoteChanges(since: nil, context: context)
                    try? await dependencies.syncEngine.flush(context: context)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            let context = sharedModelContainer.mainContext
                            try? await dependencies.syncEngine.flush(context: context)
                        }
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
            print("SwiftData container failed (\(error)). Retrying in-memory store.")
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
                .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md))
            }
        }
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
            try? modelContext.save()
            dependencies.router.startWorkout(sessionId: session.id)
        }
    }
    #endif
}
