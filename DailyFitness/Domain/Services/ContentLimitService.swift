import Foundation

/// Free-tier limits, reconciled to PRD §13.
///
/// Changes from the earlier draft:
///   * Custom programs and routines now share ONE combined cap of 5 (was 5 each).
///   * The invented 20-custom-exercise cap is gone — the PRD never limited custom exercises.
enum ContentLimitService {
    /// PRD §13: "Up to 5 custom programs / routines" — combined, not 5-of-each.
    static let maxFreeCustomContent = 5
    /// PRD §13: "2 exercises per workout with progression preview".
    static let maxFreeProgressionExercises = 2

    /// Whether the user can create another custom program or routine, given the *combined* count.
    static func canCreateCustomContent(routineCount: Int, programCount: Int, isPro: Bool) -> Bool {
        isPro || (routineCount + programCount) < maxFreeCustomContent
    }

    /// Whether smart-progression preview is available for the Nth strength exercise (0-based) in a
    /// workout. Free users get the first two.
    static func canShowProgression(forStrengthIndex index: Int, isPro: Bool) -> Bool {
        isPro || index < maxFreeProgressionExercises
    }
}
