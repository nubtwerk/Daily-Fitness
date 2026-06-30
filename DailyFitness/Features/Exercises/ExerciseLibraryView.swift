import SwiftUI
import SwiftData

/// Standalone, browsable exercise library (LIB-03/04, US-022/023). Search + category,
/// muscle and equipment filters, image rows, and a path to the exercise detail screen.
struct ExerciseLibraryView: View {
    @Bindable var dependencies: DependencyContainer
    @Query(sort: \ExerciseEntity.name) private var allExercises: [ExerciseEntity]

    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selectedMuscle: String?
    @State private var selectedEquipment: String?
    @State private var showCustomEditor = false

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    private var exercises: [ExerciseEntity] {
        allExercises.filter { $0.deletedAt == nil }
    }

    private var muscleOptions: [String] {
        MuscleGroup.allCases.map(\.token)
    }

    private var equipmentOptions: [String] {
        Equipment.common.map(\.rawValue)
    }

    private var filtered: [ExerciseEntity] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return exercises.filter { ex in
            if let selectedCategory, ex.category != selectedCategory { return false }
            if let selectedMuscle, !ex.primaryMuscles.contains(selectedMuscle) { return false }
            if let selectedEquipment, !ex.equipment.contains(selectedEquipment) { return false }
            if query.isEmpty { return true }
            return ex.name.lowercased().contains(query)
                || ex.primaryMuscles.contains { $0.contains(query) }
                || ex.equipment.contains { $0.contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    DFEmptyState(
                        title: "Library is loading",
                        message: "Exercise data hasn't finished loading yet. Reopen the app in a moment."
                    )
                } else {
                    List {
                        ForEach(filtered, id: \.id) { exercise in
                            NavigationLink {
                                ExerciseDetailView(dependencies: dependencies, exercise: exercise)
                            } label: {
                                ExerciseLibraryRow(exercise: exercise)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if filtered.isEmpty {
                            DFEmptyState(
                                title: "No exercises found",
                                message: query.isEmpty ? "Try a different filter." : "Try another search term."
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search \(exercises.count) exercises")
            .navigationTitle("Library")
            .safeAreaInset(edge: .top) {
                if !exercises.isEmpty {
                    VStack(spacing: CalmStrength.Spacing.xs) {
                        filterRow(items: ["All"] + ExerciseCategory.allCases.map(\.displayName), isAll: selectedCategory == nil, selectedTitle: selectedCategory?.displayName) { title in
                            selectedCategory = ExerciseCategory.allCases.first { $0.displayName == title }
                        }
                        filterRow(items: ["All muscles"] + muscleOptions.map { MuscleGroup.displayName(forToken: $0) }, isAll: selectedMuscle == nil, selectedTitle: selectedMuscle.map { MuscleGroup.displayName(forToken: $0) }) { title in
                            selectedMuscle = muscleOptions.first { MuscleGroup.displayName(forToken: $0) == title }
                        }
                        filterRow(items: ["All equipment"] + equipmentOptions.map { Equipment.displayName(forToken: $0) }, isAll: selectedEquipment == nil, selectedTitle: selectedEquipment.map { Equipment.displayName(forToken: $0) }) { title in
                            selectedEquipment = equipmentOptions.first { Equipment.displayName(forToken: $0) == title }
                        }
                    }
                    .padding(.vertical, CalmStrength.Spacing.xs)
                    .background(Color.dfBackground)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCustomEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCustomEditor) {
                CustomExerciseEditorView(
                    userId: dependencies.userSession.effectiveUserId,
                    isPro: dependencies.userSession.isPro
                )
            }
        }
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    /// A horizontally-scrolling row of filter chips. `isAll` true selects the leading
    /// "All" chip; otherwise the chip whose title matches `selectedTitle` is selected.
    private func filterRow(items: [String], isAll: Bool, selectedTitle: String?, onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CalmStrength.Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                    let isSelected = index == 0 ? isAll : (title == selectedTitle)
                    DFFilterChip(title: title, isSelected: isSelected) {
                        if index == 0 { onSelect("") } else { onSelect(title) }
                    }
                }
            }
            .padding(.horizontal, CalmStrength.Spacing.md)
        }
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: ExerciseEntity

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.md) {
            ExerciseImageView(imageURL: exercise.imageURL, category: exercise.category)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                HStack(spacing: CalmStrength.Spacing.xs) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(Color.dfPrimary)
                        .lineLimit(1)
                    if exercise.isCustom { CustomBadge() }
                }
                HStack(spacing: CalmStrength.Spacing.sm) {
                    Text(exercise.category.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                    if let muscle = exercise.primaryMuscles.first {
                        Text(MuscleGroup.displayName(forToken: muscle))
                            .font(.caption)
                            .foregroundStyle(Color.dfSecondaryText)
                    }
                }
            }
        }
        .padding(.vertical, CalmStrength.Spacing.xs)
    }
}
