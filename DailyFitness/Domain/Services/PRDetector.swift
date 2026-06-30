import Foundation

enum PRDetector {
    /// Sentinel id used for session-wide records (e.g. session volume), which are tied to
    /// neither a single exercise nor a single set.
    static let sessionWideId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Epley-style estimated 1RM for a single set.
    static func estimated1RM(weightKg: Double, reps: Int) -> Double {
        weightKg * (1 + Double(reps) / 30)
    }

    /// A session-volume PR if `volume` beats the previous best (or there is no prior best).
    static func detectSessionVolume(
        volume: Double,
        previousBest: Double?,
        at date: Date
    ) -> PersonalRecord? {
        guard volume > 0, previousBest == nil || volume > (previousBest ?? 0) else { return nil }
        return PersonalRecord(
            id: UUID(),
            exerciseId: sessionWideId,
            type: .sessionVolume,
            value: volume,
            achievedAt: date
        )
    }

    static func detect(
        set: CompletedWorkingSet,
        exerciseId: UUID,
        previousBestWeight: Double?,
        previousBestReps: Int?,
        previousBestE1RM: Double?
    ) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        let now = set.completedAt
        let e1RM = estimated1RM(weightKg: set.weightKg, reps: set.reps)

        if previousBestWeight == nil || set.weightKg > (previousBestWeight ?? 0) {
            records.append(PersonalRecord(
                id: UUID(),
                exerciseId: exerciseId,
                type: .weight,
                value: set.weightKg,
                achievedAt: now
            ))
        }

        if previousBestReps == nil || set.reps > (previousBestReps ?? 0) {
            records.append(PersonalRecord(
                id: UUID(),
                exerciseId: exerciseId,
                type: .reps,
                value: Double(set.reps),
                achievedAt: now
            ))
        }

        if previousBestE1RM == nil || e1RM > (previousBestE1RM ?? 0) {
            records.append(PersonalRecord(
                id: UUID(),
                exerciseId: exerciseId,
                type: .estimated1RM,
                value: e1RM,
                achievedAt: now
            ))
        }

        return records
    }
}

enum WeightFormatter {
    static func display(kg: Double, usePounds: Bool) -> String {
        if usePounds {
            let lb = kg * 2.20462
            return String(format: "%.1f lb", lb)
        }
        return String(format: "%.1f kg", kg)
    }

    static func toKg(displayValue: Double, usePounds: Bool) -> Double {
        usePounds ? displayValue / 2.20462 : displayValue
    }
}
