import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutSessionEntity.startedAt, order: .reverse)
    private var sessions: [WorkoutSessionEntity]

    @State private var exportItem: ExportItem?
    @State private var summary = ProgressSummary()
    @State private var historyMode: HistoryMode = .list
    @State private var categoryFilter: CategoryFilter = .all

    private enum HistoryMode: Hashable { case list, calendar }

    private enum CategoryFilter: String, CaseIterable, Identifiable {
        case all, strength, mobility, yoga
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var categoryRaw: String? { self == .all ? nil : rawValue }
    }

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    private var isPro: Bool { dependencies.userSession.isPro }

    private var completedSessions: [WorkoutSessionEntity] {
        let completed = sessions.filter { $0.endedAt != nil }
        guard !isPro else { return completed }
        let cutoff = Calendar.current.date(byAdding: .day, value: -AnalyticsService.freeWindowDays, to: Date()) ?? Date()
        return completed.filter { $0.startedAt >= cutoff }
    }

    private var filteredSessions: [WorkoutSessionEntity] {
        guard let raw = categoryFilter.categoryRaw else { return completedSessions }
        return completedSessions.filter { summary.categoriesBySession[$0.id]?.contains(raw) ?? false }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    prShelf
                    mobilityYogaCard
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
                        .disabled(!isPro)
                }
            }
            .sheet(item: $exportItem) { item in
                ShareLink(item: item.url) {
                    Text("Share CSV")
                }
                .presentationDetents([.medium])
            }
            .onAppear { refreshSummary() }
            .onChange(of: sessions.count) { _, _ in refreshSummary() }
            .onChange(of: isPro) { _, _ in refreshSummary() }
        }
    }

    private func refreshSummary() {
        summary = dependencies.analyticsService.progressSummary(
            userId: dependencies.userSession.effectiveUserId,
            isPro: isPro,
            context: modelContext,
            exercises: fetchExercises()
        )
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
                    .font(.subheadline)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                ForEach(prs, id: \.id) { pr in
                    DFCard {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(prTitle(pr))
                                    .font(.headline)
                                Text(prTypeLabel(pr.type))
                                    .font(.caption)
                                    .foregroundStyle(Color.dfSecondaryText)
                            }
                            Spacer()
                            Text(String(format: "%.1f", pr.value))
                                .font(.title3.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mobilityYogaCard: some View {
        if summary.mobilityYogaSessionCount > 0 {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                DFSectionHeader(title: "Mobility & yoga")
                DFCard {
                    HStack(spacing: CalmStrength.Spacing.md) {
                        Image(systemName: "figure.mind.and.body")
                            .font(.title2)
                            .foregroundStyle(Color.dfAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(summary.mobilityYogaMinutes) min")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.dfPrimary)
                            Text("across \(summary.mobilityYogaSessionCount) session\(summary.mobilityYogaSessionCount == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(Color.dfSecondaryText)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var muscleHeatmap: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            let windowLabel = summary.muscleWindowDays.map { "\($0) days" } ?? "all time"
            DFSectionHeader(title: "Muscle volume (\(windowLabel))")
            MuscleHeatmapView(volumes: summary.muscleVolumes)
            if !isPro {
                Text("Upgrade to Pro for all-time muscle volume and trends.")
                    .font(.caption)
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "History")

            Picker("View", selection: $historyMode) {
                Text("List").tag(HistoryMode.list)
                Text("Calendar").tag(HistoryMode.calendar)
            }
            .pickerStyle(.segmented)

            if historyMode == .calendar {
                DFCard {
                    MonthCalendarView(sessionDays: summary.sessionDays)
                }
            } else {
                Picker("Filter", selection: $categoryFilter) {
                    ForEach(CategoryFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if filteredSessions.isEmpty {
                    DFEmptyState(
                        title: "No workouts yet",
                        message: "Complete a session to see your history here."
                    )
                } else {
                    ForEach(filteredSessions.prefix(20), id: \.id) { session in
                        NavigationLink {
                            SessionDetailView(session: session, dependencies: dependencies)
                        } label: {
                            DFCard {
                                VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                                    Text(session.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.dfPrimary)
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dfSecondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func prTitle(_ pr: PersonalRecordEntity) -> String {
        pr.type == .sessionVolume ? "Session volume" : exerciseName(for: pr.exerciseId)
    }

    private func prTypeLabel(_ type: PersonalRecordType) -> String {
        switch type {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .estimated1RM: return "Est. 1RM"
        case .sessionVolume: return "Total volume"
        }
    }

    private func exerciseName(for id: UUID) -> String {
        fetchExercises().first(where: { $0.id == id })?.name ?? "Exercise"
    }

    private func fetchExercises() -> [ExerciseEntity] {
        (try? modelContext.fetch(FetchDescriptor<ExerciseEntity>())) ?? []
    }

    private func exportHistory() {
        guard isPro else { return }
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
                .font(.headline)
            ExerciseChartView(
                exerciseId: workoutExercise.exerciseId,
                loggingFields: exercise?.loggingFields ?? .weightReps,
                userId: dependencies.userSession.effectiveUserId,
                isPro: dependencies.userSession.isPro,
                analyticsService: dependencies.analyticsService
            )
            ForEach(workoutExercise.sets.filter(\.isCompleted).sorted(by: { $0.setNumber < $1.setNumber }), id: \.id) { set in
                Text(setSummary(set, exercise: exercise))
                    .font(.subheadline)
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

/// Per-exercise history chart with a metric switcher (weight/reps/volume/e1RM) and a
/// free 90-day window plus an upgrade prompt at the boundary (US-092; AN-02).
struct ExerciseChartView: View {
    let exerciseId: UUID
    let loggingFields: LoggingFieldMask
    let userId: UUID
    let isPro: Bool
    let analyticsService: AnalyticsService
    @Environment(\.modelContext) private var modelContext

    @State private var series = ExerciseSeries()
    @State private var metric: ChartMetric = .weight

    var body: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            if series.availableMetrics.count > 1 {
                Picker("Metric", selection: $metric) {
                    ForEach(series.availableMetrics) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
            }

            let points = series.points(for: metric)
            if points.isEmpty {
                Text("Log sets to see this chart.")
                    .font(.caption)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.dfAccent)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(Color.dfAccent)
                }
                .frame(height: 140)
            }

            if !isPro && series.hasOlderData {
                Label("Showing last 90 days — upgrade to Pro for full history.", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
        .task(id: exerciseId) { loadSeries() }
        .onChange(of: isPro) { _, _ in loadSeries() }
    }

    private func loadSeries() {
        series = analyticsService.exerciseSeries(
            exerciseId: exerciseId,
            loggingFields: loggingFields,
            userId: userId,
            isPro: isPro,
            context: modelContext
        )
        if !series.availableMetrics.contains(metric) {
            metric = series.availableMetrics.first ?? .weight
        }
    }
}

struct MuscleHeatmapView: View {
    let volumes: [MuscleVolume]

    var body: some View {
        if volumes.isEmpty {
            Text("Log strength work to see muscle volume.")
                .font(.subheadline)
                .foregroundStyle(Color.dfSecondaryText)
        } else {
            let maxVolume = volumes.map(\.volume).max() ?? 1
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: CalmStrength.Spacing.sm) {
                ForEach(volumes) { item in
                    VStack {
                        RoundedRectangle(cornerRadius: CalmStrength.Radius.sm)
                            .fill(Color.dfAccent.opacity(max(0.12, item.volume / maxVolume)))
                            .frame(height: 40)
                        Text(item.muscle.capitalized)
                            .font(.caption)
                        Text("\(Int(item.volume))")
                            .font(.caption2)
                            .foregroundStyle(Color.dfSecondaryText)
                    }
                }
            }
        }
    }
}

/// A simple month calendar marking days with completed sessions (AN-06; US-090).
struct MonthCalendarView: View {
    let sessionDays: Set<Date>
    @State private var monthAnchor = Date()
    private let calendar = Calendar.current

    private var monthTitle: String {
        monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var days: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        var day = monthInterval.start
        while day < monthInterval.end {
            cells.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return cells
    }

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.sm) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                    .foregroundStyle(Color.dfPrimary)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .tint(Color.dfAccent)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: CalmStrength.Spacing.sm) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(Color.dfSecondaryText)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let hasSession = sessionDays.contains(calendar.startOfDay(for: day))
        let isToday = calendar.isDateInToday(day)
        return Text("\(calendar.component(.day, from: day))")
            .font(.caption)
            .foregroundStyle(hasSession ? Color.white : Color.dfPrimary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(hasSession ? Color.dfAccent : Color.clear))
            .overlay(
                Circle().strokeBorder(isToday && !hasSession ? Color.dfAccent : Color.clear, lineWidth: 1)
            )
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = next
        }
    }
}
