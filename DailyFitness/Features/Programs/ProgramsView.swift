import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ProgramEntity> { $0.isSuggested == true })
    private var suggestedPrograms: [ProgramEntity]
    @Query(filter: #Predicate<ProgramEntity> { $0.isSuggested == false })
    private var myPrograms: [ProgramEntity]
    @Query(sort: \RoutineEntity.name) private var allRoutines: [RoutineEntity]
    @State private var showCreateRoutine = false
    @State private var showCreateProgram = false
    @State private var routineToEdit: RoutineEntity?
    @State private var showLimitAlert = false
    @State private var selectedCategory: ProgramCategory?

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    /// User-created routines only; seeded program-building routines are hidden here
    /// and don't count toward the free-tier limit.
    private var myRoutines: [RoutineEntity] {
        allRoutines.filter { !$0.isSuggested && $0.deletedAt == nil }
    }

    private var filteredSuggested: [ProgramEntity] {
        guard let selectedCategory else { return suggestedPrograms }
        return suggestedPrograms.filter { $0.category == selectedCategory }
    }

    private var suggestedCategories: [ProgramCategory] {
        ProgramCategory.allCases.filter { cat in suggestedPrograms.contains { $0.category == cat } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    routinesSection
                    suggestedSection
                    myProgramsSection
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New routine") { attemptCreateRoutine() }
                        Button("New program") { attemptCreateProgram() }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                RoutineEditorView(dependencies: dependencies)
            }
            .sheet(item: $routineToEdit) { routine in
                RoutineEditorView(dependencies: dependencies, routine: routine)
            }
            .sheet(isPresented: $showCreateProgram) {
                ProgramEditorView(dependencies: dependencies)
            }
            .alert("Free limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Upgrade to Pro for unlimited routines and programs.")
            }
        }
    }

    private func attemptCreateRoutine() {
        if ContentLimitService.canCreateRoutine(currentCount: myRoutines.count, isPro: dependencies.userSession.isPro) {
            showCreateRoutine = true
        } else {
            showLimitAlert = true
        }
    }

    private func attemptCreateProgram() {
        if ContentLimitService.canCreateProgram(currentCount: myPrograms.count, isPro: dependencies.userSession.isPro) {
            showCreateProgram = true
        } else {
            showLimitAlert = true
        }
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "My routines")
            if myRoutines.isEmpty {
                Text("Create a reusable session template.")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(myRoutines, id: \.id) { routine in
                    Button {
                        routineToEdit = routine
                    } label: {
                        DFCard {
                            HStack {
                                VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                                    Text(routine.name)
                                        .dfFont(.subheading)
                                        .foregroundStyle(Color.dfPrimary)
                                    Text("\(routine.exercises.count) exercises")
                                        .dfFont(.callout)
                                        .foregroundStyle(Color.dfSecondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.dfSecondaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "Suggested programs")
            if suggestedPrograms.isEmpty {
                Text("Suggested programs will appear here after seeding.")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                categoryFilter
                ForEach(filteredSuggested, id: \.id) { program in
                    NavigationLink {
                        ProgramDetailView(dependencies: dependencies, program: program)
                    } label: {
                        ProgramCard(program: program)
                    }
                    .buttonStyle(.plain)
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
                ForEach(suggestedCategories, id: \.self) { category in
                    DFChip(title: category.displayName, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.bottom, CalmStrength.Spacing.xs)
        }
    }

    private var myProgramsSection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "My programs")
            if myPrograms.isEmpty {
                Text("Start a suggested program or build your own.")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(myPrograms, id: \.id) { program in
                    NavigationLink {
                        ProgramDetailView(dependencies: dependencies, program: program)
                    } label: {
                        ProgramCard(program: program)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ProgramCard: View {
    let program: ProgramEntity

    var body: some View {
        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                HStack {
                    Label(program.category.displayName, systemImage: program.category.symbolName)
                        .dfFont(.captionStrong)
                        .foregroundStyle(Color.dfAccent)
                    Spacer()
                    if program.isActive {
                        Text("Active")
                            .dfFont(.captionStrong)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.dfAccent.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(program.name)
                    .dfFont(.subheading)
                    .foregroundStyle(Color.dfPrimary)
                HStack(spacing: CalmStrength.Spacing.md) {
                    if let days = program.daysPerWeek {
                        metaLabel("\(days)×/week", systemImage: "calendar")
                    }
                    metaLabel(durationText, systemImage: "clock")
                    if let level = program.level {
                        metaLabel(level.displayName, systemImage: "chart.bar")
                    }
                }
            }
        }
    }

    private var durationText: String {
        if let weeks = program.weeks { return "\(weeks) weeks" }
        return "Ongoing"
    }

    private func metaLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .dfFont(.caption)
            .foregroundStyle(Color.dfSecondaryText)
    }
}

extension RoutineEntity: Identifiable {}
