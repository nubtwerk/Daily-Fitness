import SwiftUI

struct MainTabView: View {
    @Bindable var dependencies: DependencyContainer

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    var body: some View {
        TabView(selection: $dependencies.router.selectedTab) {
            HomeView(dependencies: dependencies)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            ExerciseLibraryView(dependencies: dependencies)
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)

            ProgramsView(dependencies: dependencies)
                .tabItem { Label("Programs", systemImage: "calendar") }
                .tag(AppTab.programs)

            ProgressTabView(dependencies: dependencies)
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)

            ProfileView(dependencies: dependencies)
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTab.profile)
        }
        .tint(Color.dfAccent) // sage selected tab — the single-accent rule (DSS §6.8 / §9)
        .fullScreenCover(isPresented: workoutPresented) {
            if let sessionId = dependencies.router.activeWorkoutSessionId {
                LiveWorkoutView(sessionId: sessionId, dependencies: dependencies)
                    // The live workout is a separate presentation context; the app-root alert
                    // can't present over it, so surface save failures from inside the cover too.
                    .dfErrorAlert(dependencies.errorPresenter)
            }
        }
    }

    private var workoutPresented: Binding<Bool> {
        Binding(
            get: { dependencies.router.activeWorkoutSessionId != nil },
            set: { isPresented in
                if !isPresented {
                    dependencies.router.activeWorkoutSessionId = nil
                }
            }
        )
    }
}
