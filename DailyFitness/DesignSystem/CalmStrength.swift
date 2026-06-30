import SwiftUI
import UIKit

// MARK: - Calm Strength design language
//
// DailyFitness's visual identity (PRD §6 / US-001): warm stone neutrals, deep
// forest primary, a single muted-sage accent. Calm, capable, gender-neutral —
// "Apple Health meets a calm studio", never gym-bro. This file is the single
// source of truth for that language: tokens (spacing, radius, type, elevation,
// motion), the color palette, and the shared components every screen is built
// from. Touch the language here, not screen-by-screen.

enum CalmStrength {

    // MARK: Spacing — an 8pt-ish rhythm with a tight 4pt step for dense rows.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner radii — continuous corners everywhere (see `.continuous`).
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12   // controls / buttons
        static let lg: CGFloat = 16   // cards
        static let pill: CGFloat = 999
    }

    // MARK: Typography
    //
    // SF Pro (the system face) on Dynamic Type text styles, so the scale honors
    // the user's text-size setting. Headings are *medium* weight — present but
    // unshouty — and body/title styles carry explicit line spacing for a calm,
    // readable rhythm. Use via `Text(...).dfFont(.heading)`.
    enum Typography: CaseIterable {
        case display       // hero moments — onboarding, paywall
        case title         // screen titles
        case heading       // card titles, section headers (medium weight)
        case subheading    // emphasis, control labels
        case body          // running text
        case callout       // secondary running text
        case caption       // metadata
        case captionStrong // emphasized metadata
        case micro         // the very smallest labels

        var font: Font {
            switch self {
            case .display:       return .system(.largeTitle, design: .default).weight(.semibold)
            case .title:         return .system(.title2, design: .default).weight(.semibold)
            case .heading:       return .system(.title3, design: .default).weight(.medium)
            case .subheading:    return .system(.headline, design: .default).weight(.medium)
            case .body:          return .system(.body, design: .default)
            case .callout:       return .system(.callout, design: .default)
            case .caption:       return .system(.caption, design: .default)
            case .captionStrong: return .system(.caption, design: .default).weight(.medium)
            case .micro:         return .system(.caption2, design: .default)
            }
        }

        var lineSpacing: CGFloat {
            switch self {
            case .display:  return 4
            case .title:    return 3
            case .heading:  return 2
            case .body:     return 5
            case .callout:  return 3
            default:        return 1
            }
        }
    }

    // MARK: Elevation
    //
    // Cards sit on a *very* soft shadow in light mode — black at 6% opacity, a
    // wide 12pt blur, nudged 4pt down. Shadows read as mud on dark surfaces, so
    // in dark mode cards are defined by a 1px hairline instead (see DFCard).
    enum Elevation {
        static let shadowColor = Color.black.opacity(0.06)
        static let shadowRadius: CGFloat = 12
        static let shadowY: CGFloat = 4

        /// A tighter, slightly stronger shadow for floating/raised surfaces.
        static let raisedColor = Color.black.opacity(0.10)
        static let raisedRadius: CGFloat = 20
        static let raisedY: CGFloat = 8
    }

    // MARK: Motion — gentle springs only. Nothing snaps or flashes.
    enum Motion {
        /// Default — content transitions and value changes.
        static let gentle = Animation.spring(response: 0.4, dampingFraction: 0.85)
        /// Button-press feedback — a touch quicker, lightly bouncy.
        static let press = Animation.spring(response: 0.3, dampingFraction: 0.72)
        /// Larger entrances — slow and settled.
        static let settle = Animation.spring(response: 0.55, dampingFraction: 0.9)
    }

    /// Configure system bars (nav + tab) to the Calm Strength language: a warm
    /// stone background, forest titles, no hard divider lines. Call once at launch.
    @MainActor
    static func configureGlobalAppearance() {
        let stone = UIColor(named: "Background") ?? .systemBackground
        let forest = UIColor(named: "Primary") ?? .label
        let secondary = UIColor(named: "SecondaryText") ?? .secondaryLabel

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = stone
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .foregroundColor: forest,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: forest,
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = stone
        tab.shadowColor = UIColor.separator.withAlphaComponent(0.18)
        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.selected.iconColor = forest
            layout.selected.titleTextAttributes = [.foregroundColor: forest]
            layout.normal.iconColor = secondary
            layout.normal.titleTextAttributes = [.foregroundColor: secondary]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - Palette

extension Color {
    static let dfBackground = Color("Background")        // warm stone
    static let dfPrimary = Color("Primary")              // deep forest (inverts to pale sage in dark)
    static let dfAccent = Color("Accent")                // muted sage
    static let dfSecondaryText = Color("SecondaryText")  // muted sage-gray
    static let dfSurface = Color("Surface")              // card surface

    /// Forest fill for the primary CTA. `dfPrimary` inverts to a pale tint in dark
    /// mode (it's a text color), so it can't back a white-text button — this stays
    /// deep in both appearances, brightened a little in dark so it lifts off the
    /// warm-black background.
    static let dfPrimaryFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.243, green: 0.420, blue: 0.341, alpha: 1)
            : UIColor(red: 0.176, green: 0.290, blue: 0.243, alpha: 1)
    })

    /// Foreground on filled primary buttons — a warm near-white, never pure #FFF.
    static let dfOnPrimary = Color(.sRGB, red: 0.97, green: 0.96, blue: 0.94, opacity: 1)

    /// Defines card edges in dark mode, where the light-mode shadow vanishes.
    static let dfHairline = Color.white.opacity(0.08)
}

// MARK: - Typography modifier

private struct DFTypographyModifier: ViewModifier {
    let style: CalmStrength.Typography
    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(style.lineSpacing)
    }
}

extension View {
    /// Apply a Calm Strength type style (font + line spacing) in one call.
    func dfFont(_ style: CalmStrength.Typography) -> some View {
        modifier(DFTypographyModifier(style: style))
    }
}

// MARK: - Card

/// The elevated surface every block of content sits on: warm surface fill,
/// continuous-rounded corners, a soft shadow in light mode and a 1px hairline
/// in dark. Full-width by default so cards line up into a calm column.
struct DFCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let alignment: HorizontalAlignment
    private let content: Content

    init(alignment: HorizontalAlignment = .leading, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .padding(CalmStrength.Spacing.md)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .background(
                Color.dfSurface,
                in: RoundedRectangle(cornerRadius: CalmStrength.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CalmStrength.Radius.lg, style: .continuous)
                    .strokeBorder(Color.dfHairline, lineWidth: scheme == .dark ? 1 : 0)
            )
            .shadow(
                color: scheme == .dark ? .clear : CalmStrength.Elevation.shadowColor,
                radius: CalmStrength.Elevation.shadowRadius,
                x: 0,
                y: CalmStrength.Elevation.shadowY
            )
    }
}

// MARK: - Button styles
//
// Three tiers replace the stock .borderedProminent / .bordered chrome:
//   • primary   — filled forest, white text, spring press scale
//   • secondary — tinted/ghost forest on a faint forest wash
//   • tertiary  — plain text, for low-emphasis actions
// Each carries the same calm press animation.

struct DFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dfFont(.subheading)
            .foregroundStyle(Color.dfOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, CalmStrength.Spacing.lg)
            .background(
                Color.dfPrimaryFill,
                in: RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.94 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(CalmStrength.Motion.press, value: configuration.isPressed)
    }
}

struct DFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dfFont(.subheading)
            .foregroundStyle(Color.dfPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, CalmStrength.Spacing.lg)
            .background(
                Color.dfPrimary.opacity(0.10),
                in: RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous)
                    .strokeBorder(Color.dfPrimary.opacity(0.20), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(CalmStrength.Motion.press, value: configuration.isPressed)
    }
}

struct DFTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dfFont(.subheading)
            .foregroundStyle(Color.dfPrimary)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(CalmStrength.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DFPrimaryButtonStyle {
    static var dfPrimary: DFPrimaryButtonStyle { DFPrimaryButtonStyle() }
}
extension ButtonStyle where Self == DFSecondaryButtonStyle {
    static var dfSecondary: DFSecondaryButtonStyle { DFSecondaryButtonStyle() }
}
extension ButtonStyle where Self == DFTertiaryButtonStyle {
    static var dfTertiary: DFTertiaryButtonStyle { DFTertiaryButtonStyle() }
}

// MARK: - Button components (convenience wrappers over the styles above)

struct DFPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.dfPrimary)
    }
}

struct DFSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.dfSecondary)
    }
}

struct DFTertiaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.dfTertiary)
    }
}

// MARK: - Section header

struct DFSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .dfFont(.heading)
            .foregroundStyle(Color.dfPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Flow mark
//
// The Calm Strength glyph: two balanced flowing arcs inside a soft tonal disc —
// movement and balance, deliberately abstract. Not a barbell, not a body. Used
// as the empty-state mark and echoed in the app icon (PRD §6 iconography).

struct DFArc: Shape {
    let start: Angle
    let end: Angle
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: start,
            endAngle: end,
            clockwise: clockwise
        )
        return path
    }
}

struct DFFlowMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.dfAccent.opacity(0.14))
            DFArc(start: .degrees(160), end: .degrees(20), clockwise: false)
                .stroke(Color.dfAccent, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .padding(size * 0.24)
            DFArc(start: .degrees(340), end: .degrees(200), clockwise: false)
                .stroke(Color.dfPrimary.opacity(0.55), style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Empty state

/// Calm empty state: the flow mark, a title + message, and an optional CTA.
/// Existing call sites pass only `title`/`message`; supply `actionTitle`/`action`
/// to surface a next step.
struct DFEmptyState: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.md) {
            DFFlowMark(size: 64)
            VStack(spacing: CalmStrength.Spacing.xs) {
                Text(title)
                    .dfFont(.heading)
                    .foregroundStyle(Color.dfPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .dfFont(.callout)
                    .foregroundStyle(Color.dfSecondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                DFSecondaryButton(title: actionTitle, action: action)
                    .padding(.top, CalmStrength.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(CalmStrength.Spacing.xl)
    }
}
