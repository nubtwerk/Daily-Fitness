import OSLog

/// Centralized, category-scoped logging for DailyFitness.
///
/// Replaces scattered `print(...)` and silent `try?` failures with structured `os.Logger`
/// output that is visible in Console.app / `log stream` and survives release builds.
enum AppLog {
    private static let subsystem = "app.dailybase.dailyfitness"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let workout = Logger(subsystem: subsystem, category: "workout")
    static let seeding = Logger(subsystem: subsystem, category: "seeding")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let app = Logger(subsystem: subsystem, category: "app")
}
