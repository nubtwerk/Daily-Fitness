import Foundation

protocol ProgressionEngineProtocol: Sendable {
    func recommend(input: ProgressionInput) -> ProgressionOutput
}

/// Rule-based strength progression — see docs/TDD.md §8.
struct ProgressionEngine: ProgressionEngineProtocol {
    func recommend(input: ProgressionInput) -> ProgressionOutput {
        let targets = input.targets
        guard let latest = input.history.last else {
            return ProgressionOutput(
                targetWeightKg: nil,
                targetRepsMin: targets.min,
                targetRepsMax: targets.max,
                targetRir: input.rirEnabled ? 2 : nil,
                action: .hold,
                reason: "First session — use your routine targets."
            )
        }

        if input.rirEnabled, let rir = latest.rir {
            return recommendWithRIR(
                latest: latest,
                rir: rir,
                targets: targets,
                incrementKg: input.incrementKg
            )
        }

        if latest.reps >= targets.max {
            let newWeight = latest.weightKg + input.incrementKg
            return ProgressionOutput(
                targetWeightKg: newWeight,
                targetRepsMin: targets.min,
                targetRepsMax: targets.max,
                targetRir: nil,
                action: .increase,
                reason: "↑ \(formatKg(input.incrementKg)) — you hit the top of your rep range last session."
            )
        }

        if latest.reps < targets.min {
            let reduced = latest.weightKg * 0.95
            return ProgressionOutput(
                targetWeightKg: reduced,
                targetRepsMin: targets.min,
                targetRepsMax: targets.max,
                targetRir: nil,
                action: .decrease,
                reason: "↓ 5% — reps were below your target range last session."
            )
        }

        return ProgressionOutput(
            targetWeightKg: latest.weightKg,
            targetRepsMin: targets.min,
            targetRepsMax: targets.max,
            targetRir: nil,
            action: .hold,
            reason: "Hold — within range. Repeat to build consistency."
        )
    }

    private func recommendWithRIR(
        latest: CompletedWorkingSet,
        rir: Int,
        targets: RepRange,
        incrementKg: Double
    ) -> ProgressionOutput {
        let predictedMax = targets.min + targets.max / 2 + 2
        let effectiveMax = latest.reps + rir

        if effectiveMax >= predictedMax {
            return ProgressionOutput(
                targetWeightKg: latest.weightKg + incrementKg,
                targetRepsMin: targets.min,
                targetRepsMax: targets.max,
                targetRir: 2,
                action: .increase,
                reason: "↑ \(formatKg(incrementKg)) — performance exceeded target at \(rir) RIR."
            )
        }

        return ProgressionOutput(
            targetWeightKg: latest.weightKg,
            targetRepsMin: targets.min,
            targetRepsMax: targets.max,
            targetRir: 2,
            action: .hold,
            reason: "Hold — RIR suggests staying at current load."
        )
    }

    private func formatKg(_ kg: Double) -> String {
        String(format: "%.1f kg", kg)
    }
}
