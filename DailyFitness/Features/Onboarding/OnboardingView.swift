import SwiftUI

struct OnboardingView: View {
    @Bindable var dependencies: DependencyContainer
    @State private var step = 0
    @State private var selectedTypes: Set<ExerciseCategory> = [.strength]

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.lg) {
            Spacer()

            switch step {
            case 0:
                welcomeStep
            case 1:
                trainingTypesStep
            default:
                finishStep
            }

            Spacer()

            DFPrimaryButton(title: step < 2 ? "Continue" : "Get started") {
                if step < 2 {
                    step += 1
                } else {
                    completeOnboarding()
                }
            }
            .padding(.horizontal, CalmStrength.Spacing.md)

            if step > 0 && step < 2 {
                Button("Skip") { step = 2 }
                    .foregroundStyle(Color.dfSecondaryText)
            }
        }
        .padding(.vertical, CalmStrength.Spacing.lg)
        .background(Color.dfBackground)
    }

    private var welcomeStep: some View {
        VStack(spacing: CalmStrength.Spacing.md) {
            Text("DailyFitness")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Color.dfPrimary)
            Text("Your daily training — strength, mobility, and yoga in one calm app.")
                .font(.body)
                .foregroundStyle(Color.dfSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CalmStrength.Spacing.lg)
        }
    }

    private var trainingTypesStep: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.md) {
            Text("What do you train?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.dfPrimary)

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

    private var finishStep: some View {
        VStack(spacing: CalmStrength.Spacing.md) {
            Text("You're ready")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.dfPrimary)
            Text("Start your first session from Home. Enable Lock Screen controls anytime in Profile.")
                .font(.body)
                .foregroundStyle(Color.dfSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CalmStrength.Spacing.lg)
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dependencies.router.showOnboarding = false
    }
}
