import SwiftUI
import SwiftData

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

@main
struct DailyFitnessApp: App {
    @State private var dependencies = DependencyContainer.makeDefault()
    private let sharedModelContainer = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .modelContainer(sharedModelContainer)
                .task {
                    let context = sharedModelContainer.mainContext
                    do {
                        try dependencies.exerciseSeeder.seedIfNeeded(context: context)
                    } catch {
                        print("ExerciseSeeder failed: \(error)")
                    }
                }
        }
    }
}

struct RootView: View {
    let dependencies: DependencyContainer

    var body: some View {
        Group {
            if dependencies.router.showOnboarding {
                OnboardingView(dependencies: dependencies)
            } else {
                MainTabView(dependencies: dependencies)
            }
        }
        .background(Color.dfBackground)
    }
}
