import SwiftUI

struct ProgressionBanner: View {
    let recommendation: ProgressionRecommendationEntity?
    let usePounds: Bool

    var body: some View {
        if let recommendation {
            HStack(spacing: CalmStrength.Spacing.sm) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundStyle(Color.dfAccent)
                VStack(alignment: .leading, spacing: 2) {
                    if let weight = recommendation.targetWeightKg {
                        Text("Suggested: \(WeightFormatter.display(kg: weight, usePounds: usePounds)) × \(recommendation.targetRepsMin)–\(recommendation.targetRepsMax)")
                            .dfFont(.captionStrong)
                            .foregroundStyle(Color.dfPrimary)
                    } else {
                        Text("Target: \(recommendation.targetRepsMin)–\(recommendation.targetRepsMax) reps")
                            .dfFont(.captionStrong)
                            .foregroundStyle(Color.dfPrimary)
                    }
                    Text(recommendation.reason)
                        .dfFont(.micro)
                        .foregroundStyle(Color.dfSecondaryText)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, CalmStrength.Spacing.xs)
        }
    }
}

struct PRToastView: View {
    let records: [PersonalRecord]

    var body: some View {
        if !records.isEmpty {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.dfAccent)
                Text(prMessage)
                    .dfFont(.subheading)
                    .foregroundStyle(Color.dfPrimary)
            }
            .padding(CalmStrength.Spacing.sm)
            .background(Color.dfSurface)
            .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md))
        }
    }

    private var prMessage: String {
        let types = records.map { $0.type.rawValue }.joined(separator: ", ")
        return "New PR! (\(types))"
    }
}
