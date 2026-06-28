import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineEntity.name) private var routines: [RoutineEntity]
    @Query(filter: #Predicate<WorkoutSessionEntity> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSessionEntity]

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    if let active = activeSessions.first {
                        DFCard {
                            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                                Text("Workout in progress")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dfSecondaryText)
                                Text(active.name)
                                    .font(.title2.weight(.semibold))
                                DFPrimaryButton(title: "Continue") {
                                    dependencies.router.startWorkout(sessionId: active.id)
                                }
                            }
                        }
                    }

                    DFSectionHeader(title: "Quick start")

                    if routines.isEmpty {
                        DFEmptyState(
                            title: "No routines yet",
                            message: "Create a routine in Programs or start a blank workout."
                        )
                    } else {
                        ForEach(routines.prefix(5), id: \.id) { routine in
                            Button {
                                startRoutine(routine)
                            } label: {
                                DFCard {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(routine.name)
                                                .font(.headline)
                                                .foregroundStyle(Color.dfPrimary)
                                            Text("\(routine.exercises.count) exercises")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.dfSecondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.dfAccent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DFSecondaryButton(title: "Blank workout") {
                        startBlankWorkout()
                    }
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("DailyFitness")
        }
    }

    private func startRoutine(_ routine: RoutineEntity) {
        let session = WorkoutSessionEntity(
            userId: dependencies.userSession.localUserId,
            name: routine.name,
            routineId: routine.id
        )

        for routineExercise in routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            WorkoutExerciseFactory.addFromRoutineExercise(routineExercise, to: session, in: modelContext)
        }

        modelContext.insert(session)
        try? modelContext.save()
        dependencies.router.startWorkout(sessionId: session.id)
    }

    private func startBlankWorkout() {
        let session = WorkoutSessionEntity(
            userId: dependencies.userSession.localUserId,
            name: "Workout"
        )
        modelContext.insert(session)
        try? modelContext.save()
        dependencies.router.startWorkout(sessionId: session.id)
    }
}
