import Foundation

enum PRDetector {
    static func detect(
        set: CompletedWorkingSet,
        exerciseId: UUID,
        previousBestWeight: Double?,
        previousBestReps: Int?,
        previousBestE1RM: Double?
    ) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        let now = set.completedAt
        let e1RM = set.weightKg * (1 + Double(set.reps) / 30)

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
