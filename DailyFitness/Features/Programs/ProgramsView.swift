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
    @State private var showCreateProgram = false
    @State private var routineToEdit: RoutineEntity?
    @State private var showLimitAlert = false

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
        if ContentLimitService.canCreateRoutine(currentCount: routines.count, isPro: dependencies.userSession.isPro) {
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
            if routines.isEmpty {
                Text("Create a reusable session template.")
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

    private var myProgramsSection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "My programs")
            if myPrograms.isEmpty {
                Text("Start a suggested program or build your own.")
                    .font(.subheadline)
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
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                HStack {
                    Text(program.name)
                        .font(.headline)
                        .foregroundStyle(Color.dfPrimary)
                    if program.isActive {
                        Text("Active")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.dfAccent.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(program.category.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
    }
}

extension RoutineEntity: Identifiable {}
