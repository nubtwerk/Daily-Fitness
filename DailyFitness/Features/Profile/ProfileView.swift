import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var dependencies: DependencyContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var preferences: [UserPreferencesEntity]

    @State private var usePounds: Bool = Locale.current.measurementSystem != .metric
    @State private var rirEnabled = false
    @State private var liveActivitiesEnabled = true
    @State private var defaultRestSeconds = 90
    @State private var restEndNotificationEnabled = false
    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false

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
                    if dependencies.syncEngine.conflictsResolved > 0 {
                        Label(
                            "\(dependencies.syncEngine.conflictsResolved) item\(dependencies.syncEngine.conflictsResolved == 1 ? "" : "s") updated from another device",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                    }
                    Button("Sync now") {
                        Task {
                            dependencies.syncEngine.acknowledgeConflicts()
                            try? await dependencies.syncEngine.flush(context: modelContext)
                            try? await dependencies.syncEngine.pullRemoteChanges(context: modelContext)
                        }
                    }
                    .disabled(!dependencies.userSession.isAuthenticated)
                }

                Section("Account") {
                    if dependencies.userSession.isAuthenticated {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                        Button("Restore from cloud") {
                            Task { try? await dependencies.syncEngine.restoreFromCloud(context: modelContext) }
                        }
                        Button("Sign out", role: .destructive) {
                            Task { try? await dependencies.authService.signOut() }
                        }
                        Button("Delete account & all data", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } else {
                        Text("Back up and sync your workouts across devices.")
                            .dfFont(.caption)
                            .foregroundStyle(Color.dfSecondaryText)
                        AppleSignInButton(dependencies: dependencies)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section("Subscription") {
                    if dependencies.userSession.isPro {
                        Label("DailyFitness Pro", systemImage: "crown.fill")
                        Button("Manage subscription") { openURL(SubscriptionManagement.url) }
                    } else {
                        Button("Upgrade to Pro") { showPaywall = true }
                    }
                }

                Section("Feedback") {
                    Link(destination: feedbackURL) {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    .accessibilityHint("Opens your mail app to send feedback about the app.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersionString)
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
            .onChange(of: restEndNotificationEnabled) { _, enabled in
                savePreferences()
                if enabled {
                    Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
                }
            }
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
                        do {
                            try await dependencies.authService.deleteAccount(context: modelContext)
                        } catch {
                            AppLog.auth.error("Account deletion failed: \(String(describing: error), privacy: .public)")
                            dependencies.errorPresenter.present(
                                title: "Couldn’t delete your account",
                                message: "We couldn’t fully remove your data. Please try again."
                            )
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all cloud data, and removes everything from this device. This can't be undone.")
            }
        }
    }

    private var syncStatusLabel: String {
        if !dependencies.userSession.isAuthenticated { return "Local only" }
        if dependencies.syncEngine.pendingCount > 0 { return "Pending" }
        return "Synced"
    }

    /// Email address that beta/App Store feedback is routed to. Change to your support inbox.
    private static let feedbackEmail = "joachim@noobwork.no"

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Pre-fills a feedback email with the app version and OS so reports are triageable (US-120).
    private var feedbackURL: URL {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let subject = "DailyFitness feedback (\(appVersionString))"
        let body = "\n\n—\nApp \(appVersionString)\n\(os)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url ?? URL(string: "mailto:\(Self.feedbackEmail)")!
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
}
