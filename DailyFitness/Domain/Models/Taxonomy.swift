import SwiftUI

// Canonical exercise taxonomy — the single source of truth shared by seed data,
// the library filters, and the custom-exercise editor. The raw values mirror the
// tokens emitted by scripts/import-exercises.py (MUSCLES / EQUIPMENT). Keep the two
// in sync; scripts/data/taxonomy.json is a generated reference dump for parity checks.

/// A primary muscle group an exercise targets. Stored as `rawValue` tokens in
/// `ExerciseEntity.primaryMuscles`.
enum MuscleGroup: String, CaseIterable, Identifiable, Sendable {
    case chest, back, lats, traps
    case lowerBack = "lower_back"
    case shoulders, biceps, triceps, forearms, neck, core, obliques
    case glutes, quads, hamstrings, calves, adductors, abductors
    case hipFlexors = "hip_flexors"
    case hips, spine, thoracic, ankles, wrists
    case fullBody = "full_body"

    var id: String { rawValue }
    var token: String { rawValue }

    var displayName: String {
        switch self {
        case .lowerBack: return "Lower Back"
        case .hipFlexors: return "Hip Flexors"
        case .fullBody: return "Full Body"
        default: return rawValue.capitalized
        }
    }

    /// Display name for a stored token, tolerant of values outside the enum.
    static func displayName(forToken token: String) -> String {
        MuscleGroup(rawValue: token)?.displayName
            ?? token.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// Equipment an exercise uses. Stored as `rawValue` tokens in `ExerciseEntity.equipment`.
enum Equipment: String, CaseIterable, Identifiable, Sendable {
    case barbell, dumbbell, kettlebell, cable, machine
    case smithMachine = "smith_machine"
    case bodyweight, bands
    case ezBar = "ez_bar"
    case exerciseBall = "exercise_ball"
    case medicineBall = "medicine_ball"
    case foamRoller = "foam_roller"
    case pullUpBar = "pull_up_bar"
    case bench, rack, mat, box, trx, block, strap, wall, chair, plate, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smithMachine: return "Smith Machine"
        case .ezBar: return "EZ Bar"
        case .exerciseBall: return "Exercise Ball"
        case .medicineBall: return "Medicine Ball"
        case .foamRoller: return "Foam Roller"
        case .pullUpBar: return "Pull-Up Bar"
        case .trx: return "TRX"
        default: return rawValue.capitalized
        }
    }

    static func displayName(forToken token: String) -> String {
        Equipment(rawValue: token)?.displayName
            ?? token.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Equipment tokens that actually occur in the seeded library, for filter chips.
    /// Ordered most-common-first for a sensible chip row.
    static var common: [Equipment] {
        [.bodyweight, .dumbbell, .barbell, .machine, .cable, .kettlebell, .bands,
         .mat, .pullUpBar, .smithMachine, .ezBar, .bench]
    }
}

extension ExerciseCategory: Identifiable {
    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// SF Symbol used for category chips and as the illustration fallback for
    /// records whose imageURL is a `placeholder:<category>` sentinel.
    var symbolName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .mobility: return "figure.cooldown"
        case .flexibility: return "figure.flexibility"
        case .yoga: return "figure.mind.and.body"
        case .cardio: return "figure.run"
        }
    }
}
