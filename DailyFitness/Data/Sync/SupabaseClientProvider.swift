import Foundation
import Supabase

/// A single, shared `SupabaseClient` for the whole app.
///
/// Previously `SyncEngine` and `AuthService` each exposed `client` as a *computed*
/// property, so every access constructed a brand-new `SupabaseClient`. That meant the
/// auth session established by `AuthService` lived in a different client instance than the
/// one `SyncEngine` used to read/write data, and each network call paid client-setup cost.
/// Constructing it exactly once here keeps the authenticated session and the data client in
/// sync, and is cheap to reference everywhere.
enum SupabaseClientProvider {
    static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
