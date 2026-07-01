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
    var targetDurationSeconds: Int
    var restSeconds: Int
    var progressionEnabled: Bool
    var supersetGroupId: UUID?
    var note: String

    init(from entity: RoutineExerciseEntity, name: String, category: ExerciseCategory) {
        id = entity.id
        exerciseId = entity.exerciseId
        self.name = name
        self.category = category
        targetSets = entity.targetSets
        targetRepsMin = entity.targetRepsMin ?? 8
        targetRepsMax = entity.targetRepsMax ?? 12
        targetDurationSeconds = entity.targetDurationSeconds ?? 60
        restSeconds = entity.restSeconds
        progressionEnabled = entity.progressionEnabled
        supersetGroupId = entity.supersetGroupId
        note = entity.note ?? ""
    }

    init(from exercise: ExerciseEntity) {
        id = UUID()
        exerciseId = exercise.id
        name = exercise.name
        category = exercise.category
        targetSets = 3
        targetRepsMin = 8
        targetRepsMax = 12
        targetDurationSeconds = 60
        restSeconds = category == .strength ? 90 : 30
        progressionEnabled = true
        supersetGroupId = nil
        note = ""
    }

    var isStrength: Bool { category == .strength }
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
                            .dfFont(.callout)
                            .foregroundStyle(Color.dfSecondaryText)
                    } else {
                        ForEach($drafts) { $draft in
                            let index = drafts.firstIndex(where: { $0.id == draft.id }) ?? 0
                            RoutineExerciseDraftRow(
                                draft: $draft,
                                showSupersetButton: index > 0,
                                groupedWithPrevious: isGroupedWithPrevious(index),
                                isInSuperset: draft.supersetGroupId != nil,
                                onToggleSuperset: { toggleSupersetWithPrevious(at: index) }
                            )
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
                    if drafts.count > 1 {
                        Text("Tap the link icon to superset an exercise with the one above it (up to 4).")
                    }
                }

                if existingRoutine != nil {
                    Section {
                        Button("Delete routine", role: .destructive) {
                            deleteRoutine()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.dfBackground)
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
                    dependencies: dependencies,
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
        normalizeSupersets()
    }

    private func moveDrafts(from source: IndexSet, to destination: Int) {
        drafts.move(fromOffsets: source, toOffset: destination)
        normalizeSupersets()
    }

    // MARK: - Supersets (US-041)

    private func isGroupedWithPrevious(_ index: Int) -> Bool {
        guard index > 0, let id = drafts[index].supersetGroupId else { return false }
        return drafts[index - 1].supersetGroupId == id
    }

    private func groupSize(_ id: UUID) -> Int {
        drafts.filter { $0.supersetGroupId == id }.count
    }

    private func toggleSupersetWithPrevious(at index: Int) {
        guard index > 0 else { return }
        if isGroupedWithPrevious(index) {
            drafts[index].supersetGroupId = nil
        } else {
            let previous = drafts[index - 1]
            if let gid = previous.supersetGroupId, groupSize(gid) < 4 {
                drafts[index].supersetGroupId = gid
            } else if previous.supersetGroupId == nil {
                let gid = UUID()
                drafts[index - 1].supersetGroupId = gid
                drafts[index].supersetGroupId = gid
            }
            // else: previous group already at the 4-exercise cap — no-op.
        }
        normalizeSupersets()
    }

    /// Canonicalize superset groups to *contiguous runs*: each maximal run of
    /// exercises sharing an id gets a fresh id (so a reorder that splits a run into
    /// two pieces yields two distinct supersets, never one id spanning a gap), and
    /// any run of length 1 is cleared (a superset needs ≥2 members).
    private func normalizeSupersets() {
        var canonicalId: UUID?
        var previousOriginal: UUID?
        for index in drafts.indices {
            let original = drafts[index].supersetGroupId
            if original == nil {
                previousOriginal = nil
                canonicalId = nil
                continue
            }
            if original == previousOriginal {
                drafts[index].supersetGroupId = canonicalId
            } else {
                canonicalId = UUID()
                drafts[index].supersetGroupId = canonicalId
            }
            previousOriginal = original
        }

        for index in drafts.indices {
            guard let id = drafts[index].supersetGroupId else { continue }
            let prevSame = index > 0 && drafts[index - 1].supersetGroupId == id
            let nextSame = index < drafts.count - 1 && drafts[index + 1].supersetGroupId == id
            if !prevSame && !nextSame {
                drafts[index].supersetGroupId = nil
            }
        }
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
                userId: dependencies.userSession.effectiveUserId,
                name: trimmedName
            )
            modelContext.insert(routine)
        }

        for (index, draft) in drafts.enumerated() {
            let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let routineExercise = RoutineExerciseEntity(
                sortOrder: index,
                exerciseId: draft.exerciseId,
                targetSets: draft.targetSets,
                targetRepsMin: draft.isStrength ? draft.targetRepsMin : nil,
                targetRepsMax: draft.isStrength ? draft.targetRepsMax : nil,
                targetDurationSeconds: draft.isStrength ? nil : draft.targetDurationSeconds,
                restSeconds: draft.restSeconds,
                progressionEnabled: draft.isStrength ? draft.progressionEnabled : false,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            routineExercise.supersetGroupId = draft.supersetGroupId
            modelContext.insert(routineExercise)
            routine.exercises.append(routineExercise)
        }

        routine.syncStatus = .pending
        dependencies.syncEngine.enqueue(.upsertRoutine(routine.id))
        modelContext.saveOrPresent(
            "saveRoutine",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t save your routine",
            message: "Something went wrong while saving. Please try again."
        )
        dismiss()
    }

    private func deleteRoutine() {
        guard let routine = existingRoutine else { return }
        // Propagate a remote soft-delete by id, then remove the local copy. Same pattern as
        // discarding a session — avoids leaking a `deletedAt`-flagged row into routine queries.
        dependencies.syncEngine.enqueue(.deleteEntity(.routine, routine.id))
        modelContext.delete(routine)
        try? modelContext.save()
        dismiss()
    }
}

private struct RoutineExerciseDraftRow: View {
    @Binding var draft: RoutineExerciseDraft
    let showSupersetButton: Bool
    let groupedWithPrevious: Bool
    let isInSuperset: Bool
    let onToggleSuperset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            HStack {
                if isInSuperset {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(Color.dfAccent)
                }
                Text(draft.name)
                    .dfFont(.subheading)
                    .foregroundStyle(Color.dfPrimary)
                Spacer()
                if showSupersetButton {
                    Button(action: onToggleSuperset) {
                        Image(systemName: groupedWithPrevious ? "link.circle.fill" : "link.circle")
                            .foregroundStyle(groupedWithPrevious ? Color.dfAccent : Color.dfSecondaryText)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(groupedWithPrevious ? "Remove from superset" : "Superset with exercise above")
                }
            }

            if groupedWithPrevious {
                Text("Supersetted with exercise above")
                    .dfFont(.caption)
                    .foregroundStyle(Color.dfAccent)
            }

            Stepper("Sets: \(draft.targetSets)", value: $draft.targetSets, in: 1...10)

            if draft.isStrength {
                Stepper("Min reps: \(draft.targetRepsMin)", value: $draft.targetRepsMin, in: 1...30)
                Stepper("Max reps: \(draft.targetRepsMax)", value: $draft.targetRepsMax, in: 1...30)
                Stepper("Rest: \(draft.restSeconds)s", value: $draft.restSeconds, in: 15...300, step: 15)
                Toggle("Auto-progression", isOn: $draft.progressionEnabled)
                    .tint(Color.dfAccent)
            } else {
                Stepper("Duration: \(draft.targetDurationSeconds)s", value: $draft.targetDurationSeconds, in: 15...3600, step: 15)
            }

            TextField("Exercise note (optional)", text: $draft.note, axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
        }
        .padding(.vertical, CalmStrength.Spacing.xs)
    }
}
