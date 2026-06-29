import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    @State private var offerings: Offerings?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    Text("DailyFitness Pro")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Color.dfPrimary)

                    Text("Train without limits — unlimited routines, full progression, and export.")
                        .font(.body)
                        .foregroundStyle(Color.dfSecondaryText)

                    featureRow("Unlimited custom exercises")
                    featureRow("Unlimited routines & programs")
                    featureRow("Progression for all strength exercises")
                    featureRow("Advanced progress charts")
                    featureRow("CSV workout export")

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let package = offerings?.current?.availablePackages.first {
                        DFPrimaryButton(title: "Subscribe — \(package.storeProduct.localizedPriceString)") {
                            purchase(package)
                        }
                    } else {
                        Text("Subscriptions unavailable in this build.")
                            .font(.subheadline)
                            .foregroundStyle(Color.dfSecondaryText)
                    }

                    Button("Restore purchases") {
                        Task {
                            try? await dependencies.revenueCatService.restorePurchases()
                            if dependencies.userSession.isPro { dismiss() }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadOfferings() }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.dfAccent)
            Text(text)
                .foregroundStyle(Color.dfPrimary)
        }
    }

    private func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            offerings = try await dependencies.revenueCatService.offerings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchase(_ package: Package) {
        Task {
            do {
                try await dependencies.revenueCatService.purchase(package: package)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
