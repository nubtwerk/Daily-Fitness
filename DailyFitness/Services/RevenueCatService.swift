import Foundation
import RevenueCat

@MainActor
final class RevenueCatService {
    private let userSession: UserSession
    private static let proEntitlement = "pro"

    init(userSession: UserSession) {
        self.userSession = userSession
    }

    func configure() {
        let apiKey = AppConfig.revenueCatAPIKey
        guard !apiKey.isEmpty else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey, appUserID: userSession.localUserId.uuidString)
        Task { await refreshEntitlements() }
    }

    func refreshEntitlements() async {
        guard !AppConfig.revenueCatAPIKey.isEmpty else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            userSession.isPro = info.entitlements[Self.proEntitlement]?.isActive == true
        } catch {
            userSession.isPro = false
        }
    }

    func offerings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    func purchase(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        userSession.isPro = result.customerInfo.entitlements[Self.proEntitlement]?.isActive == true
    }

    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        userSession.isPro = info.entitlements[Self.proEntitlement]?.isActive == true
    }
}
