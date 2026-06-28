import SwiftUI

enum CalmStrength {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}

extension Color {
    static let dfBackground = Color("Background")
    static let dfPrimary = Color("Primary")
    static let dfAccent = Color("Accent")
    static let dfSecondaryText = Color("SecondaryText")
    static let dfSurface = Color("Surface")
}

struct DFCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(CalmStrength.Spacing.md)
            .background(Color.dfSurface)
            .clipShape(RoundedRectangle(cornerRadius: CalmStrength.Radius.md))
    }
}

struct DFPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CalmStrength.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.dfPrimary)
    }
}

struct DFSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CalmStrength.Spacing.md)
        }
        .buttonStyle(.bordered)
        .tint(Color.dfPrimary)
    }
}

struct DFSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.dfPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DFEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.dfPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.dfSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(CalmStrength.Spacing.lg)
    }
}
