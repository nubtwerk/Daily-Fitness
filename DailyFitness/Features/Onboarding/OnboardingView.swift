import SwiftUI
import SwiftData

/// Four-screen onboarding (PRD §10.4 / US-030/031):
///   0. Welcome — Sign in with Apple (primary) or continue without an account.
///   1. Training types — multi-select; the selection is persisted and drives screen 2.
///   2. Suggested program — filtered to the chosen training types; picking one activates it.
///   3. Lock Screen opt-in — enables Live Activities, then drops into Home.
struct OnboardingView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<ProgramEntity> { $0.isSuggested == true })
    private var suggestedPrograms: [ProgramEntity]

    @State private var step = 0
    @State private var selectedTypes: Set<ExerciseCategory> = [.strength]
    @State private var selectedProgramId: UUID?
    @State private var lockScreenEnabled = true

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    private var matchingPrograms: [ProgramEntity] {
        let typeRaws = Set(selectedTypes.map(\.rawValue))
        return suggestedPrograms.filter { program in
            program.category == .hybrid || typeRaws.contains(program.category.rawValue)
        }
    }

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.lg) {
            ProgressDots(total: 4, current: step)
                .padding(.top, CalmStrength.Spacing.lg)

            Spacer(minLength: 0)

            switch step {
            case 0: welcomeStep
            case 1: trainingTypesStep
            case 2: programPickerStep
            default: lockScreenStep
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(.vertical, CalmStrength.Spacing.lg)
        .background(Color.dfBackground)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: CalmStrength.Spacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(Color.dfAccent)
            Text("DailyFitness")
                .dfFont(.title)
                .foregroundStyle(Color.dfPrimary)
            Text("Your daily training — strength, mobility, and yoga in one calm app.")
                .dfFont(.body)
                .foregroundStyle(Color.dfSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CalmStrength.Spacing.lg)
        }
    }

    private var trainingTypesStep: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.md) {
            Text("What do you train?")
                .dfFont(.heading)
                .foregroundStyle(Color.dfPrimary)
            Text("We'll tailor your suggested programs.")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)

            ForEach([ExerciseCategory.strength, .mobility, .yoga, .flexibility], id: \.self) { type in
                Toggle(type.rawValue.capitalized, isOn: Binding(
                    get: { selectedTypes.contains(type) },
                    set: { isOn in
                        if isOn { selectedTypes.insert(type) } else { selectedTypes.remove(type) }
                    }
                ))
            }
        }
        .padding(.horizontal, CalmStrength.Spacing.lg)
    }

    private var programPickerStep: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.md) {
            Text("Pick a starting program")
                .dfFont(.heading)
                .foregroundStyle(Color.dfPrimary)

            if matchingPrograms.isEmpty {
                Text("Suggested programs are still loading. You can choose one anytime from the Programs tab.")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                Text("Tap one to start, or skip and explore later.")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
                ScrollView {
                    VStack(spacing: CalmStrength.Spacing.sm) {
                        ForEach(matchingPrograms, id: \.id) { program in
                            programOption(program)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CalmStrength.Spacing.lg)
    }

    private func programOption(_ program: ProgramEntity) -> some View {
        let isSelected = selectedProgramId == program.id
        return Button {
            selectedProgramId = isSelected ? nil : program.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                    Text(program.name)
                        .dfFont(.subheading)
                        .foregroundStyle(Color.dfPrimary)
                    Text(program.category.rawValue.capitalized)
                        .dfFont(.callout)
                        .foregroundStyle(Color.dfSecondaryText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.dfAccent : Color.dfSecondaryText)
            }
            .padding(CalmStrength.Spacing.md)
            .background(Color.dfSurface)
            .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CalmStrength.Radius.md)
                    .stroke(isSelected ? Color.dfAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var lockScreenStep: some View {
        VStack(spacing: CalmStrength.Spacing.md) {
            Image(systemName: "lock.iphone")
                .font(.system(size: 56))
                .foregroundStyle(Color.dfAccent)
            Text("Control workouts from the Lock Screen")
                .dfFont(.heading)
                .foregroundStyle(Color.dfPrimary)
                .multilineTextAlignment(.center)
            Text("Log sets and rest without unlocking, using Live Activities.")
                .dfFont(.body)
                .foregroundStyle(Color.dfSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CalmStrength.Spacing.lg)

            Toggle("Enable Lock Screen workouts", isOn: $lockScreenEnabled)
                .padding(.horizontal, CalmStrength.Spacing.lg)
                .padding(.top, CalmStrength.Spacing.sm)
        }
    }

    // MARK: - Footer / navigation

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: CalmStrength.Spacing.sm) {
            if step == 0 {
                AppleSignInButton(dependencies: dependencies) { step = 1 }
                    .padding(.horizontal, CalmStrength.Spacing.md)
                Button("Continue without an account") { step = 1 }
                    .foregroundStyle(Color.dfSecondaryText)
            } else {
                DFPrimaryButton(title: step < 3 ? "Continue" : "Start first session") {
                    advance()
                }
                .padding(.horizontal, CalmStrength.Spacing.md)

                if step == 2 {
                    Button("Skip for now") { advance() }
                        .foregroundStyle(Color.dfSecondaryText)
                }
            }
        }
    }

    private func advance() {
        if step == 1 { persistTrainingTypes() }
        if step == 2, let id = selectedProgramId,
           let program = matchingPrograms.first(where: { $0.id == id }) {
            activate(program)
        }
        if step < 3 {
            step += 1
        } else {
            completeOnboarding()
        }
    }

    private func persistTrainingTypes() {
        UserDefaults.standard.set(selectedTypes.map(\.rawValue), forKey: OnboardingState.trainingTypesKey)
    }

    /// Adopts a suggested program: copies it to an owned program, marks it active, and enqueues a
    /// push. Mirrors ProgramDetailView.startProgram (no limit check — it's the user's first).
    private func activate(_ program: ProgramEntity) {
        let owned = ProgramEntity(
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
            modelContext.insert(copy)
            owned.days.append(copy)
        }
        owned.isActive = true
        owned.syncStatus = .pending
        modelContext.insert(owned)
        try? modelContext.save()
        dependencies.syncEngine.enqueue(.upsertProgram(owned.id))
    }

    private func completeOnboarding() {
        persistTrainingTypes()
        let prefs = dependencies.preferencesRepository.loadOrCreate(
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        prefs.liveActivitiesEnabled = lockScreenEnabled
        try? modelContext.save()
        LiveActivityManager.shared.setEnabled(lockScreenEnabled)

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dependencies.router.selectedTab = .home
        dependencies.router.showOnboarding = false
    }
}

/// Persisted onboarding selections, reusable elsewhere (e.g. to personalise Home).
enum OnboardingState {
    static let trainingTypesKey = "onboardingTrainingTypes"

    static var trainingTypes: [ExerciseCategory] {
        (UserDefaults.standard.array(forKey: trainingTypesKey) as? [String] ?? [])
            .compactMap(ExerciseCategory.init(rawValue:))
    }
}

private struct ProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.dfAccent : Color.dfSecondaryText.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
