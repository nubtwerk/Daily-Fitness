import Foundation

enum WorkoutExportService {
    static func exportCSV(
        sessions: [WorkoutSessionEntity],
        exercises: [ExerciseEntity],
        userId: UUID
    ) -> URL? {
        var lines = ["session_id,session_name,started_at,exercise,set_number,weight_kg,reps,duration_seconds,hold_seconds"]

        for session in sessions where session.userId == userId {
            for workoutExercise in session.exercises {
                let exerciseName = exercises.first(where: { $0.id == workoutExercise.exerciseId })?.name ?? "Exercise"
                for set in workoutExercise.sets where set.isCompleted {
                    let row = [
                        session.id.uuidString,
                        csvEscape(session.name),
                        ISO8601DateFormatter().string(from: session.startedAt),
                        csvEscape(exerciseName),
                        String(set.setNumber),
                        set.weightKg.map { String($0) } ?? "",
                        set.reps.map { String($0) } ?? "",
                        set.durationSeconds.map { String($0) } ?? "",
                        set.holdSeconds.map { String($0) } ?? ""
                    ].joined(separator: ",")
                    lines.append(row)
                }
            }
        }

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dailyfitness-export-\(UUID().uuidString.prefix(8)).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
