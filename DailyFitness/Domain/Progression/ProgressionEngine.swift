import Foundation

protocol ProgressionEngineProtocol: Sendable {
    func recommend(input: ProgressionInput) -> ProgressionOutput
}

/// Rule-based strength progression — see docs/TDD.md §8 and PRD §12.
struct ProgressionEngine: ProgressionEngineProtocol {
    /// Consecutive stalls (hold/regress) before a deload is suggested (PROG-04).
    static let deloadThreshold = 3

    /// A recommendation before deload/streak bookkeeping is applied.
    private struct BaseRecommendation {
        let action: ProgressionAction
        let targetWeightKg: Double?
        let targetRir: Int?
        let reason: String
    }

    func recommend(input: ProgressionInput) -> ProgressionOutput {
        let targets = input.targets
        // Changing the routine's rep targets resets the stall streak (US-083).
        let priorStalls = input.targetsChanged ? 0 : input.failedAttempts

        guard let latest = input.history.last else {
            return ProgressionOutput(
                targetWeightKg: nil,
                targetRepsMin: targets.min,
                targetRepsMax: targets.max,
                targetRir: input.rirEnabled ? 2 : nil,
                action: .hold,
                reason: "First session — use your routine targets.",
                failedAttempts: priorStalls
            )
        }

        let base: BaseRecommendation
        if input.rirEnabled, let rir = latest.rir {
            base = recommendWithRIR(latest: latest, rir: rir, targets: targets, incrementKg: input.incrementKg)
        } else {
            base = recommendByReps(latest: latest, targets: targets, incrementKg: input.incrementKg)
        }

        // Anything other than a load increase counts as a stalled attempt.
        let isStall = base.action != .increase
        let streak = isStall ? priorStalls + 1 : 0

        if isStall, streak >= Self.deloadThreshold {
            let deloadWeight = latest.weightKg * 0.9
            return ProgressionOutput(
                targetWeightKg: deloadWeight,
                targetRepsMin: targets.min,
                targetRepsMax: targets.max,
                targetRir: input.rirEnabled ? 2 : nil,
                action: .deload,
                reason: "Deload — \(streak) sessions without progress. Drop to \(formatKg(deloadWeight)) and rebuild.",
                failedAttempts: 0
            )
        }

        return ProgressionOutput(
            targetWeightKg: base.targetWeightKg,
            targetRepsMin: targets.min,
            targetRepsMax: targets.max,
            targetRir: base.targetRir,
            action: base.action,
            reason: base.reason,
            failedAttempts: streak
        )
    }

    private func recommendByReps(
        latest: CompletedWorkingSet,
        targets: RepRange,
        incrementKg: Double
    ) -> BaseRecommendation {
        if latest.reps >= targets.max {
            return BaseRecommendation(
                action: .increase,
                targetWeightKg: latest.weightKg + incrementKg,
                targetRir: nil,
                reason: "↑ \(formatKg(incrementKg)) — you hit the top of your rep range last session."
            )
        }

        if latest.reps < targets.min {
            return BaseRecommendation(
                action: .decrease,
                targetWeightKg: latest.weightKg * 0.95,
                targetRir: nil,
                reason: "↓ 5% — reps were below your target range last session."
            )
        }

        return BaseRecommendation(
            action: .hold,
            targetWeightKg: latest.weightKg,
            targetRir: nil,
            reason: "Hold — within range. Repeat to build consistency."
        )
    }

    private func recommendWithRIR(
        latest: CompletedWorkingSet,
        rir: Int,
        targets: RepRange,
        incrementKg: Double
    ) -> BaseRecommendation {
        // Predicted reps-at-failure threshold: midpoint of the rep range plus a buffer.
        // NOTE: parentheses are required — without them Swift evaluates
        // `min + max / 2 + 2`, biasing the engine to always hold.
        let predictedMax = (targets.min + targets.max) / 2 + 2
        let effectiveMax = latest.reps + rir

        if effectiveMax >= predictedMax {
            return BaseRecommendation(
                action: .increase,
                targetWeightKg: latest.weightKg + incrementKg,
                targetRir: 2,
                reason: "↑ \(formatKg(incrementKg)) — performance exceeded target at \(rir) RIR."
            )
        }

        return BaseRecommendation(
            action: .hold,
            targetWeightKg: latest.weightKg,
            targetRir: 2,
            reason: "Hold — RIR suggests staying at current load."
        )
    }

    private func formatKg(_ kg: Double) -> String {
        String(format: "%.1f kg", kg)
    }
}
