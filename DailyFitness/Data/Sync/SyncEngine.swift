import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString)
        else {
            return URL(string: "https://placeholder.supabase.co")!
        }
        return url
    }

    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    static var revenueCatAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
    }
}

actor SyncEngine {
    enum SyncOperation: Sendable {
        case upsertSession(UUID)
        case upsertRoutine(UUID)
        case deleteEntity(UUID)
    }

    private var queue: [SyncOperation] = []

    func enqueue(_ operation: SyncOperation) {
        queue.append(operation)
    }

    func flush() async {
        // Phase 1: wire to Supabase client
        queue.removeAll()
    }
}
