import Foundation
import SwiftData

@MainActor
final class UserPreferencesRepository {
    func loadOrCreate(userId: UUID, context: ModelContext) -> UserPreferencesEntity {
        let descriptor = FetchDescriptor<UserPreferencesEntity>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let prefs = UserPreferencesEntity(userId: userId)
        context.insert(prefs)
        try? context.save()
        return prefs
    }

    func save(
        userId: UUID,
        usePounds: Bool,
        rirEnabled: Bool,
        liveActivitiesEnabled: Bool,
        restEndNotificationEnabled: Bool = false,
        defaultRestSeconds: Int = 90,
        context: ModelContext
    ) {
        let prefs = loadOrCreate(userId: userId, context: context)
        prefs.usePounds = usePounds
        prefs.rirEnabled = rirEnabled
        prefs.liveActivitiesEnabled = liveActivitiesEnabled
        prefs.restEndNotificationEnabled = restEndNotificationEnabled
        prefs.defaultRestSeconds = defaultRestSeconds
        try? context.save()
    }
}
