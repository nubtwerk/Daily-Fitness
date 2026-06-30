import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutSessionEntity.startedAt, order: .reverse)
    private var sessions: [WorkoutSessionEntity]

    @State private var showExport = false
    @State private var exportItem: ExportItem?

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    private var completedSessions: [WorkoutSessionEntity] {
        let completed = sessions.filter { $0.endedAt != nil }
        guard !dependencies.userSession.isPro else { return completed }
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return completed.filter { $0.startedAt >= cutoff }
    }

    private var heatmapDays: Int {
        dependencies.userSession.isPro ? 30 : 7
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    prShelf
                    muscleHeatmap
                    historySection
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export") { exportHistory() }
                        .disabled(!dependencies.userSession.isPro)
                }
            }
            .sheet(item: $exportItem) { item in
                ShareLink(item: item.url) {
                    Text("Share CSV")
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var prShelf: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "Recent PRs")
            let prs = dependencies.prService.recentPRs(
                userId: dependencies.userSession.effectiveUserId,
                limit: 5,
                context: modelContext
            )
            if prs.isEmpty {
                Text("Complete strength sets to track personal records.")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(prs, id: \.id) { pr in
                    DFCard {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(exerciseName(for: pr.exerciseId))
                                    .dfFont(.subheading)
                                Text(pr.type.rawValue.capitalized)
                                    .dfFont(.caption)
                                    .foregroundStyle(Color.dfSecondaryText)
                            }
                            Spacer()
                            Text(String(format: "%.1f", pr.value))
                                .dfFont(.heading)
                        }
                    }
                }
            }
        }
    }

    private var muscleHeatmap: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "Muscle volume (\(heatmapDays) days)")
            MuscleHeatmapView(
                sessions: completedSessions,
                exercises: fetchExercises(),
                dayWindow: heatmapDays
            )
            if !dependencies.userSession.isPro {
                Text("Upgrade to Pro for 30-day muscle trends.")
                    .dfFont(.caption)
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "History")
            if completedSessions.isEmpty {
                DFEmptyState(
                    title: "No workouts yet",
                    message: "Complete a session to see your history here."
                )
            } else {
                ForEach(completedSessions.prefix(20), id: \.id) { session in
                    NavigationLink {
                        SessionDetailView(session: session, dependencies: dependencies)
                    } label: {
                        DFCard {
                            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                                Text(session.name)
                                    .dfFont(.subheading)
                                    .foregroundStyle(Color.dfPrimary)
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .dfFont(.callout)
                                    .foregroundStyle(Color.dfSecondaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exerciseName(for id: UUID) -> String {
        fetchExercises().first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func fetchExercises() -> [ExerciseEntity] {
        (try? modelContext.fetch(FetchDescriptor<ExerciseEntity>())) ?? []
    }

    private func exportHistory() {
        guard dependencies.userSession.isPro else { return }
        if let url = WorkoutExportService.exportCSV(
            sessions: completedSessions,
            exercises: fetchExercises(),
            userId: dependencies.userSession.effectiveUserId
        ) {
            exportItem = ExportItem(url: url)
        }
    }
}

struct SessionDetailView: View {
    let session: WorkoutSessionEntity
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [ExerciseEntity]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                summaryCard
                ForEach(session.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { workoutExercise in
                    exerciseSection(workoutExercise)
                }
            }
            .padding(CalmStrength.Spacing.md)
        }
        .background(Color.dfBackground)
        .navigationTitle(session.name)
    }

    private var summaryCard: some View {
        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                if let ended = session.endedAt {
                    Text("Duration: \(Int(ended.timeIntervalSince(session.startedAt) / 60)) min")
                }
                Text("\(session.exercises.count) exercises")
            }
        }
    }

    @ViewBuilder
    private func exerciseSection(_ workoutExercise: WorkoutExerciseEntity) -> some View {
        let exercise = exercises.first(where: { $0.id == workoutExercise.exerciseId })
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            Text(exercise?.name ?? "Exercise")
                .dfFont(.subheading)
            ExerciseChartView(
                exerciseId: workoutExercise.exerciseId,
                userId: dependencies.userSession.effectiveUserId,
                context: modelContext,
                isPro: dependencies.userSession.isPro
            )
            ForEach(workoutExercise.sets.filter(\.isCompleted).sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                Text(setSummary(set, exercise: exercise))
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
    }

    private func setSummary(_ set: WorkoutSetEntity, exercise: ExerciseEntity?) -> String {
        switch exercise?.loggingFields ?? .weightReps {
        case .weightReps:
            return "Set \(set.setNumber): \(WeightFormatter.display(kg: set.weightKg ?? 0, usePounds: false)) × \(set.reps ?? 0)"
        case .duration:
            return "Set \(set.setNumber): \(set.durationSeconds ?? 0)s"
        case .hold, .side:
            return "Set \(set.setNumber): \(set.holdSeconds ?? 0)s hold"
        }
    }
}

struct ExerciseChartView: View {
    let exerciseId: UUID
    let userId: UUID
    let context: ModelContext
    let isPro: Bool

    private var dataPoints: [(Date, Double)] {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        var points: [(Date, Double)] = []
        for session in sessions {
            for workoutExercise in session.exercises where workoutExercise.exerciseId == exerciseId {
                for set in workoutExercise.sets where set.isCompleted {
                    if let weight = set.weightKg, weight > 0 {
                        points.append((set.completedAt ?? session.startedAt, weight))
                    }
                }
            }
        }
        return points.suffix(20).map { $0 }
    }

    var body: some View {
        if !isPro {
            Text("Charts available with Pro")
                .dfFont(.caption)
                .foregroundStyle(Color.dfSecondaryText)
        } else if dataPoints.isEmpty {
            EmptyView()
        } else {
            Chart(dataPoints, id: \.0) { point in
                LineMark(
                    x: .value("Date", point.0),
                    y: .value("Weight", point.1)
                )
                .foregroundStyle(Color.dfAccent)
            }
            .frame(height: 120)
        }
    }
}

struct MuscleHeatmapView: View {
    let sessions: [WorkoutSessionEntity]
    let exercises: [ExerciseEntity]
    var dayWindow: Int = 7

    private var volumeByMuscle: [String: Double] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -dayWindow, to: Date()) ?? Date()
        var volumes: [String: Double] = [:]
        for session in sessions where session.startedAt >= cutoff {
            for workoutExercise in session.exercises {
                guard let exercise = exercises.first(where: { $0.id == workoutExercise.exerciseId }) else { continue }
                // Warmups excluded from volume totals (LOG-07 / US-054).
                let volume = WorkoutMetrics.strengthVolume(for: workoutExercise)
                for muscle in exercise.primaryMuscles {
                    volumes[muscle, default: 0] += volume
                }
            }
        }
        return volumes
    }

    var body: some View {
        if volumeByMuscle.isEmpty {
            Text("Log strength work to see muscle volume.")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
        } else {
            let maxVolume = volumeByMuscle.values.max() ?? 1
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: CalmStrength.Spacing.sm) {
                ForEach(volumeByMuscle.sorted(by: { $0.value > $1.value }), id: \.key) { muscle, volume in
                    VStack {
                        RoundedRectangle(cornerRadius: CalmStrength.Radius.sm)
                            .fill(Color.dfAccent.opacity(volume / maxVolume))
                            .frame(height: 40)
                        Text(muscle.capitalized)
                            .dfFont(.caption)
                        Text("\(Int(volume))")
                            .dfFont(.micro)
                            .foregroundStyle(Color.dfSecondaryText)
                    }
                }
            }
        }
    }
}
