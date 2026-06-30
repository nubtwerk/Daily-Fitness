import Foundation

/// Deep link used as the Live Activity's `widgetURL` fallback so that tapping the
/// activity (when interactive buttons aren't supported) opens the app on the
/// active workout's current set (LOCK-03 / US-062).
enum WorkoutDeepLink {
    static let scheme = "dailyfitness"
    static let host = "workout"

    static func url(sessionId: UUID) -> URL? {
        URL(string: "\(scheme)://\(host)/\(sessionId.uuidString)")
    }

    static func sessionId(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == host else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
