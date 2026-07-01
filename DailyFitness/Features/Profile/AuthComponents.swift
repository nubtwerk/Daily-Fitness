import SwiftUI

/// Apple-styled "Sign in with Apple" button. Routes through the existing `AuthService` flow
/// (ASAuthorizationController + Supabase id-token exchange) and, on success, merges local data
/// up to the cloud. Used as the primary auth surface on the welcome screen, the cloud-sync
/// prompt, and Profile.
struct AppleSignInButton: View {
    @Bindable var dependencies: DependencyContainer
    var onSignedIn: () -> Void = {}

    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.sm) {
            Button(action: signIn) {
                HStack(spacing: CalmStrength.Spacing.sm) {
                    if isSigningIn {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                            .dfFont(.subheading)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CalmStrength.Spacing.md)
                .foregroundStyle(.white)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md))
            }
            .disabled(isSigningIn)

            if let errorMessage {
                Text(errorMessage)
                    .dfFont(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await dependencies.authService.signInWithApple()
                try await dependencies.authService.mergeLocalData(context: modelContext)
                isSigningIn = false
                onSignedIn()
            } catch {
                errorMessage = error.localizedDescription
                isSigningIn = false
            }
        }
    }
}

/// Shown once, right after the user saves their first workout, inviting them to back it up to the
/// cloud. Sign-in is always optional — the app is offline-first — so this is a soft prompt with a
/// clear "Not now".
struct CloudSyncPromptView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.lg) {
            Spacer()

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 56))
                .foregroundStyle(Color.dfAccent)

            VStack(spacing: CalmStrength.Spacing.sm) {
                Text("Back up your training")
                    .dfFont(.heading)
                    .foregroundStyle(Color.dfPrimary)
                Text("Nice first session! Sign in to sync your workouts across devices and keep them safe if you change phones.")
                    .dfFont(.body)
                    .foregroundStyle(Color.dfSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CalmStrength.Spacing.lg)
            }

            Spacer()

            AppleSignInButton(dependencies: dependencies) { dismiss() }
                .padding(.horizontal, CalmStrength.Spacing.md)

            Button("Not now") { dismiss() }
                .foregroundStyle(Color.dfSecondaryText)
                .padding(.bottom, CalmStrength.Spacing.md)
        }
        .padding(.vertical, CalmStrength.Spacing.lg)
        .background(Color.dfBackground)
    }

    /// UserDefaults flag so the prompt only ever appears once.
    static let hasPromptedKey = "hasPromptedCloudSync"

    static var shouldPrompt: Bool {
        !UserDefaults.standard.bool(forKey: hasPromptedKey)
    }

    static func markPrompted() {
        UserDefaults.standard.set(true, forKey: hasPromptedKey)
    }
}

/// Opens the system subscription-management screen (App Store → Subscriptions).
enum SubscriptionManagement {
    static let url = URL(string: "https://apps.apple.com/account/subscriptions")!
}
