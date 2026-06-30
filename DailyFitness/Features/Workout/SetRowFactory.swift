import SwiftUI

enum SetRowFactory {
    @ViewBuilder
    static func row(
        for set: WorkoutSetEntity,
        loggingFields: LoggingFieldMask,
        usePounds: Bool,
        rirEnabled: Bool,
        onComplete: @escaping () -> Void
    ) -> some View {
        switch loggingFields {
        case .weightReps:
            StrengthSetRow(set: set, usePounds: usePounds, rirEnabled: rirEnabled, onComplete: onComplete)
        case .duration:
            DurationSetRow(set: set, onComplete: onComplete)
        case .hold, .side:
            HoldSetRow(set: set, showSide: loggingFields == .side, onComplete: onComplete)
        }
    }
}

/// The spring set-completion control + sage row-fill + success haptic that every
/// set row shares (DSS §5 / §6.5 — closes the LOG-04 haptic gap). Apply
/// `.dfSetCompletion(_:)` to a row's container.
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
    }
}

private extension View {
    /// Sweeps a soft sage fill behind a completed set row and fires a success
    /// haptic when completion toggles.
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

struct StrengthSetRow: View {
    @Bindable var set: WorkoutSetEntity
    let usePounds: Bool
    let rirEnabled: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Text("Set \(set.setNumber)")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
                .frame(width: 44, alignment: .leading)

            TextField(usePounds ? "lb" : "kg", value: weightBinding, format: .number)
                .keyboardType(.decimalPad)
                .dfField()
                .frame(width: 64)

            TextField("reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .dfField()
                .frame(width: 52)

            if rirEnabled {
                TextField("RIR", value: $set.rir, format: .number)
                    .keyboardType(.numberPad)
                    .dfField()
                    .frame(width: 44)
            }

            SetCompleteButton(isCompleted: set.isCompleted, action: onComplete)
        }
        .dfSetCompletion(set.isCompleted)
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
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Text("Set \(set.setNumber)")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
                .frame(width: 44, alignment: .leading)

            Stepper(
                "\(set.durationSeconds ?? 60)s",
                value: Binding(
                    get: { set.durationSeconds ?? 60 },
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
}

struct HoldSetRow: View {
    @Bindable var set: WorkoutSetEntity
    let showSide: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.sm) {
            Text("Set \(set.setNumber)")
                .dfFont(.callout)
                .foregroundStyle(Color.dfSecondaryText)
                .frame(width: 44, alignment: .leading)

            Stepper(
                "\(set.holdSeconds ?? 30)s hold",
                value: Binding(
                    get: { set.holdSeconds ?? 30 },
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

    private var sideBinding: Binding<BodySide> {
        Binding(
            get: { set.side ?? .both },
            set: { set.side = $0 }
        )
    }
}
