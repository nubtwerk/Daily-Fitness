import Foundation

enum AppGroup {
    static let identifier = "group.app.dailybase.dailyfitness"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}
