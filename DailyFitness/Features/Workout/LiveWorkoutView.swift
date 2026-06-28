import SwiftUI
import SwiftData

struct LiveWorkoutView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sessionId: UUID

    @Query private var sessions: [WorkoutSessionEntity]
    @Query private var exercises: [ExerciseEntity]

    @State private var restEndsAt: Date?
    @State private var showEndConfirmation = false
    @State private var showExercisePicker = false

    init(sessionId: UUID, dependencies: DependencyContainer) {
        self.sessionId = sessionId
        self._dependencies = Bindable(wrappedValue: dependencies)
        _sessions = Query(filter: #Predicate<WorkoutSessionEntity> { $0.id == sessionId })
    }

    private var session: WorkoutSessionEntity? { sessions.first }

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
        }
    }

    @ViewBuilder
    private func workoutContent(_ session: WorkoutSessionEntity) -> some View {
        ScrollView {
            VStack(spacing: CalmStrength.Spacing.md) {
                if let restEndsAt, restEndsAt > Date() {
                    RestTimerBanner(restEndsAt: restEndsAt)
                }

                if session.exercises.isEmpty {
                    DFEmptyState(
                        title: "No exercises yet",
                        message: "Add exercises from the library to start logging sets."
                    )
                    DFPrimaryButton(title: "Add exercise") {
                        showExercisePicker = true
                    }
                } else {
                    ForEach(session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { workoutExercise in
                        ExerciseWorkoutCard(
                            exerciseName: exerciseName(for: workoutExercise.exerciseId),
                            sets: workoutExercise.sets.sorted(by: { $0.setNumber < $1.setNumber }),
                            onCompleteSet: { set in
                                completeSet(set, workoutExercise: workoutExercise, session: session)
                            }
                        )
                    }
                }
            }
            .padding(CalmStrength.Spacing.md)
        }
    }

    private func addExercise(_ exercise: ExerciseEntity, to session: WorkoutSessionEntity) {
        _ = WorkoutExerciseFactory.addExercise(exercise, to: session, in: modelContext)
        session.syncStatus = .pending
        try? modelContext.save()
    }

    private func exerciseName(for id: UUID) -> String {
        exercises.first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func completeSet(
        _ set: WorkoutSetEntity,
        workoutExercise: WorkoutExerciseEntity,
        session: WorkoutSessionEntity
    ) {
        guard !set.isCompleted else { return }
        set.isCompleted = true
        set.completedAt = Date()
        if set.weightKg == nil { set.weightKg = 0 }
        if set.reps == nil { set.reps = 0 }
        session.syncStatus = .pending
        try? modelContext.save()

        let restSeconds = 90
        restEndsAt = Date().addingTimeInterval(TimeInterval(restSeconds))
        LiveActivityManager.shared.update(session: session, phase: .resting, restEndsAt: restEndsAt)
    }

    private func finishWorkout() {
        guard let session else { return }
        session.endedAt = Date()
        session.syncStatus = .pending
        try? modelContext.save()
        LiveActivityManager.shared.end()
        dependencies.router.endWorkout()
        dismiss()
    }

    private func discardWorkout() {
        guard let session else { return }
        modelContext.delete(session)
        try? modelContext.save()
        LiveActivityManager.shared.end()
        dependencies.router.endWorkout()
        dismiss()
    }

    private func dismissWorkout() {
        dependencies.router.endWorkout()
        dismiss()
    }
}

struct RestTimerBanner: View {
    let restEndsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(restEndsAt.timeIntervalSince(context.date)))
            DFCard {
                HStack {
                    Text("Rest")
                        .font(.headline)
                    Spacer()
                    Text("\(remaining)s")
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(Color.dfAccent)
                }
            }
        }
    }
}

struct ExerciseWorkoutCard: View {
    let exerciseName: String
    let sets: [WorkoutSetEntity]
    let onCompleteSet: (WorkoutSetEntity) -> Void

    var body: some View {
        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                Text(exerciseName)
                    .font(.headline)
                    .foregroundStyle(Color.dfPrimary)

                ForEach(sets, id: \.id) { set in
                    SetRow(set: set, onComplete: { onCompleteSet(set) })
                }
            }
        }
    }
}

struct SetRow: View {
    @Bindable var set: WorkoutSetEntity
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Text("Set \(set.setNumber)")
                .font(.subheadline)
                .foregroundStyle(Color.dfSecondaryText)
                .frame(width: 44, alignment: .leading)

            TextField("kg", value: $set.weightKg, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)

            TextField("reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)

            Button(action: onComplete) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.dfAccent : Color.dfSecondaryText)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
    }
}
