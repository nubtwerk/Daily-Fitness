import SwiftUI
import SwiftData

struct HomeView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineEntity.name) private var allRoutines: [RoutineEntity]
    @Query(filter: #Predicate<WorkoutSessionEntity> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSessionEntity]
    @Query(filter: #Predicate<ProgramEntity> { $0.isActive == true })
    private var activePrograms: [ProgramEntity]

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    /// User-created routines for Quick start; seeded program-building routines are hidden.
    private var routines: [RoutineEntity] {
        allRoutines.filter { !$0.isSuggested && $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    if let active = activeSessions.first {
                        DFCard {
                            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                                Text("Session in progress")
                                    .dfFont(.callout)
                                    .foregroundStyle(Color.dfSecondaryText)
                                Text(active.name)
                                    .dfFont(.heading)
                                DFPrimaryButton(title: "Continue") {
                                    dependencies.router.startWorkout(sessionId: active.id)
                                }
                            }
                        }
                    }

                    todayProgramCard

                    DFSectionHeader(title: "Quick start")

                    if routines.isEmpty {
                        DFEmptyState(
                            title: "No routines yet",
                            message: "Create a routine in Programs or start a blank session."
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
                                                .dfFont(.subheading)
                                                .foregroundStyle(Color.dfPrimary)
                                            Text("\(routine.exercises.count) exercises")
                                                .dfFont(.callout)
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

                    DFSecondaryButton(title: "Blank session") {
                        startBlankWorkout()
                    }
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("DailyFitness")
        }
    }

    @ViewBuilder
    private var todayProgramCard: some View {
        // Resolve against ALL routines: an active program's days may reference seeded
        // (suggested) routines that are hidden from the Quick-start list.
        if let program = activePrograms.first,
           let match = ProgramScheduleResolver.routineForToday(
               program: program,
               routines: allRoutines.filter { $0.deletedAt == nil }
           ) {
            let (today, routine) = match
            DFCard {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                    Text("Today's session")
                        .dfFont(.callout)
                        .foregroundStyle(Color.dfSecondaryText)
                    Text(routine.name)
                        .dfFont(.heading)
                    Text(program.name)
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                    DFPrimaryButton(title: "Start") {
                        startRoutine(routine, programDayId: today.id)
                    }
                }
            }
        }
    }

    private func startRoutine(_ routine: RoutineEntity, programDayId: UUID? = nil) {
        let session = WorkoutSessionEntity(
            userId: dependencies.userSession.effectiveUserId,
            name: routine.name,
            routineId: routine.id
        )
        session.programDayId = programDayId

        let exerciseDescriptor = FetchDescriptor<ExerciseEntity>()
        let allExercises = (try? modelContext.fetch(exerciseDescriptor)) ?? []

        for routineExercise in routine.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let exercise = allExercises.first(where: { $0.id == routineExercise.exerciseId })
            _ = WorkoutExerciseFactory.addFromRoutineExercise(
                routineExercise,
                to: session,
                in: modelContext,
                category: exercise?.category ?? .strength,
                loggingFields: exercise?.loggingFields ?? .weightReps
            )
        }

        modelContext.insert(session)
        // Recommendations stay advisory: surfaced in the live workout as an accept/edit/ignore
        // banner (US-080) alongside non-destructive ghost placeholders (US-051) — set weights
        // are never silently pre-written at session start.
        try? modelContext.save()
        dependencies.syncEngine.enqueue(.upsertSession(session.id))
        dependencies.router.startWorkout(sessionId: session.id)
    }

    private func startBlankWorkout() {
        let session = WorkoutSessionEntity(
            userId: dependencies.userSession.effectiveUserId,
            name: "Session"
        )
        modelContext.insert(session)
        try? modelContext.save()
        dependencies.router.startWorkout(sessionId: session.id)
    }
}
