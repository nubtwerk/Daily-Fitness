import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RoutineEntity.name) private var routines: [RoutineEntity]

    let program: ProgramEntity

    @State private var editorTarget: ProgramEntity?
    @State private var basedOnName: String?
    @State private var showLeaveConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                headerCard

                DFSectionHeader(title: "Schedule")
                if program.days.isEmpty {
                    Text("No days scheduled yet. Edit the program to assign routines to days.")
                        .dfFont(.body)
                        .foregroundStyle(Color.dfSecondaryText)
                } else {
                    ForEach(program.days.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { day in
                        scheduleRow(day)
                    }
                }

                actionButtons
            }
            .padding(CalmStrength.Spacing.md)
        }
        .background(Color.dfBackground)
        .navigationTitle(program.name)
        .sheet(item: $editorTarget) { target in
            ProgramEditorView(dependencies: dependencies, program: target)
        }
        .confirmationDialog(
            "Leave this program?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Leave program", role: .destructive) { leaveProgram() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's removed from My programs. Your logged workout history is kept.")
        }
        .task(id: program.id) { resolveBasedOn() }
    }

    private var headerCard: some View {
        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                HStack {
                    Label(program.category.displayName, systemImage: program.category.symbolName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dfAccent)
                    Spacer()
                    if program.isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dfAccent)
                    }
                }

                if let basedOnName {
                    Text("Based on \(basedOnName)")
                        .font(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                }

                if let description = program.programDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Color.dfPrimary)
                }

                HStack(spacing: CalmStrength.Spacing.md) {
                    if let days = program.daysPerWeek {
                        metaLabel("\(days)×/week", systemImage: "calendar")
                    }
                    metaLabel(durationText, systemImage: "clock")
                    if let level = program.level {
                        metaLabel(level.displayName, systemImage: "chart.bar")
                    }
                }

                if !program.equipment.isEmpty {
                    Text("Equipment")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dfSecondaryText)
                        .padding(.top, CalmStrength.Spacing.xs)
                    FlowChips(items: program.equipment.map { Equipment.displayName(forToken: $0) })
                }
            }
        }
    }

    private func scheduleRow(_ day: ProgramDayEntity) -> some View {
        DFCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(dayName(day.dayOfWeek))
                        .font(.headline)
                        .foregroundStyle(Color.dfPrimary)
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

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: CalmStrength.Spacing.sm) {
            if program.isSuggested {
                DFPrimaryButton(title: "Start program") { startSuggested() }
                DFSecondaryButton(title: "Duplicate & edit") { fork() }
            } else {
                if program.isActive {
                    DFSecondaryButton(title: "Pause program") { pauseProgram() }
                } else {
                    DFPrimaryButton(title: "Start program") { activate(program) }
                }
                DFSecondaryButton(title: "Edit program") { editorTarget = program }
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Text("Leave program")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CalmStrength.Spacing.md)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private var durationText: String {
        if let weeks = program.weeks { return "\(weeks) weeks" }
        return "Ongoing"
    }

    private func metaLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(Color.dfSecondaryText)
    }

    private func dayName(_ dayOfWeek: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard dayOfWeek >= 1, dayOfWeek <= symbols.count else { return "Day \(dayOfWeek)" }
        return symbols[dayOfWeek - 1]
    }

    private func routineName(for id: UUID?) -> String {
        guard let id, let routine = routines.first(where: { $0.id == id }) else {
            return "Rest or blank session"
        }
        return routine.name
    }

    private func resolveBasedOn() {
        guard let sourceId = program.sourceTemplateId else { basedOnName = nil; return }
        let descriptor = FetchDescriptor<ProgramEntity>(predicate: #Predicate { $0.id == sourceId })
        basedOnName = (try? modelContext.fetch(descriptor).first)?.name
    }

    // MARK: - Actions

    /// Start a suggested template: create an owned, active copy (PRG-03/US-071).
    private func startSuggested() {
        let myProgramCount = (try? modelContext.fetchCount(FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.isSuggested == false }
        ))) ?? 0
        guard ContentLimitService.canCreateProgram(currentCount: myProgramCount, isPro: dependencies.userSession.isPro) else { return }

        let copy = makeOwnedCopy(active: true)
        modelContext.insert(copy)
        deactivateOthers(except: copy.id)
        copy.isActive = true
        modelContext.saveOrPresent(
            "startSuggestedProgram",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t start the program",
            message: "We couldn’t start this program just now. Please try again in a moment."
        )
        dependencies.syncEngine.enqueue(.upsertProgram(copy.id))
    }

    /// Duplicate & edit (PRG-06/US-073): owned, inactive copy opened in the builder.
    private func fork() {
        let copy = makeOwnedCopy(active: false)
        modelContext.insert(copy)
        modelContext.saveOrPresent(
            "duplicateProgram",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t duplicate the program",
            message: "We couldn’t make a copy of this program just now. Please try again in a moment."
        )
        dependencies.syncEngine.enqueue(.upsertProgram(copy.id))
        editorTarget = copy
    }

    private func makeOwnedCopy(active: Bool) -> ProgramEntity {
        let copy = ProgramEntity(
            userId: dependencies.userSession.effectiveUserId,
            name: program.name,
            category: program.category,
            isSuggested: false,
            weeks: program.weeks,
            programDescription: program.programDescription,
            level: program.level,
            daysPerWeek: program.daysPerWeek,
            equipment: program.equipment
        )
        copy.sourceTemplateId = program.id
        for day in program.days {
            let dayCopy = ProgramDayEntity(
                weekIndex: day.weekIndex,
                dayOfWeek: day.dayOfWeek,
                routineId: day.routineId,
                sortOrder: day.sortOrder
            )
            modelContext.insert(dayCopy)
            copy.days.append(dayCopy)
        }
        return copy
    }

    private func activate(_ target: ProgramEntity) {
        deactivateOthers(except: target.id)
        target.isActive = true
        target.updatedAt = Date()
        modelContext.saveOrPresent(
            "activateProgram",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t start the program",
            message: "We couldn’t start this program just now. Please try again in a moment."
        )
        dependencies.syncEngine.enqueue(.upsertProgram(target.id))
    }

    private func pauseProgram() {
        program.isActive = false
        program.updatedAt = Date()
        modelContext.saveOrPresent(
            "pauseProgram",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t pause the program",
            message: "We couldn’t pause this program just now. Please try again in a moment."
        )
        dependencies.syncEngine.enqueue(.upsertProgram(program.id))
    }

    private func leaveProgram() {
        let id = program.id
        modelContext.delete(program)
        modelContext.saveOrPresent(
            "leaveProgram",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t leave the program",
            message: "We couldn’t leave this program just now. Please try again in a moment."
        )
        dependencies.syncEngine.enqueue(.deleteEntity(id))
        dismiss()
    }

    private func deactivateOthers(except keepId: UUID) {
        let active = (try? modelContext.fetch(FetchDescriptor<ProgramEntity>(
            predicate: #Predicate { $0.isActive == true }
        ))) ?? []
        for program in active where program.id != keepId {
            program.isActive = false
        }
    }
}

extension ProgramEntity: Identifiable {}

// MARK: - Program builder

/// Create or edit a custom program: assign a routine (or rest) to each weekday
/// (PRG-04/US-072). Saving persists ProgramDayEntity rows — programs no longer
/// save with zero days.
struct ProgramEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineEntity.name) private var allRoutines: [RoutineEntity]
    @Query private var allExercises: [ExerciseEntity]

    let dependencies: DependencyContainer
    /// When set, edits this program instead of creating a new one.
    var program: ProgramEntity? = nil

    @State private var name = ""
    @State private var category: ProgramCategory = .strength
    @State private var level: ProgramLevel = .all
    @State private var isOngoing = true
    @State private var weeks = 4
    @State private var details = ""
    /// weekday (Calendar.weekday) -> assigned routine id
    @State private var assignments: [Int: UUID] = [:]
    @State private var didLoad = false

    /// Monday-first weekday ordering for display.
    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    private var routines: [RoutineEntity] {
        allRoutines.filter { $0.deletedAt == nil }
    }

    private var isEditing: Bool { program != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !assignments.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Program") {
                    TextField("Program name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ProgramCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Level", selection: $level) {
                        ForEach(ProgramLevel.allCases, id: \.self) { lvl in
                            Text(lvl.displayName).tag(lvl)
                        }
                    }
                    Toggle("Ongoing", isOn: $isOngoing)
                    if !isOngoing {
                        Stepper("Weeks: \(weeks)", value: $weeks, in: 1...12)
                    }
                }

                Section("Description") {
                    TextField("Optional summary", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    ForEach(weekdayOrder, id: \.self) { weekday in
                        Picker(dayName(weekday), selection: routineBinding(for: weekday)) {
                            Text("Rest").tag(UUID?.none)
                            ForEach(routines, id: \.id) { routine in
                                Text(routine.name).tag(UUID?.some(routine.id))
                            }
                        }
                    }
                } header: {
                    Text("Weekly schedule")
                } footer: {
                    Text("\(assignments.count) training day\(assignments.count == 1 ? "" : "s") per week.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.dfBackground)
            .navigationTitle(isEditing ? "Edit program" : "New program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadIfNeeded)
        }
    }

    private func routineBinding(for weekday: Int) -> Binding<UUID?> {
        Binding(
            get: { assignments[weekday] },
            set: { newValue in
                if let newValue { assignments[weekday] = newValue }
                else { assignments[weekday] = nil }
            }
        )
    }

    private func dayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "Day \(weekday)" }
        return symbols[weekday - 1]
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let program else { return }
        name = program.name
        category = program.category
        level = program.level ?? .all
        isOngoing = program.weeks == nil
        weeks = program.weeks ?? 4
        details = program.programDescription ?? ""
        for day in program.days {
            if let routineId = day.routineId {
                assignments[day.dayOfWeek] = routineId
            }
        }
    }

    private func deriveEquipment() -> [String] {
        let exercisesById = Dictionary(allExercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let routinesById = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var tokens: [String] = []
        var seen = Set<String>()
        for routineId in assignments.values {
            guard let routine = routinesById[routineId] else { continue }
            for item in routine.exercises {
                for token in exercisesById[item.exerciseId]?.equipment ?? [] where !seen.contains(token) {
                    seen.insert(token)
                    tokens.append(token)
                }
            }
        }
        return tokens
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target: ProgramEntity

        if let program {
            target = program
            target.name = trimmedName
            target.category = category
            target.updatedAt = Date()
            for day in target.days {
                modelContext.delete(day)
            }
            target.days.removeAll()
        } else {
            let count = (try? modelContext.fetchCount(FetchDescriptor<ProgramEntity>(
                predicate: #Predicate { $0.isSuggested == false }
            ))) ?? 0
            guard ContentLimitService.canCreateProgram(currentCount: count, isPro: dependencies.userSession.isPro) else {
                dismiss()
                return
            }
            target = ProgramEntity(
                userId: dependencies.userSession.effectiveUserId,
                name: trimmedName,
                category: category,
                isSuggested: false
            )
            modelContext.insert(target)
        }

        target.programDescription = details.trimmingCharacters(in: .whitespaces).isEmpty ? nil : details
        target.level = level
        target.weeks = isOngoing ? nil : weeks
        target.daysPerWeek = assignments.count
        target.equipment = deriveEquipment()

        for (sortOrder, weekday) in assignments.keys.sorted().enumerated() {
            let day = ProgramDayEntity(
                weekIndex: 0,
                dayOfWeek: weekday,
                routineId: assignments[weekday],
                sortOrder: sortOrder
            )
            modelContext.insert(day)
            target.days.append(day)
        }

        target.syncStatus = .pending
        modelContext.saveOrPresent(
            "saveProgramEdits",
            presenter: dependencies.errorPresenter,
            title: "Couldn’t save your changes",
            message: "We couldn’t save your changes to this program just now. Please try again in a moment."
        )
        dependencies.syncEngine.enqueue(.upsertProgram(target.id))
        dismiss()
    }
}
