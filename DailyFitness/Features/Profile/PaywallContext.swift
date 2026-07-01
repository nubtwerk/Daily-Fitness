import Foundation

/// Why the paywall is being shown. Each limit point passes its own context so the paywall leads
/// with the benefit the user just bumped into, instead of a generic pitch.
enum PaywallContext: String, Identifiable, CaseIterable, Sendable {
    case general
    case customContent   // tried to create a 6th routine/program (free cap is 5 combined)
    case progression     // tried to enable progression on a 3rd strength exercise
    case history         // scrolled past the 90-day free history window
    case export          // tapped CSV export
    case analytics       // wanted advanced charts / trends

    var id: String { rawValue }

    /// Lead headline shown at the top of the paywall.
    var headline: String {
        switch self {
        case .general:       return "Train without limits"
        case .customContent: return "Build more than 5 plans"
        case .progression:   return "Progression on every lift"
        case .history:       return "See your whole history"
        case .export:        return "Export your workout data"
        case .analytics:     return "Unlock advanced analytics"
        }
    }

    /// Supporting line that names the specific limit the user hit.
    var subheadline: String {
        switch self {
        case .general:
            return "Unlimited plans, full progression, all-time history, and CSV export."
        case .customContent:
            return "The free plan includes 5 custom programs and routines combined. Go unlimited with Pro."
        case .progression:
            return "Free includes smart progression for your first 2 strength exercises. Pro unlocks every exercise."
        case .history:
            return "Free keeps your last 90 days. Pro keeps everything, forever."
        case .export:
            return "CSV export is a Pro feature — take your sets, reps, and notes anywhere."
        case .analytics:
            return "Pro adds progress charts and longer-range trends across every exercise."
        }
    }

    /// The comparison row to visually emphasise for this context (matches a `ProFeature.title`).
    var highlightedFeature: String? {
        switch self {
        case .general:       return nil
        case .customContent: return "Unlimited programs & routines"
        case .progression:   return "Progression on all strength exercises"
        case .history:       return "All-time history"
        case .export:        return "CSV workout export"
        case .analytics:     return "Advanced progress charts"
        }
    }
}

/// One row in the Free-vs-Pro comparison table on the paywall.
struct ProFeature: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let free: String
    let pro: String

    /// PRD §13 feature matrix.
    static let all: [ProFeature] = [
        ProFeature(title: "Workout logging", free: "Unlimited", pro: "Unlimited"),
        ProFeature(title: "Unlimited programs & routines", free: "5 total", pro: "Unlimited"),
        ProFeature(title: "Progression on all strength exercises", free: "First 2", pro: "Every exercise"),
        ProFeature(title: "All-time history", free: "90 days", pro: "Forever"),
        ProFeature(title: "Advanced progress charts", free: "—", pro: "Included"),
        ProFeature(title: "CSV workout export", free: "—", pro: "Included")
    ]
}
