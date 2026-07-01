import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: ExerciseEntity
    /// When provided (e.g. from the routine builder's picker), shows a direct
    /// "Add to routine" button that calls back instead of choosing a routine.
    var onAdd: ((ExerciseEntity) -> Void)? = nil

    @State private var lastPerformed: String?
    @State private var showEditor = false
    @State private var showAddToRoutine = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                ExerciseImageView(imageURL: exercise.imageURL, category: exercise.category, cornerRadius: CalmStrength.Radius.lg)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                    HStack {
                        Text(exercise.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.dfPrimary)
                        if exercise.isCustom {
                            CustomBadge()
                        }
                    }
                    Label(exercise.category.displayName, systemImage: exercise.category.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(Color.dfSecondaryText)
                }

                if let lastPerformed {
                    DFCard {
                        HStack(spacing: CalmStrength.Spacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color.dfAccent)
                            Text("Last: \(lastPerformed)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dfPrimary)
                        }
                    }
                }

                metadataSection(title: "Primary muscles", tokens: exercise.primaryMuscles, display: MuscleGroup.displayName(forToken:))
                metadataSection(title: "Equipment", tokens: exercise.equipment, display: Equipment.displayName(forToken:))

                if let onAdd {
                    DFPrimaryButton(title: "Add to routine") {
                        onAdd(exercise)
                        dismiss()
                    }
                } else {
                    DFPrimaryButton(title: "Add to routine…") {
                        showAddToRoutine = true
                    }
                }
            }
            .padding(CalmStrength.Spacing.md)
        }
        .background(Color.dfBackground)
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if exercise.isCustom {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditor = true }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            CustomExerciseEditorView(
                userId: dependencies.userSession.effectiveUserId,
                isPro: dependencies.userSession.isPro,
                existing: exercise,
                onDeleted: { dismiss() }
            )
        }
        .sheet(isPresented: $showAddToRoutine) {
            AddToRoutineSheet(dependencies: dependencies, exercise: exercise)
        }
        .task(id: exercise.id) { loadLastPerformed() }
    }

    @ViewBuilder
    private func metadataSection(title: String, tokens: [String], display: (String) -> String) -> some View {
        if !tokens.isEmpty {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                DFSectionHeader(title: title)
                FlowChips(items: tokens.map(display))
            }
        }
    }

    private func loadLastPerformed() {
        let id = exercise.id
        let descriptor = FetchDescriptor<WorkoutExerciseEntity>(
            predicate: #Predicate { $0.exerciseId == id }
        )
        guard let workoutExercises = try? modelContext.fetch(descriptor) else {
            lastPerformed = nil
            return
        }
        let completed = workoutExercises
            .flatMap(\.sets)
            .filter { $0.isCompleted && $0.completedAt != nil }
        guard let latest = completed.max(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }) else {
            lastPerformed = nil
            return
        }
        lastPerformed = format(set: latest)
    }

    private func format(set: WorkoutSetEntity) -> String? {
        let usePounds = dependencies.preferencesRepository
            .loadOrCreate(userId: dependencies.userSession.effectiveUserId, context: modelContext)
            .usePounds
        switch exercise.loggingFields {
        case .weightReps:
            guard let reps = set.reps else { return nil }
            let weight = WeightFormatter.display(kg: set.weightKg ?? 0, usePounds: usePounds)
            return "\(weight) × \(reps)"
        case .duration:
            guard let seconds = set.durationSeconds ?? set.holdSeconds else { return nil }
            return formatSeconds(seconds)
        case .hold, .side:
            guard let seconds = set.holdSeconds ?? set.durationSeconds else { return nil }
            return formatSeconds(seconds)
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60, s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }
}

struct CustomBadge: View {
    var body: some View {
        Text("Custom")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.dfAccent.opacity(0.2))
            .clipShape(Capsule())
    }
}

/// Simple wrapping chip row for muscle/equipment tags.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: CalmStrength.Spacing.sm) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, CalmStrength.Spacing.md)
                    .padding(.vertical, CalmStrength.Spacing.sm)
                    .background(Color.dfSurface)
                    .foregroundStyle(Color.dfPrimary)
                    .clipShape(Capsule())
            }
        }
    }
}

/// Lightweight flow layout (left-to-right, wrapping) for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Sheet for adding an exercise to an existing routine, or starting a new one.
struct AddToRoutineSheet: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineEntity.name) private var routinesRaw: [RoutineEntity]

    let exercise: ExerciseEntity

    private var routines: [RoutineEntity] {
        routinesRaw.filter { $0.deletedAt == nil && !$0.isSuggested }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        createRoutine()
                    } label: {
                        Label("New routine with this exercise", systemImage: "plus.circle.fill")
                    }
                }
                if !routines.isEmpty {
                    Section("Add to") {
                        ForEach(routines, id: \.id) { routine in
                            Button {
                                add(to: routine)
                            } label: {
                                HStack {
                                    Text(routine.name).foregroundStyle(Color.dfPrimary)
                                    Spacer()
                                    Text("\(routine.exercises.count)")
                                        .foregroundStyle(Color.dfSecondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func makeRoutineExercise(sortOrder: Int) -> RoutineExerciseEntity {
        let isStrength = exercise.category == .strength
        return RoutineExerciseEntity(
            sortOrder: sortOrder,
            exerciseId: exercise.id,
            targetSets: 3,
            targetRepsMin: isStrength ? 8 : nil,
            targetRepsMax: isStrength ? 12 : nil,
            targetDurationSeconds: isStrength ? nil : 60,
            restSeconds: isStrength ? 90 : 30
        )
    }

    private func add(to routine: RoutineEntity) {
        let item = makeRoutineExercise(sortOrder: routine.exercises.count)
        modelContext.insert(item)
        routine.exercises.append(item)
        routine.updatedAt = Date()
        routine.syncStatus = .pending
        try? modelContext.save()
        dependencies.syncEngine.enqueue(.upsertRoutine(routine.id))
        dismiss()
    }

    private func createRoutine() {
        let routine = RoutineEntity(
            userId: dependencies.userSession.effectiveUserId,
            name: exercise.name
        )
        modelContext.insert(routine)
        let item = makeRoutineExercise(sortOrder: 0)
        modelContext.insert(item)
        routine.exercises.append(item)
        routine.syncStatus = .pending
        try? modelContext.save()
        dependencies.syncEngine.enqueue(.upsertRoutine(routine.id))
        dismiss()
    }
}
