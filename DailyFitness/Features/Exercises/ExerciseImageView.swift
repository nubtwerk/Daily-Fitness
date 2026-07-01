import SwiftUI
import UIKit

/// Renders an exercise illustration from its stored `imageURL`, which is never nil:
///   • `http(s)://…`   → remote photo via AsyncImage (free-exercise-db CDN)
///   • `asset:<name>`  → bundled asset-catalog image
///   • `placeholder:…` → a calm per-category SF Symbol tile (the common case for
///                       curated/generated records that have no photo)
/// Any load failure falls back to the category tile, so a row never shows blank.
struct ExerciseImageView: View {
    let imageURL: String?
    let category: ExerciseCategory
    var cornerRadius: CGFloat = CalmStrength.Radius.sm

    var body: some View {
        Group {
            if let url = remoteURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder.overlay { ProgressView().tint(Color.dfSecondaryText) }
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else if let assetName, UIImage(named: assetName) != nil {
                Image(assetName).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .background(Color.dfSurface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var remoteURL: URL? {
        guard let imageURL, imageURL.hasPrefix("http") else { return nil }
        return URL(string: imageURL)
    }

    private var assetName: String? {
        guard let imageURL, imageURL.hasPrefix("asset:") else { return nil }
        return String(imageURL.dropFirst("asset:".count))
    }

    private var placeholder: some View {
        ZStack {
            Color.dfSurface
            Image(systemName: category.symbolName)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.dfPrimary.opacity(0.45))
        }
    }
}
