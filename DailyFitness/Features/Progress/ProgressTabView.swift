import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \WorkoutSessionEntity.startedAt, order: .reverse)
    private var sessions: [WorkoutSessionEntity]

    private var completedSessions: [WorkoutSessionEntity] {
        sessions.filter { $0.endedAt != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if completedSessions.isEmpty {
                    DFEmptyState(
                        title: "No workouts yet",
                        message: "Complete a session to see your history here."
                    )
                } else {
                    List(completedSessions, id: \.id) { session in
                        VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                            Text(session.name)
                                .font(.headline)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(Color.dfSecondaryText)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.dfBackground)
            .navigationTitle("Progress")
        }
    }
}
