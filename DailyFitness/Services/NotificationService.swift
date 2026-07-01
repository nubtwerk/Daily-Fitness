import Foundation
import UserNotifications

/// Local notification scheduling for the rest timer fallback (LOCK-06 / US-063).
///
/// When Live Activities are unavailable or disabled, an opted-in user still gets
/// a notification the moment their rest period ends.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let restNotificationId = "app.dailybase.dailyfitness.rest-timer-end"

    private init() {}

    /// Ask for alert/sound permission once. Safe to call repeatedly — it only
    /// prompts while the status is still undetermined.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// Schedule (or replace) the single pending rest-end notification.
    func scheduleRestEnd(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restNotificationId])

        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: restNotificationId, content: content, trigger: trigger)
        center.add(request)
    }

    /// Cancel any pending rest-end notification (set completed early, rest skipped, workout ended).
    func cancelRestEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotificationId])
    }
}
