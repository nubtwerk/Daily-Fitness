import SwiftUI
import SwiftData

struct RoutineExerciseDraft: Identifiable {
    let id: UUID
    var exerciseId: UUID
    var name: String
    var category: ExerciseCategory
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var restSeconds: Int

    init(from entity: RoutineExerciseEntity, name: String, category: ExerciseCategory) {
        id = entity.id
        exerciseId = entity.exerciseId
        self.name = name
        self.category = category
        targetSets = entity.targetSets
        targetRepsMin = entity.targetRepsMin ?? 8
        targetRepsMax = entity.targetRepsMax ?? 12
        restSeconds = entity.restSeconds
    }

    init(from exercise: ExerciseEntity) {
        id = UUID()
        exerciseId = exercise.id
        name = exercise.name
        category = exercise.category
        targetSets = 3
        targetRepsMin = 8
        targetRepsMax = 12
        restSeconds = 90
    }
}

struct RoutineEditorView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseEntity.name) private var allExercisesRaw: [ExerciseEntity]

    private var allExercises: [ExerciseEntity] {
        allExercisesRaw.filter { $0.deletedAt == nil }
    }

    private let existingRoutine: RoutineEntity?

    @State private var name: String
    @State private var drafts: [RoutineExerciseDraft]
    @State private var showExercisePicker = false

    init(dependencies: DependencyContainer, routine: RoutineEntity? = nil) {
        self._dependencies = Bindable(wrappedValue: dependencies)
        existingRoutine = routine
        _name = State(initialValue: routine?.name ?? "")
        _drafts = State(initialValue: [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Routine name", text: $name)
                }

                Section {
                    if drafts.isEmpty {
                        Text("Add exercises from the library to build this routine.")
                            .font(.subheadline)
                            .foregroundStyle(Color.dfSecondaryText)
                    } else {
                        ForEach($drafts) { $draft in
                            RoutineExerciseDraftRow(draft: $draft)
                        }
                        .onDelete(perform: deleteDrafts)
                        .onMove(perform: moveDrafts)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    if !drafts.isEmpty {
                        Text("Drag to reorder. Defaults: 3 sets, 8–12 reps, 90s rest.")
                    }
                }
            }
            .navigationTitle(existingRoutine == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
                if !drafts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(
                    excludeIds: Set(drafts.map(\.exerciseId)),
                    onSelect: addExercise
                )
            }
            .onAppear(perform: loadDraftsIfNeeded)
            .onChange(of: allExercisesRaw.count) { _, _ in
                loadDraftsIfNeeded()
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !drafts.isEmpty
    }

    private func loadDraftsIfNeeded() {
        guard drafts.isEmpty, let routine = existingRoutine else { return }
        drafts = routine.exercises
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .compactMap { item in
                guard let exercise = allExercises.first(where: { $0.id == item.exerciseId }) else {
                    return RoutineExerciseDraft(
                        from: item,
                        name: "Unknown exercise",
                        category: .strength
                    )
                }
                return RoutineExerciseDraft(from: item, name: exercise.name, category: exercise.category)
            }
    }

    private func addExercise(_ exercise: ExerciseEntity) {
        drafts.append(RoutineExerciseDraft(from: exercise))
    }

    private func deleteDrafts(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    private func moveDrafts(from source: IndexSet, to destination: Int) {
        drafts.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let routine: RoutineEntity

        if let existingRoutine {
            routine = existingRoutine
            routine.name = trimmedName
            routine.updatedAt = Date()
            for exercise in routine.exercises {
                modelContext.delete(exercise)
            }
            routine.exercises.removeAll()
        } else {
            routine = RoutineEntity(
                userId: dependencies.userSession.localUserId,
                name: trimmedName
            )
            modelContext.insert(routine)
        }

        for (index, draft) in drafts.enumerated() {
            let routineExercise = RoutineExerciseEntity(
                sortOrder: index,
                exerciseId: draft.exerciseId,
                targetSets: draft.targetSets,
                targetRepsMin: draft.targetRepsMin,
                targetRepsMax: draft.targetRepsMax,
                restSeconds: draft.restSeconds
            )
            modelContext.insert(routineExercise)
            routine.exercises.append(routineExercise)
        }

        routine.syncStatus = .pending
        try? modelContext.save()
        dismiss()
    }
}

private struct RoutineExerciseDraftRow: View {
    @Binding var draft: RoutineExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            Text(draft.name)
                .font(.headline)
                .foregroundStyle(Color.dfPrimary)

            Stepper("Sets: \(draft.targetSets)", value: $draft.targetSets, in: 1...10)

            HStack {
                Stepper("Min reps: \(draft.targetRepsMin)", value: $draft.targetRepsMin, in: 1...30)
            }

            HStack {
                Stepper("Max reps: \(draft.targetRepsMax)", value: $draft.targetRepsMax, in: 1...30)
            }

            Stepper("Rest: \(draft.restSeconds)s", value: $draft.restSeconds, in: 15...300, step: 15)
        }
        .padding(.vertical, CalmStrength.Spacing.xs)
    }
}
