import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var dependencies: DependencyContainer
    @Query private var preferences: [UserPreferencesEntity]
    @State private var usePounds: Bool = Locale.current.measurementSystem != .metric
    @State private var rirEnabled = false
    @State private var liveActivitiesEnabled = true

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
                }

                Section("Account") {
                    if dependencies.userSession.isAuthenticated {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                    } else {
                        Button("Sign in with Apple") {
                            // Phase 0: Supabase auth wiring
                        }
                    }
                }

                Section("Subscription") {
                    if dependencies.userSession.isPro {
                        Text("DailyFitness Pro")
                    } else {
                        Button("Upgrade to Pro") {}
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .navigationTitle("Profile")
            .onAppear(perform: loadPreferences)
            .onChange(of: usePounds) { _, _ in savePreferences() }
            .onChange(of: rirEnabled) { _, _ in savePreferences() }
            .onChange(of: liveActivitiesEnabled) { _, _ in savePreferences() }
        }
    }

    private func loadPreferences() {
        if let prefs = preferences.first {
            usePounds = prefs.usePounds
            rirEnabled = prefs.rirEnabled
            liveActivitiesEnabled = prefs.liveActivitiesEnabled
        }
    }

    private func savePreferences() {
        // Persist in Phase 1 via dedicated repository
    }
}
