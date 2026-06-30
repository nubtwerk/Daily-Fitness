import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferencesEntity]

    @State private var usePounds: Bool = Locale.current.measurementSystem != .metric
    @State private var rirEnabled = false
    @State private var liveActivitiesEnabled = true
    @State private var defaultRestSeconds = 90
    @State private var restEndNotificationEnabled = false
    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var authError: String?
    @State private var isSigningIn = false

    init(dependencies: DependencyContainer) {
        self._dependencies = Bindable(wrappedValue: dependencies)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Training") {
                    Toggle("Use pounds (lb)", isOn: $usePounds)
                    Toggle("RIR tracking", isOn: $rirEnabled)
                    Toggle("Lock Screen workout", isOn: $liveActivitiesEnabled)
                    Stepper("Default rest: \(defaultRestSeconds)s", value: $defaultRestSeconds, in: 30...300, step: 15)
                    Toggle("Rest end notification", isOn: $restEndNotificationEnabled)
                }

                Section("Sync") {
                    LabeledContent("Status", value: syncStatusLabel)
                    if dependencies.syncEngine.pendingCount > 0 {
                        Text("\(dependencies.syncEngine.pendingCount) items pending upload")
                            .dfFont(.caption)
                            .foregroundStyle(Color.dfSecondaryText)
                    }
                    Button("Sync now") {
                        Task {
                            try? await dependencies.syncEngine.flush(context: modelContext)
                            try? await dependencies.syncEngine.pullRemoteChanges(since: nil, context: modelContext)
                        }
                    }
                    .disabled(!dependencies.userSession.isAuthenticated)
                }

                Section("Account") {
                    if dependencies.userSession.isAuthenticated {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                        Button("Sign out", role: .destructive) {
                            Task { try? await dependencies.authService.signOut() }
                        }
                        Button("Delete account & local data", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } else {
                        Button {
                            signIn()
                        } label: {
                            if isSigningIn {
                                ProgressView()
                            } else {
                                Text("Sign in with Apple")
                            }
                        }
                        .disabled(isSigningIn)
                    }
                    if let authError {
                        Text(authError)
                            .dfFont(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Subscription") {
                    if dependencies.userSession.isPro {
                        Text("DailyFitness Pro")
                    } else {
                        Button("Upgrade to Pro") { showPaywall = true }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.dfBackground)
            .navigationTitle("Profile")
            .onAppear(perform: loadPreferences)
            .onChange(of: usePounds) { _, _ in savePreferences() }
            .onChange(of: rirEnabled) { _, _ in savePreferences() }
            .onChange(of: liveActivitiesEnabled) { _, _ in savePreferences() }
            .onChange(of: defaultRestSeconds) { _, _ in savePreferences() }
            .onChange(of: restEndNotificationEnabled) { _, _ in savePreferences() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(dependencies: dependencies)
            }
            .confirmationDialog(
                "Delete account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete account & data", role: .destructive) {
                    Task {
                        try? await dependencies.authService.deleteAccount(context: modelContext)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your local workouts and signs you out. Cloud data may remain until server deletion is configured.")
            }
        }
    }

    private var syncStatusLabel: String {
        if !dependencies.userSession.isAuthenticated { return "Local only" }
        if dependencies.syncEngine.pendingCount > 0 { return "Pending" }
        return "Synced"
    }

    private func loadPreferences() {
        let prefs = dependencies.preferencesRepository.loadOrCreate(
            userId: dependencies.userSession.effectiveUserId,
            context: modelContext
        )
        usePounds = prefs.usePounds
        rirEnabled = prefs.rirEnabled
        liveActivitiesEnabled = prefs.liveActivitiesEnabled
        defaultRestSeconds = prefs.defaultRestSeconds
        restEndNotificationEnabled = prefs.restEndNotificationEnabled
        LiveActivityManager.shared.setEnabled(liveActivitiesEnabled)
    }

    private func savePreferences() {
        dependencies.preferencesRepository.save(
            userId: dependencies.userSession.effectiveUserId,
            usePounds: usePounds,
            rirEnabled: rirEnabled,
            liveActivitiesEnabled: liveActivitiesEnabled,
            restEndNotificationEnabled: restEndNotificationEnabled,
            defaultRestSeconds: defaultRestSeconds,
            context: modelContext
        )
        LiveActivityManager.shared.setEnabled(liveActivitiesEnabled)
    }

    private func signIn() {
        isSigningIn = true
        authError = nil
        Task {
            do {
                try await dependencies.authService.signInWithApple()
                try await dependencies.authService.mergeLocalData(context: modelContext)
            } catch {
                authError = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
