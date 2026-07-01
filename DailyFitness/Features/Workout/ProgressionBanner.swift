import SwiftUI

/// Actionable next-session recommendation (US-080: accept / edit / ignore). When the
/// recommendation is a deload it renders as a distinct, non-blocking warning (PROG-04).
struct ProgressionBanner: View {
    let recommendation: ProgressionRecommendationEntity
    let usePounds: Bool
    let onAccept: () -> Void
    let onIgnore: () -> Void

    private var isDeload: Bool { recommendation.action == .deload }
    private var accent: Color { isDeload ? Color.dfWarning : Color.dfAccent }

    private var iconName: String {
        switch recommendation.action {
        case .increase: return "arrow.up.forward.circle.fill"
        case .decrease: return "arrow.down.right.circle.fill"
        case .deload: return "arrow.uturn.down.circle.fill"
        case .hold: return "equal.circle.fill"
        }
    }

    private var headline: String {
        if isDeload { return "Deload suggested" }
        if let weight = recommendation.targetWeightKg {
            return "Suggested: \(WeightFormatter.display(kg: weight, usePounds: usePounds)) × \(recommendation.targetRepsMin)–\(recommendation.targetRepsMax)"
        }
        return "Target: \(recommendation.targetRepsMin)–\(recommendation.targetRepsMax) reps"
    }

    private var hasWeight: Bool { recommendation.targetWeightKg != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
            HStack(alignment: .top, spacing: CalmStrength.Spacing.sm) {
                Image(systemName: iconName)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .dfFont(.captionStrong)
                        .foregroundStyle(Color.dfPrimary)
                    Text(recommendation.reason)
                        .dfFont(.micro)
                        .foregroundStyle(Color.dfSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: CalmStrength.Spacing.md) {
                Button(action: onAccept) {
                    Text(hasWeight ? "Accept" : "Got it")
                        .dfFont(.captionStrong)
                        .foregroundStyle(Color.dfBackground)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(accent, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: onIgnore) {
                    Text("Ignore")
                        .dfFont(.captionStrong)
                        .foregroundStyle(Color.dfSecondaryText)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if hasWeight {
                    Text("or edit below")
                        .dfFont(.micro)
                        .foregroundStyle(Color.dfSecondaryText)
                }
            }
        }
        .padding(CalmStrength.Spacing.sm)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.sm))
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
