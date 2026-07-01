import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseEntity.name) private var allExercises: [ExerciseEntity]

    var dependencies: DependencyContainer?
    var excludeIds: Set<UUID> = []
    var onSelect: (ExerciseEntity) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedMuscle: String?
    @State private var showCustomEditor = false

    private var exercises: [ExerciseEntity] {
        allExercises.filter { $0.deletedAt == nil }
    }

    private var muscleOptions: [String] {
        Array(Set(exercises.flatMap(\.primaryMuscles))).sorted()
    }

    private var filteredExercises: [ExerciseEntity] {
        exercises.filter { exercise in
            guard !excludeIds.contains(exercise.id) else { return false }
            if let selectedCategory, exercise.category != selectedCategory { return false }
            if let selectedMuscle, !exercise.primaryMuscles.contains(selectedMuscle) { return false }
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return exercise.name.lowercased().contains(query)
                || exercise.primaryMuscles.contains { $0.lowercased().contains(query) }
                || exercise.equipment.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    DFEmptyState(
                        title: "Library is empty",
                        message: "Exercise data hasn't loaded yet. Force-quit and reopen the app."
                    )
                } else {
                    List(filteredExercises, id: \.id) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            ExercisePickerRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.dfBackground)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if dependencies != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Custom") { showCustomEditor = true }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if !exercises.isEmpty {
                    VStack(spacing: CalmStrength.Spacing.sm) {
                        categoryFilter
                        muscleFilter
                    }
                }
            }
            .overlay {
                if !exercises.isEmpty && filteredExercises.isEmpty {
                    DFEmptyState(
                        title: "No exercises found",
                        message: searchText.isEmpty
                            ? "Try a different filter."
                            : "Try another search term."
                    )
                }
            }
            .sheet(isPresented: $showCustomEditor) {
                if let dependencies {
                    CustomExerciseEditorView(
                        userId: dependencies.userSession.effectiveUserId,
                        isPro: dependencies.userSession.isPro,
                        onCreated: { exercise in
                            onSelect(exercise)
                            dismiss()
                        }
                    )
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CalmStrength.Spacing.sm) {
                DFChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    DFChip(
                        title: category.rawValue.capitalized,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, CalmStrength.Spacing.md)
            .padding(.vertical, CalmStrength.Spacing.sm)
        }
        .background(Color.dfBackground)
    }

    private var muscleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CalmStrength.Spacing.sm) {
                DFChip(title: "All muscles", isSelected: selectedMuscle == nil) {
                    selectedMuscle = nil
                }
                ForEach(muscleOptions, id: \.self) { muscle in
                    DFChip(
                        title: MuscleGroup.displayName(forToken: muscle),
                        isSelected: selectedMuscle == muscle
                    ) {
                        selectedMuscle = muscle
                    }
                }
            }
            .padding(.horizontal, CalmStrength.Spacing.md)
            .padding(.bottom, CalmStrength.Spacing.sm)
        }
        .background(Color.dfBackground)
    }
}

private struct ExercisePickerRow: View {
    let exercise: ExerciseEntity

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.md) {
            ExerciseImageView(imageURL: exercise.imageURL, category: exercise.category)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                HStack {
                    Text(exercise.name)
                        .dfFont(.subheading)
                        .foregroundStyle(Color.dfPrimary)
                    if exercise.isCustom {
                        CustomBadge()
                    }
                }
                HStack(spacing: CalmStrength.Spacing.sm) {
                    Text(exercise.category.displayName)
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                    if let muscle = exercise.primaryMuscles.first {
                        Text(MuscleGroup.displayName(forToken: muscle))
                            .dfFont(.caption)
                            .foregroundStyle(Color.dfSecondaryText)
                    }
                }
            }
        }
        .padding(.vertical, CalmStrength.Spacing.xs)
        .contentShape(Rectangle())
    }
}
