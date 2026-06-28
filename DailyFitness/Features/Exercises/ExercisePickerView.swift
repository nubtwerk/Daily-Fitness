import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseEntity.name) private var allExercises: [ExerciseEntity]

    var excludeIds: Set<UUID> = []
    var onSelect: (ExerciseEntity) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?

    private var exercises: [ExerciseEntity] {
        allExercises.filter { $0.deletedAt == nil }
    }

    private var filteredExercises: [ExerciseEntity] {
        exercises.filter { exercise in
            guard !excludeIds.contains(exercise.id) else { return false }
            if let selectedCategory, exercise.category != selectedCategory { return false }
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
                        message: "Exercise data hasn't loaded yet. Force-quit and reopen the app, or reinstall from Xcode."
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
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                if !exercises.isEmpty {
                    categoryFilter
                }
            }
            .overlay {
                if !exercises.isEmpty && filteredExercises.isEmpty {
                    DFEmptyState(
                        title: "No exercises found",
                        message: searchText.isEmpty
                            ? "Try a different category filter."
                            : "Try another search term."
                    )
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CalmStrength.Spacing.sm) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    CategoryChip(
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
}

private struct ExercisePickerRow: View {
    let exercise: ExerciseEntity

    var body: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(Color.dfPrimary)
            HStack(spacing: CalmStrength.Spacing.sm) {
                Text(exercise.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(Color.dfSecondaryText)
                if let muscle = exercise.primaryMuscles.first {
                    Text(muscle.capitalized)
                        .font(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                }
            }
        }
        .padding(.vertical, CalmStrength.Spacing.xs)
        .contentShape(Rectangle())
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, CalmStrength.Spacing.md)
                .padding(.vertical, CalmStrength.Spacing.sm)
                .background(isSelected ? Color.dfPrimary : Color.dfSurface)
                .foregroundStyle(isSelected ? Color.white : Color.dfPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
