import SwiftUI

enum SetRowFactory {
    @ViewBuilder
    static func row(
        for set: WorkoutSetEntity,
        loggingFields: LoggingFieldMask,
        usePounds: Bool,
        rirEnabled: Bool,
        lastPerformance: LastWorkingSetService.Performance?,
        onComplete: @escaping () -> Void
    ) -> some View {
        switch loggingFields {
        case .weightReps:
            StrengthSetRow(
                set: set,
                usePounds: usePounds,
                rirEnabled: rirEnabled,
                lastPerformance: lastPerformance,
                onComplete: onComplete
            )
        case .duration:
            DurationSetRow(set: set, lastPerformance: lastPerformance, onComplete: onComplete)
        case .hold, .side:
            HoldSetRow(
                set: set,
                showSide: loggingFields == .side,
                lastPerformance: lastPerformance,
                onComplete: onComplete
            )
        }
    }
}

// MARK: - Set type presentation (LOG-07 / US-054)

extension SetType {
    var displayName: String {
        switch self {
        case .normal: return "Working set"
        case .warmup: return "Warm-up"
        case .failure: return "To failure"
        case .dropSet: return "Drop set"
        }
    }

    /// Compact badge glyph shown on the set row.
    var shortLabel: String {
        switch self {
        case .normal: return "W"
        case .warmup: return "WU"
        case .failure: return "F"
        case .dropSet: return "D"
        }
    }

    /// Calm Strength palette only — no raw alarm colors (DESIGN_SYSTEM_SPEC: one
    /// accent, no red urgency). Badges stay distinct via their letter + the drop glyph.
    var tint: Color {
        switch self {
        case .normal: return .dfSecondaryText
        case .warmup: return .dfSecondaryText
        case .failure: return .dfPrimary
        case .dropSet: return .dfAccent
        }
    }
}

// MARK: - Shared row chrome

/// The spring set-completion control shared by every row (DSS §5 / §6.5 — closes
/// the LOG-04 haptic gap). Apply `.dfSetCompletion(_:)` to a row's container.
private struct SetCompleteButton: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? Color.dfAccent : Color.dfSecondaryText)
                .scaleEffect(isCompleted ? 1.0 : 0.9)
                .animation(CalmStrength.Motion.standard, value: isCompleted)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(isCompleted ? "Set complete" : "Mark set complete")
    }
}

private extension View {
    /// Sweeps a soft sage fill behind a completed set row and fires a success
    /// haptic when completion toggles (LOG-04 / US-051).
    func dfSetCompletion(_ isCompleted: Bool) -> some View {
        self
            .padding(.horizontal, CalmStrength.Spacing.xs)
            .background(
                isCompleted ? Color.dfAccent.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: CalmStrength.Radius.sm, style: .continuous)
            )
            .animation(CalmStrength.Motion.standard, value: isCompleted)
            .sensoryFeedback(.success, trigger: isCompleted)
    }
}

/// One-tap set-type selector — visible per row, not buried (US-054).
private struct SetTypeMenu: View {
    @Bindable var set: WorkoutSetEntity

    var body: some View {
        Menu {
            Picker("Set type", selection: $set.setType) {
                ForEach(SetType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } label: {
            HStack(spacing: CalmStrength.Spacing.xs) {
                if set.setType == .dropSet {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundStyle(SetType.dropSet.tint)
                }
                Text("Set \(set.setNumber)")
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
                if set.setType != .normal {
                    Text(set.setType.shortLabel)
                        .dfFont(.micro)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(set.setType.tint.opacity(0.18))
                        .foregroundStyle(set.setType.tint)
                        .clipShape(Capsule())
                }
            }
            .frame(minWidth: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Set \(set.setNumber), \(set.setType.displayName)")
    }
}

// MARK: - Rows

struct StrengthSetRow: View {
    @Bindable var set: WorkoutSetEntity
    let usePounds: Bool
    let rirEnabled: Bool
    let lastPerformance: LastWorkingSetService.Performance?
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            SetTypeMenu(set: set)

            TextField(weightPrompt, value: weightBinding, format: .number)
                .keyboardType(.decimalPad)
                .dfField()
                .frame(width: 64)

            TextField(repsPrompt, value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .dfField()
                .frame(width: 52)

            if rirEnabled {
                TextField("RIR", value: $set.rir, format: .number)
                    .keyboardType(.numberPad)
                    .dfField()
                    .frame(width: 44)
            }

            Spacer(minLength: 0)

            SetCompleteButton(isCompleted: set.isCompleted, action: onComplete)
        }
        .dfSetCompletion(set.isCompleted)
    }

    private var weightPrompt: String {
        if let kg = lastPerformance?.weightKg {
            let value = usePounds ? kg * 2.20462 : kg
            return String(format: "%.1f", value)
        }
        return usePounds ? "lb" : "kg"
    }

    private var repsPrompt: String {
        if let reps = lastPerformance?.reps { return "\(reps)" }
        return "reps"
    }

    private var weightBinding: Binding<Double?> {
        Binding(
            get: {
                guard let kg = set.weightKg else { return nil }
                return usePounds ? kg * 2.20462 : kg
            },
            set: { newValue in
                guard let value = newValue else {
                    set.weightKg = nil
                    return
                }
                set.weightKg = WeightFormatter.toKg(displayValue: value, usePounds: usePounds)
            }
        )
    }
}

struct DurationSetRow: View {
    @Bindable var set: WorkoutSetEntity
    let lastPerformance: LastWorkingSetService.Performance?
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Text("Set \(set.setNumber)")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
                .frame(width: 44, alignment: .leading)

            Stepper(
                "\(set.durationSeconds ?? defaultDuration)s",
                value: Binding(
                    get: { set.durationSeconds ?? defaultDuration },
                    set: { set.durationSeconds = $0 }
                ),
                in: 15...3600,
                step: 15
            )

            Spacer()

            SetCompleteButton(isCompleted: set.isCompleted, action: onComplete)
        }
        .dfSetCompletion(set.isCompleted)
    }

    private var defaultDuration: Int { lastPerformance?.durationSeconds ?? 60 }
}

struct HoldSetRow: View {
    @Bindable var set: WorkoutSetEntity
    let showSide: Bool
    let lastPerformance: LastWorkingSetService.Performance?
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Text("Set \(set.setNumber)")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
                .frame(width: 44, alignment: .leading)

            Stepper(
                "\(set.holdSeconds ?? defaultHold)s hold",
                value: Binding(
                    get: { set.holdSeconds ?? defaultHold },
                    set: { set.holdSeconds = $0 }
                ),
                in: 5...300,
                step: 5
            )

            if showSide {
                Picker("Side", selection: sideBinding) {
                    ForEach(BodySide.allCases, id: \.self) { side in
                        Text(side.rawValue.capitalized).tag(side)
                    }
                }
                .pickerStyle(.menu)
            }

            Spacer()

            SetCompleteButton(isCompleted: set.isCompleted, action: onComplete)
        }
        .dfSetCompletion(set.isCompleted)
    }

    private var defaultHold: Int { lastPerformance?.holdSeconds ?? 30 }

    private var sideBinding: Binding<BodySide> {
        Binding(
            get: { set.side ?? lastPerformance?.side ?? .both },
            set: { set.side = $0 }
        )
    }
}
