import WidgetKit
import SwiftUI
import ActivityKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            LockScreenWorkoutView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.workoutName)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == .resting, let restEndsAt = context.state.restEndsAt {
                        Text(timerInterval: Date()...restEndsAt, countsDown: true)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.exerciseName) · Set \(context.state.setCurrent)/\(context.state.setTotal)")
                        .font(.caption2)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                if context.state.phase == .resting, let restEndsAt = context.state.restEndsAt {
                    Text(timerInterval: Date()...restEndsAt, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 40)
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
        }
    }
}

struct LockScreenWorkoutView: View {
    let context: ActivityViewContext<WorkoutAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.attributes.workoutName)
                .font(.headline)
            Text(context.state.exerciseName)
                .font(.subheadline)
            Text("Set \(context.state.setCurrent) of \(context.state.setTotal)")
                .font(.caption)

            if context.state.phase == .resting, let restEndsAt = context.state.restEndsAt {
                Text(timerInterval: Date()...restEndsAt, countsDown: true)
                    .font(.title2.monospacedDigit())
            }

            HStack {
                Button(intent: CompleteSetIntent()) {
                    Label("Done", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)

                Button(intent: ExtendRestIntent()) {
                    Label("+30s", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding()
    }
}

struct WorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setCurrent: Int
        var setTotal: Int
        var phase: WorkoutPhase
        var restEndsAt: Date?
        var sessionId: UUID
    }

    var workoutName: String
}

enum WorkoutPhase: String, Codable, Hashable {
    case active
    case resting
}

@main
struct WorkoutLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
