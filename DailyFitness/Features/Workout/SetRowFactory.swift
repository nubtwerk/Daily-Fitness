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
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)

            TextField("reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)

            if rirEnabled {
                TextField("RIR", value: $set.rir, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
            }

            completeButton
        }
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

    private var completeButton: some View {
        Button(action: onComplete) {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(set.isCompleted ? Color.dfAccent : Color.dfSecondaryText)
        }
        .frame(minWidth: 44, minHeight: 44)
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

            Button(action: onComplete) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.dfAccent : Color.dfSecondaryText)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
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

            Button(action: onComplete) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.dfAccent : Color.dfSecondaryText)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    private var sideBinding: Binding<BodySide> {
        Binding(
            get: { set.side ?? .both },
            set: { set.side = $0 }
        )
    }
}
