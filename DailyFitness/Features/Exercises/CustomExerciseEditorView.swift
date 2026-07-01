import SwiftUI
import SwiftData

struct CustomExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let userId: UUID
    /// When set, the editor edits this existing custom exercise instead of creating one.
    var existing: ExerciseEntity? = nil
    var onCreated: ((ExerciseEntity) -> Void)? = nil
    /// Called after the edited exercise is deleted, so the presenter can pop.
    var onDeleted: (() -> Void)? = nil

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var selectedMuscles: Set<String> = []
    @State private var equipmentText = ""
    @State private var loggingFields: LoggingFieldMask = .weightReps
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var didLoad = false

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newValue in
                        loggingFields = defaultLoggingFields(for: newValue)
                    }
                }

                Section("Muscles") {
                    ForEach(MuscleGroup.allCases) { muscle in
                        Toggle(muscle.displayName, isOn: Binding(
                            get: { selectedMuscles.contains(muscle.token) },
                            set: { isOn in
                                if isOn { selectedMuscles.insert(muscle.token) }
                                else { selectedMuscles.remove(muscle.token) }
                            }
                        ))
                    }
                }

                Section {
                    TextField("e.g. dumbbell, bench", text: $equipmentText)
                } header: {
                    Text("Equipment")
                } footer: {
                    Text("Comma-separated. Common: \(Equipment.common.prefix(6).map(\.displayName).joined(separator: ", "))")
                }

                Section("Logging") {
                    Picker("Fields", selection: $loggingFields) {
                        Text("Weight × Reps").tag(LoggingFieldMask.weightReps)
                        Text("Duration").tag(LoggingFieldMask.duration)
                        Text("Hold time").tag(LoggingFieldMask.hold)
                        Text("Hold + Side").tag(LoggingFieldMask.side)
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete exercise", systemImage: "trash")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.dfBackground)
            .navigationTitle(isEditing ? "Edit exercise" : "Custom exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this exercise?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteExercise() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Logged history is kept, but it will no longer appear in the library.")
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing else { return }
        name = existing.name
        category = existing.category
        selectedMuscles = Set(existing.primaryMuscles)
        equipmentText = existing.equipment.joined(separator: ", ")
        loggingFields = existing.loggingFields
    }

    private func defaultLoggingFields(for category: ExerciseCategory) -> LoggingFieldMask {
        switch category {
        case .strength: return .weightReps
        case .cardio, .yoga: return .duration
        case .mobility, .flexibility: return .hold
        }
    }

    private func parsedEquipment() -> [String] {
        equipmentText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: " ", with: "_") }
            .filter { !$0.isEmpty }
    }

    private func save() {
        let repo = ExerciseRepository()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let existing {
            do {
                try repo.updateCustom(
                    existing,
                    name: trimmedName,
                    category: category,
                    primaryMuscles: Array(selectedMuscles),
                    equipment: parsedEquipment(),
                    loggingFields: loggingFields,
                    context: modelContext
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        // Custom exercises are unlimited on every tier (PRD §13 never capped them).
        do {
            let entity = try repo.createCustom(
                name: trimmedName,
                category: category,
                primaryMuscles: Array(selectedMuscles),
                equipment: parsedEquipment(),
                loggingFields: loggingFields,
                userId: userId,
                context: modelContext
            )
            onCreated?(entity)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExercise() {
        guard let existing else { return }
        do {
            try ExerciseRepository().softDelete(existing, context: modelContext)
            onDeleted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
