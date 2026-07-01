import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Bindable var dependencies: DependencyContainer
    var context: PaywallContext = .general

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var offerings: Offerings?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var package: Package? { offerings?.current?.availablePackages.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalmStrength.Spacing.lg) {
                    header
                    comparisonTable
                    purchaseSection
                    footer
                }
                .padding(CalmStrength.Spacing.md)
            }
            .background(Color.dfBackground)
            .navigationTitle("DailyFitness Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadOfferings() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
            Text(context.headline)
                .dfFont(.title)
                .foregroundStyle(Color.dfPrimary)
            Text(context.subheadline)
                .dfFont(.body)
                .foregroundStyle(Color.dfSecondaryText)
        }
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feature").dfFont(.captionStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free").dfFont(.captionStrong)
                    .frame(width: 64)
                Text("Pro").dfFont(.captionStrong)
                    .frame(width: 80)
                    .foregroundStyle(Color.dfAccent)
            }
            .foregroundStyle(Color.dfSecondaryText)
            .padding(.vertical, CalmStrength.Spacing.sm)

            ForEach(ProFeature.all) { feature in
                let highlighted = feature.title == context.highlightedFeature
                HStack {
                    Text(feature.title)
                        .dfFont(.callout)
                        .foregroundStyle(Color.dfPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(feature.free)
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                        .frame(width: 64)
                    Text(feature.pro)
                        .dfFont(highlighted ? .captionStrong : .caption)
                        .foregroundStyle(Color.dfAccent)
                        .frame(width: 80)
                }
                .padding(.vertical, CalmStrength.Spacing.sm)
                .padding(.horizontal, CalmStrength.Spacing.sm)
                .background(highlighted ? Color.dfAccent.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.sm))
            }
        }
        .padding(CalmStrength.Spacing.sm)
        .background(Color.dfSurface)
        .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md))
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity)
        } else if let package {
            VStack(spacing: CalmStrength.Spacing.sm) {
                if let trial = trialText(for: package) {
                    Text(trial)
                        .dfFont(.callout)
                        .foregroundStyle(Color.dfPrimary)
                        .frame(maxWidth: .infinity)
                }
                DFPrimaryButton(title: purchaseButtonTitle(for: package)) {
                    purchase(package)
                }
                .disabled(isPurchasing)
                if hasFreeTrial(package) {
                    Text("Cancel anytime. \(package.storeProduct.localizedPriceString) after the trial.")
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            Text("Subscriptions are unavailable in this build.")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
        }
    }

    private var footer: some View {
        VStack(spacing: CalmStrength.Spacing.sm) {
            Button("Restore purchases") {
                Task {
                    try? await dependencies.revenueCatService.restorePurchases()
                    if dependencies.userSession.isPro { dismiss() }
                }
            }
            .frame(maxWidth: .infinity)

            Button("Manage subscription") {
                openURL(SubscriptionManagement.url)
            }
            .dfFont(.caption)
            .foregroundStyle(Color.dfSecondaryText)
            .frame(maxWidth: .infinity)

            if let errorMessage {
                Text(errorMessage)
                    .dfFont(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Trial / pricing helpers

    private func hasFreeTrial(_ package: Package) -> Bool {
        package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
    }

    private func trialText(for package: Package) -> String? {
        guard let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        return "\(periodText(intro.subscriptionPeriod)) free trial"
    }

    private func purchaseButtonTitle(for package: Package) -> String {
        if hasFreeTrial(package) {
            return "Start free trial"
        }
        return "Subscribe — \(package.storeProduct.localizedPriceString)"
    }

    private func periodText(_ period: SubscriptionPeriod) -> String {
        let value = period.value
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: return value == 1 ? "7-day" : "\(value)-week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return "\(value)-\(unit)"
    }

    // MARK: - Actions

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
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                try await dependencies.revenueCatService.purchase(package: package)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
