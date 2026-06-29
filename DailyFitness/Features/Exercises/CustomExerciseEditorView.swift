import SwiftUI
import SwiftData

struct CustomExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let userId: UUID
    let isPro: Bool
    let onCreated: (ExerciseEntity) -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var selectedMuscles: Set<String> = []
    @State private var equipmentText = ""
    @State private var loggingFields: LoggingFieldMask = .weightReps
    @State private var errorMessage: String?

    private let muscleOptions = ["chest", "back", "shoulders", "biceps", "triceps", "quads", "hamstrings", "glutes", "core", "hips", "calves"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue.capitalized).tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newValue in
                        loggingFields = defaultLoggingFields(for: newValue)
                    }
                }

                Section("Muscles") {
                    ForEach(muscleOptions, id: \.self) { muscle in
                        Toggle(muscle.capitalized, isOn: Binding(
                            get: { selectedMuscles.contains(muscle) },
                            set: { isOn in
                                if isOn { selectedMuscles.insert(muscle) }
                                else { selectedMuscles.remove(muscle) }
                            }
                        ))
                    }
                }

                Section("Equipment") {
                    TextField("e.g. dumbbell, bench", text: $equipmentText)
                }

                Section("Logging") {
                    Picker("Fields", selection: $loggingFields) {
                        Text("Weight × Reps").tag(LoggingFieldMask.weightReps)
                        Text("Duration").tag(LoggingFieldMask.duration)
                        Text("Hold time").tag(LoggingFieldMask.hold)
                        Text("Hold + Side").tag(LoggingFieldMask.side)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Custom exercise")
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
        }
    }

    private func defaultLoggingFields(for category: ExerciseCategory) -> LoggingFieldMask {
        switch category {
        case .strength: return .weightReps
        case .cardio, .yoga: return .duration
        case .mobility, .flexibility: return .hold
        }
    }

    private func save() {
        let repo = ExerciseRepository()
        let count = repo.customExerciseCount(userId: userId, context: modelContext)
        guard ContentLimitService.canCreateCustomExercise(currentCount: count, isPro: isPro) else {
            errorMessage = "Free plan allows \(ContentLimitService.maxFreeCustomExercises) custom exercises. Upgrade to Pro for unlimited."
            return
        }

        let equipment = equipmentText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        do {
            let entity = try repo.createCustom(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                primaryMuscles: Array(selectedMuscles),
                equipment: equipment,
                loggingFields: loggingFields,
                userId: userId,
                context: modelContext
            )
            onCreated(entity)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
