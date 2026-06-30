import Foundation
import SwiftData

/// A metric plottable on the per-exercise history chart (US-092).
enum ChartMetric: String, CaseIterable, Identifiable {
    case weight
    case reps
    case volume
    case e1RM
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .volume: return "Volume"
        case .e1RM: return "Est. 1RM"
        case .duration: return "Duration"
        }
    }

    var unitSuffix: String {
        switch self {
        case .weight, .e1RM: return "kg"
        case .reps: return "reps"
        case .volume: return "kg·reps"
        case .duration: return "min"
        }
    }
}

struct ChartPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double

    static func == (lhs: ChartPoint, rhs: ChartPoint) -> Bool {
        lhs.date == rhs.date && lhs.value == rhs.value
    }
}

/// Per-session series for a single exercise. Strength exercises expose weight/reps/volume/e1RM;
/// duration-based exercises (mobility/yoga) expose a duration series.
struct ExerciseSeries: Equatable {
    var weight: [ChartPoint] = []
    var reps: [ChartPoint] = []
    var volume: [ChartPoint] = []
    var e1RM: [ChartPoint] = []
    var duration: [ChartPoint] = []
    /// True when a free user has sessions older than the 90-day window (drives the upgrade prompt).
    var hasOlderData = false
    var isDurationBased = false

    var availableMetrics: [ChartMetric] {
        isDurationBased ? [.duration] : [.weight, .reps, .volume, .e1RM]
    }

    func points(for metric: ChartMetric) -> [ChartPoint] {
        switch metric {
        case .weight: return weight
        case .reps: return reps
        case .volume: return volume
        case .e1RM: return e1RM
        case .duration: return duration
        }
    }

    var isEmpty: Bool {
        weight.isEmpty && reps.isEmpty && volume.isEmpty && e1RM.isEmpty && duration.isEmpty
    }
}

struct MuscleVolume: Identifiable, Equatable {
    var id: String { muscle }
    let muscle: String
    let volume: Double
}

/// Everything the Progress tab needs, computed in a single pass so views never aggregate per render.
struct ProgressSummary: Equatable {
    var muscleVolumes: [MuscleVolume] = []
    /// nil = all-time (Premium); otherwise the rolling window in days.
    var muscleWindowDays: Int? = AnalyticsService.freeMuscleWindowDays
    var mobilityYogaMinutes: Int = 0
    var mobilityYogaSessionCount: Int = 0
    /// Start-of-day dates that have at least one completed session (calendar marking — AN-06).
    var sessionDays: Set<Date> = []
    /// session.id → set of exercise-category raw values present in that session (history filter).
    var categoriesBySession: [UUID: Set<String>] = [:]
}

@MainActor
final class AnalyticsService {
    // nonisolated so they can be referenced from nonisolated contexts (e.g. ProgressSummary's
    // default value) without tripping Swift 6 actor-isolation diagnostics.
    nonisolated static let freeWindowDays = 90
    nonisolated static let freeMuscleWindowDays = 30

    // MARK: - Per-exercise charts (US-092)

    func exerciseSeries(
        exerciseId: UUID,
        loggingFields: LoggingFieldMask,
        userId: UUID,
        isPro: Bool,
        context: ModelContext
    ) -> ExerciseSeries {
        let sessions = completedSessions(userId: userId, context: context)
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.freeWindowDays, to: Date()) ?? .distantPast

        var series = ExerciseSeries()
        series.isDurationBased = (loggingFields != .weightReps)

        for session in sessions {
            // Free tier: only the last 90 days; flag older data for the upgrade prompt.
            if !isPro && session.startedAt < cutoff {
                if session.exercises.contains(where: { $0.exerciseId == exerciseId }) {
                    series.hasOlderData = true
                }
                continue
            }

            let date = session.startedAt
            var maxWeight = 0.0
            var maxReps = 0
            var sessionVolume = 0.0
            var maxE1RM = 0.0
            var durationSeconds = 0
            var hasStrengthData = false
            var hasDurationData = false

            for workoutExercise in session.exercises where workoutExercise.exerciseId == exerciseId {
                for set in workoutExercise.sets where set.isCompleted && set.setType != .warmup {
                    if series.isDurationBased {
                        let secs = (set.durationSeconds ?? 0) + (set.holdSeconds ?? 0)
                        if secs > 0 { durationSeconds += secs; hasDurationData = true }
                    } else if let weight = set.weightKg, let reps = set.reps, weight > 0, reps > 0 {
                        hasStrengthData = true
                        maxWeight = max(maxWeight, weight)
                        maxReps = max(maxReps, reps)
                        sessionVolume += weight * Double(reps)
                        maxE1RM = max(maxE1RM, PRDetector.estimated1RM(weightKg: weight, reps: reps))
                    }
                }
            }

            if hasStrengthData {
                series.weight.append(ChartPoint(date: date, value: maxWeight))
                series.reps.append(ChartPoint(date: date, value: Double(maxReps)))
                series.volume.append(ChartPoint(date: date, value: sessionVolume))
                series.e1RM.append(ChartPoint(date: date, value: (maxE1RM * 10).rounded() / 10))
            }
            if hasDurationData {
                series.duration.append(ChartPoint(date: date, value: Double(durationSeconds) / 60))
            }
        }

        return series
    }

    // MARK: - Progress tab summary (AN-05/06/07)

    func progressSummary(
        userId: UUID,
        isPro: Bool,
        context: ModelContext,
        exercises: [ExerciseEntity]
    ) -> ProgressSummary {
        let sessions = completedSessions(userId: userId, context: context)
        let exercisesById = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let calendar = Calendar.current

        // Muscle volume window: free 30 days, Premium all-time (AN-05).
        let muscleWindowDays: Int? = isPro ? nil : Self.freeMuscleWindowDays
        let muscleCutoff = muscleWindowDays.flatMap {
            calendar.date(byAdding: .day, value: -$0, to: Date())
        } ?? .distantPast

        // History/calendar honour the standard free window (90 days).
        let historyCutoff = isPro
            ? Date.distantPast
            : (calendar.date(byAdding: .day, value: -Self.freeWindowDays, to: Date()) ?? .distantPast)

        var muscleVolumes: [String: Double] = [:]
        var mobilityYogaSeconds = 0
        var mobilityYogaSessions = 0
        var sessionDays: Set<Date> = []
        var categoriesBySession: [UUID: Set<String>] = [:]

        for session in sessions where session.startedAt >= historyCutoff {
            sessionDays.insert(calendar.startOfDay(for: session.startedAt))

            var categories: Set<String> = []
            var sessionHasMobilityYoga = false

            for workoutExercise in session.exercises {
                guard let exercise = exercisesById[workoutExercise.exerciseId] else { continue }
                categories.insert(exercise.categoryRaw)

                let completedSets = workoutExercise.sets.filter { $0.isCompleted && $0.setType != .warmup }

                if exercise.category == .strength {
                    if session.startedAt >= muscleCutoff {
                        let volume = completedSets.reduce(0.0) { partial, set in
                            partial + (set.weightKg ?? 0) * Double(set.reps ?? 0)
                        }
                        if volume > 0 {
                            for muscle in exercise.primaryMuscles {
                                muscleVolumes[muscle, default: 0] += volume
                            }
                        }
                    }
                } else if [.mobility, .yoga, .flexibility].contains(exercise.category) {
                    let secs = completedSets.reduce(0) { $0 + ($1.durationSeconds ?? 0) + ($1.holdSeconds ?? 0) }
                    if secs > 0 {
                        mobilityYogaSeconds += secs
                        sessionHasMobilityYoga = true
                    }
                }
            }

            categoriesBySession[session.id] = categories
            if sessionHasMobilityYoga { mobilityYogaSessions += 1 }
        }

        let volumes = muscleVolumes
            .map { MuscleVolume(muscle: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }

        return ProgressSummary(
            muscleVolumes: volumes,
            muscleWindowDays: muscleWindowDays,
            mobilityYogaMinutes: mobilityYogaSeconds / 60,
            mobilityYogaSessionCount: mobilityYogaSessions,
            sessionDays: sessionDays,
            categoriesBySession: categoriesBySession
        )
    }

    // MARK: - Shared fetch

    private func completedSessions(userId: UUID, context: ModelContext) -> [WorkoutSessionEntity] {
        let descriptor = FetchDescriptor<WorkoutSessionEntity>(
            predicate: #Predicate { $0.userId == userId && $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
