import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineEntity.name) private var routines: [RoutineEntity]

    let program: ProgramEntity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                DFCard {
                    VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                        Text(program.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(Color.dfSecondaryText)
                        if let weeks = program.weeks {
                            Text("\(weeks) weeks")
                                .font(.subheadline)
                        }
                        if program.isActive {
                            Label("Active program", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.dfAccent)
                        }
                    }
                }

                DFSectionHeader(title: "Schedule")
                ForEach(program.days.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { day in
                    DFCard {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(dayName(day.dayOfWeek))
                                    .font(.headline)
                                Text(routineName(for: day.routineId))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dfSecondaryText)
                            }
                            Spacer()
                            if day.weekIndex > 0 {
                                Text("Week \(day.weekIndex + 1)")
                                    .font(.caption)
                                    .foregroundStyle(Color.dfSecondaryText)
                            }
                        }
                    }
                }

                if !program.isActive {
                    DFPrimaryButton(title: "Start program") {
                        startProgram()
                    }
                }
            }
            .padding(CalmStrength.Spacing.md)
        }
        .background(Color.dfBackground)
        .navigationTitle(program.name)
    }

    private func dayName(_ dayOfWeek: Int) -> String {
        Calendar.current.weekdaySymbols[dayOfWeek - 1]
    }

    private func routineName(for id: UUID?) -> String {
        guard let id, let routine = routines.first(where: { $0.id == id }) else {
            return "Rest or blank session"
        }
        return routine.name
    }

    private func startProgram() {
        let myPrograms = (try? modelContext.fetch(FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.isSuggested == false }
        ))) ?? []

        guard ContentLimitService.canCreateProgram(currentCount: myPrograms.count, isPro: dependencies.userSession.isPro)
            || program.isSuggested == false
        else { return }

        for active in (try? modelContext.fetch(FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.isActive == true }
        ))) ?? [] {
            active.isActive = false
        }

        let owned: ProgramEntity
        if program.isSuggested {
            owned = ProgramEntity(
                name: program.name,
                category: program.category,
                isSuggested: false,
                weeks: program.weeks
            )
            owned.sourceTemplateId = program.id
            owned.userId = dependencies.userSession.effectiveUserId
            for day in program.days {
                let copy = ProgramDayEntity(
                    weekIndex: day.weekIndex,
                    dayOfWeek: day.dayOfWeek,
                    routineId: day.routineId,
                    sortOrder: day.sortOrder
                )
                contextInsert(copy, into: owned)
            }
            modelContext.insert(owned)
        } else {
            owned = program
        }

        owned.isActive = true
        owned.updatedAt = Date()
        try? modelContext.save()
    }

    private func contextInsert(_ day: ProgramDayEntity, into program: ProgramEntity) {
        modelContext.insert(day)
        program.days.append(day)
    }
}

struct ProgramEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let dependencies: DependencyContainer
    @State private var name = ""
    @State private var category: ProgramCategory = .strength
    @State private var weeks = 4

    var body: some View {
        NavigationStack {
            Form {
                TextField("Program name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(ProgramCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue.capitalized).tag(cat)
                    }
                }
                Stepper("Weeks: \(weeks)", value: $weeks, in: 1...12)
            }
            .navigationTitle("New program")
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

    private func save() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.isSuggested == false }
        ))) ?? 0
        guard ContentLimitService.canCreateProgram(currentCount: count, isPro: dependencies.userSession.isPro) else {
            return
        }

        let program = ProgramEntity(
            userId: dependencies.userSession.effectiveUserId,
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            isSuggested: false,
            weeks: weeks
        )
        modelContext.insert(program)
        try? modelContext.save()
        dismiss()
    }
}
