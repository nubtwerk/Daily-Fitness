import Foundation

@MainActor
final class WorkoutIntentObserver {
    static let shared = WorkoutIntentObserver()

    private var callback: ((WorkoutIntentAction) -> Void)?

    private init() {}

    func start(onAction: @escaping (WorkoutIntentAction) -> Void) {
        callback = onAction
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let instance = Unmanaged<WorkoutIntentObserver>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    if let action = WorkoutIntentBridge.consumePendingAction() {
                        instance.callback?(action)
                    }
                }
            },
            WorkoutIntentBridge.darwinNotificationName.rawValue,
            nil,
            .deliverImmediately
        )
    }

    func stop() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            WorkoutIntentBridge.darwinNotificationName,
            nil
        )
        callback = nil
    }
}
