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

    @AppStorage("hasSeenLiveActivityExplainer") private var hasSeenLiveActivityExplainer = false

    @State private var restEndsAt: Date?
    @State private var restTotalSeconds = 0
    @State private var showSummary = false
    @State private var showExercisePicker = false
    @State private var showSessionNote = false
    @State private var sessionNoteDraft = ""
    @State private var showLiveActivityExplainer = false
    @State private var recentPRs: [PersonalRecord] = []
    /// Workout-exercise ids whose recommendation the user has accepted or ignored this session.
    @State private var handledRecommendations: Set<UUID> = []
    @State private var handledScrollToken = 0

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
                            sessionNoteDraft = session?.note ?? ""
                            showSessionNote = true
                        } label: {
                            Image(systemName: (session?.note?.isEmpty == false) ? "note.text" : "square.and.pencil")
                        }
                        .accessibilityLabel("Session note")
                        Button {
                            showExercisePicker = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add exercise")
                        Button("Finish") { showSummary = true }
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
            .sheet(isPresented: $showSessionNote) { sessionNoteSheet }
            .sheet(isPresented: $showSummary) {
                if let session {
                    WorkoutSummaryView(
                        dependencies: dependencies,
                        session: session,
                        onSave: { showSummary = false; finishWorkout() },
                        onDiscard: { showSummary = false; discardWorkout() }
                    )
                }
            }
            .sheet(isPresented: $showLiveActivityExplainer) { liveActivityExplainerSheet }
            .onAppear(perform: handleOnAppear)
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: CalmStrength.Spacing.md) {
                    if let restEndsAt, restEndsAt > Date() {
                        DFRestTimerRing(
                            restEndsAt: restEndsAt,
                            totalSeconds: restTotalSeconds,
                            onExtend: { extendRest(in: session) },
                            onSkip: { skipRest(in: session) }
                        )
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
                        ForEach(supersetGroups(in: session), id: \.id) { group in
                            if group.exercises.count > 1 {
                                supersetContainer(group: group, session: session)
                            } else if let workoutExercise = group.exercises.first {
                                exerciseCard(workoutExercise: workoutExercise, session: session)
                            }
                        }
                    }
                }
                .padding(CalmStrength.Spacing.md)
            }
            .onChange(of: dependencies.router.scrollToCurrentSetToken) { _, token in
                scrollToCurrentSet(proxy: proxy, session: session, token: token)
            }
            .onAppear {
                scrollToCurrentSet(proxy: proxy, session: session, token: dependencies.router.scrollToCurrentSetToken)
            }
        }
    }

    private func supersetContainer(group: SupersetGroup, session: WorkoutSessionEntity) -> some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            HStack(spacing: CalmStrength.Spacing.xs) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                Text("Superset")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.dfAccent)

            ForEach(group.exercises, id: \.id) { workoutExercise in
                exerciseCard(workoutExercise: workoutExercise, session: session)
            }
        }
        .padding(.leading, CalmStrength.Spacing.sm)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.dfAccent.opacity(0.4))
                .frame(width: 3)
        }
    }

    @ViewBuilder
    private func exerciseCard(
        workoutExercise: WorkoutExerciseEntity,
        session: WorkoutSessionEntity
    ) -> some View {
        let exercise = exercises.first(where: { $0.id == workoutExercise.exerciseId })
        let loggingFields = exercise?.loggingFields ?? .weightReps
        let usePounds = userPrefs?.usePounds ?? false
        let rirEnabled = userPrefs?.rirEnabled ?? false
        let isStrength = exercise?.category == .strength
        let showProgression = isStrength
            && ContentLimitService.canShowProgression(
                forStrengthIndex: strengthIndex(for: workoutExercise, in: session),
                isPro: dependencies.userSession.isPro
            )
        let lastPerformance = LastWorkingSetService.lastPerformance(
            exerciseId: workoutExercise.exerciseId,
            userId: dependencies.userSession.effectiveUserId,
            excludingSessionId: session.id,
            context: modelContext
        )

        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                Text(exercise?.name ?? "Exercise")
                    .dfFont(.subheading)
                    .foregroundStyle(Color.dfPrimary)

                if let lastSummary = lastPerformance?.summary(loggingFields: loggingFields, usePounds: usePounds) {
                    Text(lastSummary)
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                }

                if showProgression,
                   !handledRecommendations.contains(workoutExercise.id),
                   let recommendation = dependencies.progressionService.latestRecommendation(
                        exerciseId: workoutExercise.exerciseId,
                        userId: dependencies.userSession.effectiveUserId,
                        context: modelContext
                   ) {
                    ProgressionBanner(
                        recommendation: recommendation,
                        usePounds: usePounds,
                        onAccept: {
                            dependencies.progressionService.applyRecommendation(
                                recommendation,
                                to: workoutExercise,
                                context: modelContext
                            )
                            handledRecommendations.insert(workoutExercise.id)
                        },
                        onIgnore: {
                            handledRecommendations.insert(workoutExercise.id)
                        }
                    )
                }

                ForEach(workoutExercise.sets.sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                    SetRowFactory.row(
                        for: set,
                        loggingFields: loggingFields,
                        usePounds: usePounds,
                        rirEnabled: rirEnabled,
                        lastPerformance: lastPerformance,
                        onComplete: {
                            completeSet(set, workoutExercise: workoutExercise, session: session, exercise: exercise)
                        }
                    )
                    .id(set.id)
                }

                ExerciseOptionsView(
                    workoutExercise: workoutExercise,
                    isStrength: isStrength,
                    defaultRestSeconds: userPrefs?.defaultRestSeconds ?? 90
                ) {
                    persist(session)
                }
            }
        }
    }

    // MARK: - Superset grouping

    struct SupersetGroup: Identifiable {
        let id: String
        let exercises: [WorkoutExerciseEntity]
    }

    /// Consecutive exercises sharing a `supersetGroupId` are grouped together (US-041).
    private func supersetGroups(in session: WorkoutSessionEntity) -> [SupersetGroup] {
        let sorted = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
        var groups: [SupersetGroup] = []
        var current: [WorkoutExerciseEntity] = []

        func flush() {
            guard let first = current.first else { return }
            let id = first.supersetGroupId?.uuidString ?? first.id.uuidString
            groups.append(SupersetGroup(id: id, exercises: current))
            current = []
        }

        for exercise in sorted {
            if let last = current.last {
                if let gid = exercise.supersetGroupId, gid == last.supersetGroupId {
                    current.append(exercise)
                } else {
                    flush()
                    current = [exercise]
                }
            } else {
                current = [exercise]
            }
        }
        flush()
        return groups
    }

    private func strengthIndex(for workoutExercise: WorkoutExerciseEntity, in session: WorkoutSessionEntity) -> Int {
        let sorted = session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder })
        var count = -1
        for item in sorted {
            if exercises.first(where: { $0.id == item.exerciseId })?.category == .strength {
                count += 1
            }
            if item.id == workoutExercise.id { return count }
        }
        return count
    }

    /// Next set to log, cycling across superset exercises in order (A1, B1, A2, B2…).
    private func nextIncompleteSet(in session: WorkoutSessionEntity) -> (WorkoutExerciseEntity, WorkoutSetEntity)? {
        for group in supersetGroups(in: session) {
            if group.exercises.count == 1 {
                let exercise = group.exercises[0]
                if let set = exercise.sets.sorted(by: { $0.setNumber < $1.setNumber }).first(where: { !$0.isCompleted }) {
                    return (exercise, set)
                }
            } else {
                let maxSets = group.exercises.map(\.sets.count).max() ?? 0
                for setIndex in 0..<maxSets {
                    for exercise in group.exercises {
                        let sets = exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })
                        if setIndex < sets.count, !sets[setIndex].isCompleted {
                            return (exercise, sets[setIndex])
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Sheets

    private var sessionNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Session note") {
                    TextField("How is the session going?", text: $sessionNoteDraft, axis: .vertical)
                        .lineLimit(4...10)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSessionNote = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = sessionNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        session?.note = trimmed.isEmpty ? nil : trimmed
                        if let session { persist(session) }
                        showSessionNote = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var liveActivityExplainerSheet: some View {
        VStack(spacing: CalmStrength.Spacing.lg) {
            Image(systemName: "lock.iphone")
                .font(.system(size: 48))
                .foregroundStyle(Color.dfAccent)
            Text("Keep your workout on the Lock Screen")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("DailyFitness can show your current set, rest countdown, and a complete-set button on the Lock Screen and Dynamic Island — so your phone stays in your pocket between sets.")
                .font(.subheadline)
                .foregroundStyle(Color.dfSecondaryText)
                .multilineTextAlignment(.center)
            VStack(spacing: CalmStrength.Spacing.sm) {
                DFPrimaryButton(title: "Show on Lock Screen") {
                    hasSeenLiveActivityExplainer = true
                    showLiveActivityExplainer = false
                    startLiveActivity()
                }
                Button("Not now") {
                    hasSeenLiveActivityExplainer = true
                    showLiveActivityExplainer = false
                }
                .font(.subheadline)
            }
        }
        .padding(CalmStrength.Spacing.xl)
        .presentationDetents([.medium])
    }

    // MARK: - Lifecycle

    private func handleOnAppear() {
        WorkoutIntentObserver.shared.start { action in
            processIntentAction(action)
        }
        maybeStartLiveActivity()
        if let action = WorkoutIntentBridge.consumePendingAction() {
            processIntentAction(action)
        }
    }

    private func maybeStartLiveActivity() {
        guard session != nil else { return }
        let prefs = dependencies.preferencesRepository.loadOrCreate(
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        guard prefs.liveActivitiesEnabled else { return }
        if hasSeenLiveActivityExplainer {
            startLiveActivity()
        } else {
            showLiveActivityExplainer = true
        }
    }

    private func startLiveActivity() {
        guard let session else { return }
        dependencies.workoutCoordinator.startLiveActivityIfEnabled(
            session: session,
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
    }

    private func scrollToCurrentSet(proxy: ScrollViewProxy, session: WorkoutSessionEntity, token: Int) {
        guard token > 0, token != handledScrollToken else { return }
        handledScrollToken = token
        guard let (_, set) = nextIncompleteSet(in: session) else { return }
        withAnimation {
            proxy.scrollTo(set.id, anchor: .center)
        }
    }

    // MARK: - Actions

    private func addExercise(_ exercise: ExerciseEntity, to session: WorkoutSessionEntity) {
        _ = WorkoutExerciseFactory.addExercise(exercise, to: session, in: modelContext)
        session.syncStatus = .pending
        modelContext.saveOrPresent(
            "addExercise",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t add the exercise",
            message: "We couldn’t save that exercise to your workout. Please try again."
        )
    }

    private func completeSet(
        _ set: WorkoutSetEntity,
        workoutExercise: WorkoutExerciseEntity,
        session: WorkoutSessionEntity,
        exercise: ExerciseEntity?
    ) {
        let result = dependencies.workoutCoordinator.completeSet(
            set,
            workoutExercise: workoutExercise,
            session: session,
            exercise: exercise,
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        if !result.personalRecords.isEmpty {
            recentPRs = result.personalRecords
            // The PR toast auto-dismisses; announce the same text so VoiceOver users hear it.
            let types = result.personalRecords.map { $0.type.rawValue }.joined(separator: ", ")
            AccessibilityNotification.Announcement("New PR! (\(types))").post()
        }
        restEndsAt = result.restEndsAt
        if let end = result.restEndsAt {
            restTotalSeconds = max(1, Int(end.timeIntervalSinceNow.rounded()))
        }
    }

    private func extendRest(in session: WorkoutSessionEntity) {
        // Only extend an active rest — never spawn a phantom rest from a stray
        // +30s (e.g. a Lock Screen ExtendRestIntent fired while not resting).
        guard let current = restEndsAt, current > Date() else { return }
        let updated = current.addingTimeInterval(30)
        restEndsAt = updated
        restTotalSeconds += 30
        dependencies.workoutCoordinator.syncRest(
            session: session,
            restEndsAt: updated,
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
    }

    private func skipRest(in session: WorkoutSessionEntity) {
        restEndsAt = nil
        restTotalSeconds = 0
        dependencies.workoutCoordinator.syncRest(
            session: session,
            restEndsAt: nil,
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
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

    private func persist(_ session: WorkoutSessionEntity) {
        session.syncStatus = .pending
        modelContext.saveOrPresent(
            "persistWorkout",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t save your change",
            message: "Your last edit to this workout may not be saved. Please try again."
        )
    }

    private func processIntentAction(_ action: WorkoutIntentAction) {
        guard let session else { return }
        switch action {
        case .completeSet:
            completeNextSet(in: session)
        case .extendRest:
            extendRest(in: session)
        case .endWorkout:
            showSummary = true
        }
    }

    private func completeNextSet(in session: WorkoutSessionEntity) {
        guard let (workoutExercise, set) = nextIncompleteSet(in: session) else { return }
        let exercise = exercises.first(where: { $0.id == workoutExercise.exerciseId })
        completeSet(set, workoutExercise: workoutExercise, session: session, exercise: exercise)
    }
}

/// Collapsible per-exercise note + rest override (US-042 / US-053).
private struct ExerciseOptionsView: View {
    @Bindable var workoutExercise: WorkoutExerciseEntity
    let isStrength: Bool
    let defaultRestSeconds: Int
    let onChange: () -> Void

    @State private var noteDraft: String = ""

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                TextField("Exercise note (cues, pain flags…)", text: $noteDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: noteDraft) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newNote = trimmed.isEmpty ? nil : trimmed
                        guard newNote != workoutExercise.note else { return }
                        workoutExercise.note = newNote
                        onChange()
                    }

                if isStrength {
                    Stepper(
                        "Rest: \(workoutExercise.restSecondsOverride ?? defaultRestSeconds)s",
                        value: Binding(
                            get: { workoutExercise.restSecondsOverride ?? defaultRestSeconds },
                            set: { workoutExercise.restSecondsOverride = $0; onChange() }
                        ),
                        in: 15...300,
                        step: 15
                    )
                    .font(.subheadline)
                }
            }
            .padding(.top, CalmStrength.Spacing.xs)
        } label: {
            Label("Notes & rest", systemImage: "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(Color.dfSecondaryText)
        }
        .onAppear { noteDraft = workoutExercise.note ?? "" }
    }
}
