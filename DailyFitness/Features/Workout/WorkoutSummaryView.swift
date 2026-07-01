import SwiftUI
import SwiftData

/// End-of-workout summary shown before the session is saved (LOG-10 / US-055).
///
/// Surfaces what the athlete accomplished — duration, volume / total time,
/// exercises completed, and any new PRs — and lets them add a workout note
/// before committing. No social share prompt (out of scope).
struct WorkoutSummaryView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext

    let session: WorkoutSessionEntity
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var note: String = ""
    @State private var didLoadNote = false
    @State private var showDiscardConfirm = false

    private var usePounds: Bool {
        let prefs = dependencies.preferencesRepository.loadOrCreate(
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        return prefs.usePounds
    }

    private var personalRecords: [PersonalRecordEntity] {
        dependencies.prService.records(forSession: session.id, context: modelContext)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    headline
                    statsGrid
                    if !personalRecords.isEmpty {
                        prHighlights
                    }
                    noteEditor
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("Workout complete")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: CalmStrength.Spacing.sm) {
                    DFPrimaryButton(title: "Save workout") {
                        commitNote()
                        onSave()
                    }
                    Button("Discard", role: .destructive) { showDiscardConfirm = true }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .padding(CalmStrength.Spacing.md)
                .background(.ultraThinMaterial)
            }
            .confirmationDialog(
                "Discard this workout?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard workout", role: .destructive) { onDiscard() }
                Button("Keep logging", role: .cancel) {}
            } message: {
                Text("Your logged sets for this session will be deleted.")
            }
            .onAppear {
                guard !didLoadNote else { return }
                note = session.note ?? ""
                didLoadNote = true
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
            Text(session.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.dfPrimary)
            Text("Nice work — here's the recap.")
                .font(.subheadline)
                .foregroundStyle(Color.dfSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: CalmStrength.Spacing.sm
        ) {
            statCard(title: "Duration", value: durationText)
            statCard(title: "Exercises", value: "\(WorkoutMetrics.completedExerciseCount(for: session))")
            statCard(title: "Working sets", value: "\(WorkoutMetrics.completedWorkingSetCount(for: session))")
            if strengthVolumeKg > 0 {
                statCard(title: "Volume", value: volumeText)
            }
            if timedSeconds > 0 {
                statCard(title: "Total time", value: timedText)
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        DFCard {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.dfPrimary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.dfSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var prHighlights: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "New personal records")
            ForEach(personalRecords, id: \.id) { pr in
                DFCard {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Color.dfAccent)
                        VStack(alignment: .leading) {
                            Text(exerciseName(for: pr.exerciseId))
                                .font(.headline)
                                .foregroundStyle(Color.dfPrimary)
                            Text(prDescription(pr))
                                .font(.caption)
                                .foregroundStyle(Color.dfSecondaryText)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            DFSectionHeader(title: "Workout note")
            TextField("How did it go? (optional)", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Derived values

    private var durationText: String {
        let seconds = Int(Date().timeIntervalSince(session.startedAt))
        let minutes = max(0, seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var strengthVolumeKg: Double { WorkoutMetrics.totalStrengthVolume(for: session) }

    private var volumeText: String {
        let value = usePounds ? strengthVolumeKg * 2.20462 : strengthVolumeKg
        let unit = usePounds ? "lb" : "kg"
        return "\(Int(value.rounded())) \(unit)"
    }

    private var timedSeconds: Int { WorkoutMetrics.totalTimedSeconds(for: session) }

    private var timedText: String {
        let minutes = timedSeconds / 60
        let seconds = timedSeconds % 60
        if minutes == 0 { return "\(seconds)s" }
        return "\(minutes)m \(seconds)s"
    }

    private func commitNote() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        session.note = trimmed.isEmpty ? nil : trimmed
    }

    private func exerciseName(for id: UUID) -> String {
        let descriptor = FetchDescriptor<ExerciseEntity>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor).first?.name) ?? "Exercise"
    }

    private func prDescription(_ pr: PersonalRecordEntity) -> String {
        switch pr.type {
        case .weight:
            return "Top weight · \(WeightFormatter.display(kg: pr.value, usePounds: usePounds))"
        case .reps:
            return "Most reps · \(Int(pr.value))"
        case .estimated1RM:
            return "Est. 1RM · \(WeightFormatter.display(kg: pr.value, usePounds: usePounds))"
        case .sessionVolume:
            return "Session volume PR"
        }
    }
}
