import SwiftUI
import SwiftData

struct LiveWorkoutView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Environment(\.scenePhase) private var scenePhase

    let sessionId: UUID

    @Query private var sessions: [WorkoutSessionEntity]
    @Query private var exercises: [ExerciseEntity]
    @Query private var preferences: [UserPreferencesEntity]

    @State private var restEndsAt: Date?
    @State private var showEndConfirmation = false
    @State private var showExercisePicker = false
    @State private var recentPRs: [PersonalRecord] = []

    init(sessionId: UUID, dependencies: DependencyContainer) {
        self.sessionId = sessionId
        self._dependencies = Bindable(wrappedValue: dependencies)
        _sessions = Query(filter: #Predicate<WorkoutSessionEntity> { $0.id == sessionId })
    }

    private var session: WorkoutSessionEntity? { sessions.first }

    private var userPrefs: UserPreferencesEntity? {
        preferences.first(where: { $0.userId == dependencies.userSession.effectiveUserId })
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    workoutContent(session)
                } else {
                    ProgressView()
                }
            }
            .background(Color.dfBackground)
            .navigationTitle(session?.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismissWorkout() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: CalmStrength.Spacing.md) {
                        Button {
                            showExercisePicker = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button("Finish") { showEndConfirmation = true }
                    }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(
                    dependencies: dependencies,
                    excludeIds: Set(sessions.first?.exercises.map(\.exerciseId) ?? []),
                    onSelect: { exercise in
                        guard let session = sessions.first else { return }
                        addExercise(exercise, to: session)
                    }
                )
            }
            .confirmationDialog("Finish workout?", isPresented: $showEndConfirmation) {
                Button("Save workout") { finishWorkout() }
                Button("Discard", role: .destructive) { discardWorkout() }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                WorkoutIntentObserver.shared.start { action in
                    processIntentAction(action)
                }
                if let session {
                    dependencies.workoutCoordinator.startLiveActivityIfEnabled(
                        session: session,
                        userId: dependencies.userSession.effectiveUserId,
                        context: modelContext
                    )
                }
                if let action = WorkoutIntentBridge.consumePendingAction() {
                    processIntentAction(action)
                }
            }
            .onDisappear {
                WorkoutIntentObserver.shared.stop()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, let action = WorkoutIntentBridge.consumePendingAction() {
                    processIntentAction(action)
                }
            }
            .overlay(alignment: .top) {
                if !recentPRs.isEmpty {
                    PRToastView(records: recentPRs)
                        .padding(.top, CalmStrength.Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { recentPRs = [] }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: recentPRs.count)
        }
    }

    @ViewBuilder
    private func workoutContent(_ session: WorkoutSessionEntity) -> some View {
        ScrollView {
            VStack(spacing: CalmStrength.Spacing.md) {
                if let restEndsAt, restEndsAt > Date() {
                    RestTimerBanner(restEndsAt: restEndsAt) {
                        self.restEndsAt = restEndsAt.addingTimeInterval(30)
                    }
                }

                if session.exercises.isEmpty {
                    DFEmptyState(
                        title: "No exercises yet",
                        message: "Add exercises from the library to start logging sets.",
                        actionTitle: "Add exercise"
                    ) {
                        showExercisePicker = true
                    }
                } else {
                    ForEach(Array(session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated()), id: \.element.id) { index, workoutExercise in
                        exerciseCard(
                            workoutExercise: workoutExercise,
                            strengthIndex: strengthIndex(upTo: index, in: session),
                            session: session
                        )
                    }
                }
            }
            .padding(CalmStrength.Spacing.md)
        }
    }

    @ViewBuilder
    private func exerciseCard(
        workoutExercise: WorkoutExerciseEntity,
        strengthIndex: Int,
        session: WorkoutSessionEntity
    ) -> some View {
        let exercise = exercises.first(where: { $0.id == workoutExercise.exerciseId })
        let loggingFields = exercise?.loggingFields ?? .weightReps
        let usePounds = userPrefs?.usePounds ?? false
        let rirEnabled = userPrefs?.rirEnabled ?? false
        let showProgression = exercise?.category == .strength
            && ContentLimitService.canShowProgression(forStrengthIndex: strengthIndex, isPro: dependencies.userSession.isPro)

        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                Text(exercise?.name ?? "Exercise")
                    .dfFont(.subheading)
                    .foregroundStyle(Color.dfPrimary)

                if showProgression {
                    ProgressionBanner(
                        recommendation: dependencies.progressionService.latestRecommendation(
                            exerciseId: workoutExercise.exerciseId,
                            userId: dependencies.userSession.effectiveUserId,
                            context: modelContext
                        ),
                        usePounds: usePounds
                    )
                }

                ForEach(workoutExercise.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                    SetRowFactory.row(
                        for: set,
                        loggingFields: loggingFields,
                        usePounds: usePounds,
                        rirEnabled: rirEnabled,
                        onComplete: {
                            completeSet(set, workoutExercise: workoutExercise, session: session, exercise: exercise)
                        }
                    )
                }
            }
        }
    }

    private func strengthIndex(upTo index: Int, in session: WorkoutSessionEntity) -> Int {
        let sorted = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
        return sorted.prefix(index + 1).filter { item in
            exercises.first(where: { $0.id == item.exerciseId })?.category == .strength
        }.count - 1
    }

    private func addExercise(_ exercise: ExerciseEntity, to session: WorkoutSessionEntity) {
        _ = WorkoutExerciseFactory.addExercise(exercise, to: session, in: modelContext)
        session.syncStatus = .pending
        try? modelContext.save()
    }

    private func completeSet(
        _ set: WorkoutSetEntity,
        workoutExercise: WorkoutExerciseEntity,
        session: WorkoutSessionEntity,
        exercise: ExerciseEntity?
    ) {
        let prs = dependencies.workoutCoordinator.completeSet(
            set,
            workoutExercise: workoutExercise,
            session: session,
            exercise: exercise,
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        if !prs.isEmpty {
            recentPRs = prs
        }

        let prefs = dependencies.preferencesRepository.loadOrCreate(
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        if exercise?.category == .strength, prefs.defaultRestSeconds > 0 {
            restEndsAt = Date().addingTimeInterval(TimeInterval(prefs.defaultRestSeconds))
        }
    }

    private func finishWorkout() {
        guard let session else { return }
        dependencies.workoutCoordinator.finishSession(
            session,
            userId: dependencies.userSession.effectiveUserId,
            isPro: dependencies.userSession.isPro,
            context: modelContext
        )
        dependencies.router.endWorkout()
        dismiss()
    }

    private func discardWorkout() {
        guard let session else { return }
        dependencies.workoutCoordinator.discardSession(session, context: modelContext)
        dependencies.router.endWorkout()
        dismiss()
    }

    private func dismissWorkout() {
        dependencies.router.endWorkout()
        dismiss()
    }

    private func processIntentAction(_ action: WorkoutIntentAction) {
        guard let session else { return }
        switch action {
        case .completeSet:
            completeNextSet(in: session)
        case .extendRest:
            if let restEndsAt {
                self.restEndsAt = restEndsAt.addingTimeInterval(30)
            }
        case .endWorkout:
            showEndConfirmation = true
        }
    }

    private func completeNextSet(in session: WorkoutSessionEntity) {
        for workoutExercise in session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            for set in workoutExercise.sets.sorted(by: { $0.setNumber < $1.setNumber }) where !set.isCompleted {
                let exercise = exercises.first(where: { $0.id == workoutExercise.exerciseId })
                completeSet(set, workoutExercise: workoutExercise, session: session, exercise: exercise)
                return
            }
        }
    }
}

struct RestTimerBanner: View {
    let restEndsAt: Date
    var onExtend: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(restEndsAt.timeIntervalSince(context.date)))
            DFCard {
                HStack {
                    Text("Rest")
                        .dfFont(.subheading)
                    Spacer()
                    if let onExtend {
                        Button("+30s", action: onExtend)
                            .dfFont(.subheading)
                    }
                    Text("\(remaining)s")
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(Color.dfAccent)
                }
            }
        }
    }
}
