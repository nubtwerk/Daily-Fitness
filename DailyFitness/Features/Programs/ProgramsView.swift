import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ProgramEntity> { $0.isSuggested == true })
    private var suggestedPrograms: [ProgramEntity]
    @Query(filter: #Predicate<ProgramEntity> { $0.isSuggested == false })
    private var myPrograms: [ProgramEntity]
    @Query(sort: \RoutineEntity.name) private var routines: [RoutineEntity]
    @State private var showCreateRoutine = false
    @State private var routineToEdit: RoutineEntity?

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
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
                    Button("New routine") { showCreateRoutine = true }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                RoutineEditorView(dependencies: dependencies)
            }
            .sheet(item: $routineToEdit) { routine in
                RoutineEditorView(dependencies: dependencies, routine: routine)
            }
        }
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "My routines")
            if routines.isEmpty {
                Text("Create a reusable workout template.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(routines, id: \.id) { routine in
                    Button {
                        routineToEdit = routine
                    } label: {
                        DFCard {
                            HStack {
                                VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                                    Text(routine.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.dfPrimary)
                                    Text("\(routine.exercises.count) exercises")
                                        .font(.subheadline)
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
            DFSectionHeader(title: "Suggested")
            if suggestedPrograms.isEmpty {
                Text("Suggested programs will appear here after seeding.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(suggestedPrograms, id: \.id) { program in
                    ProgramCard(program: program)
                }
            }
        }
    }

    private var myProgramsSection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "My programs")
            if myPrograms.isEmpty {
                Text("Start a suggested program or build your own.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(myPrograms, id: \.id) { program in
                    ProgramCard(program: program)
                }
            }
        }
    }
}

struct ProgramCard: View {
    let program: ProgramEntity

    var body: some View {
        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                Text(program.name)
                    .font(.headline)
                    .foregroundStyle(Color.dfPrimary)
                Text(program.category.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
    }
}

extension RoutineEntity: Identifiable {}
