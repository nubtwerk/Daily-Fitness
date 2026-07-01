import SwiftUI
import UIKit

// MARK: - Calm Strength design language
//
// DailyFitness's visual identity (PRD §6 / US-001, formalized in
// docs/DESIGN_SYSTEM_SPEC.md): warm stone neutrals, deep forest primary, a
// single muted-sage accent. Calm, capable, gender-neutral — "Apple Health meets
// a calm studio", never gym-bro. This file is the single source of truth for
// that language: tokens (spacing, radius, type, elevation, motion), the color
// palette, system-chrome appearance, and the shared components every screen is
// built from. Touch the language here, not screen-by-screen.

enum CalmStrength {

    // MARK: Spacing — 4 / 8 / 16 / 24 / 32 / 48 rhythm (DSS §4).
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48   // top-of-screen breathing room, empty-state pad
    }

    // MARK: Corner radii — continuous (squircle) corners everywhere (DSS §3.3).
    enum Radius {
        static let sm: CGFloat = 8     // chips, small controls, input fields
        static let md: CGFloat = 14    // cards
        static let lg: CGFloat = 20    // sheets, hero cards
        static let pill: CGFloat = 999 // capsule buttons, chips
    }

    // MARK: Typography (DSS §2)
    //
    // SF Pro. Headings are `.medium` weight — present but unshouty; this is the
    // single biggest "calm not aggressive" signal, so `.semibold` is reserved for
    // buttons/callouts only. Per §2.2 Phase 1 ships fixed sizes with the token
    // names kept, so a later Dynamic-Type migration (`.relativeTo`) is mechanical.
    // Use via `Text(...).dfFont(.heading)`.
    enum Typography: CaseIterable {
        case display       // big numbers — rest timer, hero stats
        case title         // screen titles / large section intros
        case heading       // card titles, section headers
        case subheading    // row primary text, control labels
        case body          // body copy, descriptions
        case callout       // buttons, emphasized inline
        case caption       // metadata, set labels, helper text
        case captionStrong // emphasized metadata
        case micro         // the very smallest labels

        var font: Font {
            switch self {
            case .display:       return .system(size: 40, weight: .medium, design: .rounded)
            case .title:         return .system(size: 28, weight: .medium)
            case .heading:       return .system(size: 20, weight: .medium)
            case .subheading:    return .system(size: 17, weight: .medium)
            case .body:          return .system(size: 16, weight: .regular)
            case .callout:       return .system(size: 16, weight: .semibold)
            case .caption:       return .system(size: 13, weight: .regular)
            case .captionStrong: return .system(size: 13, weight: .medium)
            case .micro:         return .system(size: 11, weight: .regular)
            }
        }

        var lineSpacing: CGFloat {
            switch self {
            case .display:       return 0
            case .title:         return 2
            case .heading:       return 2
            case .subheading:    return 2
            case .body:          return 4   // generous
            case .callout:       return 0
            case .caption:       return 2
            case .captionStrong: return 2
            case .micro:         return 0
            }
        }
    }

    // MARK: Elevation (DSS §3.1)
    //
    // Soft, low-opacity, large-blur shadows — calm, not "material design" hard.
    // Shadows read as mud on dark surfaces, so in dark mode cards drop to the
    // faint `pressed` shadow and lean on a 1px hairline instead (see DFCard).
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Elevation {
        static let card    = Shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let raised  = Shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 8)  // sheets, active banner
        static let pressed = Shadow(color: .black.opacity(0.04), radius: 6,  x: 0, y: 2)  // pressed / dark cards
    }

    // MARK: Motion — gentle springs only (DSS §5). Nothing snaps or flashes.
    enum Motion {
        static let standard = Animation.spring(response: 0.40, dampingFraction: 0.85) // value changes, completions
        static let gentle   = Animation.spring(response: 0.55, dampingFraction: 0.90) // screen / step transitions
        static let snappy   = Animation.spring(response: 0.30, dampingFraction: 0.80) // button press feedback
        static let calm     = Animation.easeInOut(duration: 0.8)                       // rest-timer ring depletion
    }
}

// MARK: - System chrome appearance (DSS §6.8)
//
// Branded nav + tab bars: warm-stone background, medium-weight forest titles, a
// sage-tinted selected tab. NB: this deliberately does NOT set an opaque
// `scrollEdgeAppearance` on the nav bar — on iOS 26 that blanks the large title
// text. Branding the standard + compact states is enough: the large title
// renders over the warm-stone content at the top, and the stone bar appears once
// the user scrolls.
enum AppearanceConfigurator {
    @MainActor
    static func apply() {
        let stone     = UIColor(named: "Background") ?? .systemBackground
        let forest    = UIColor(named: "Primary") ?? .label
        let sage      = UIColor(named: "Accent") ?? .tintColor
        let secondary = UIColor(named: "SecondaryText") ?? .secondaryLabel

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = stone
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .foregroundColor: forest,
            .font: UIFont.systemFont(ofSize: 17, weight: .medium),
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: forest,
            .font: UIFont.systemFont(ofSize: 30, weight: .medium),
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        // scrollEdgeAppearance intentionally left default — see note above.

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = stone
        tab.shadowColor = UIColor.separator.withAlphaComponent(0.18)
        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.selected.iconColor = sage
            layout.selected.titleTextAttributes = [.foregroundColor: sage]
            layout.normal.iconColor = secondary
            layout.normal.titleTextAttributes = [.foregroundColor: secondary]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - Palette (DSS §1.3)

extension Color {
    // Canvas & surfaces
    static let dfBackground      = Color("Background")        // warm stone
    static let dfSurface         = Color("Surface")           // card surface
    static let dfSurfaceElevated = Color("SurfaceElevated")   // faint off-white for stacked/elevated cards

    // Ink & accent
    static let dfPrimary       = Color("Primary")             // deep forest (inverts to pale sage in dark)
    static let dfAccent        = Color("Accent")              // muted sage — the single accent (decorative fills)
    /// AA-safe sage for FOREGROUND glyphs/text on Background or Surface. Plain `dfAccent` only
    /// clears ~2.6–3.0:1 in light mode, so use this for the ring arc, completed checkmark, and
    /// any icon/text that must be legible (WCAG-AA, US-122). Decorative `dfAccent` fills stay as-is.
    static let dfAccentForeground = Color("AccentForeground")
    static let dfSecondaryText = Color("SecondaryText")       // muted sage-gray

    // Derived / computed tokens (no asset needed)
    static let dfHairline        = Color.dfPrimary.opacity(0.08)  // light input/separator border (dark cards use .white.opacity(0.08))
    static let dfFieldBackground = Color.dfPrimary.opacity(0.04)  // input fill that matches the card system
    static let dfWarning         = Color(red: 0.769, green: 0.471, blue: 0.353) // muted terracotta #C4785A — calm warning, never alarm (DSS §1.2)
}

// MARK: - Shadow application

extension View {
    /// Apply a Calm Strength elevation shadow.
    func dfShadow(_ s: CalmStrength.Shadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
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

// MARK: - Card (DSS §6.1)

/// The elevated surface every block of content sits on: warm surface fill,
/// continuous-rounded corners, a soft shadow in light mode and a 1px hairline
/// in dark. Full-width by default so cards line up into a calm column.
struct DFCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var elevation: CalmStrength.Shadow
    var padding: CGFloat
    private let content: Content

    init(elevation: CalmStrength.Shadow = CalmStrength.Elevation.card,
         padding: CGFloat = CalmStrength.Spacing.md,
         @ViewBuilder content: () -> Content) {
        self.elevation = elevation
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.dfSurface,
                in: RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .opacity(scheme == .dark ? 1 : 0)
            )
            .dfShadow(scheme == .dark ? CalmStrength.Elevation.pressed : elevation)
    }
}

/// Wrap a tappable card so the whole surface springs on press.
/// Usage: `Button { … } label: { DFCard { row } }.buttonStyle(DFCardButtonStyle())`.
struct DFCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(CalmStrength.Motion.standard, value: configuration.isPressed)
    }
}

// MARK: - Button styles (DSS §6.2)
//
// Three tiers replace the stock .borderedProminent / .bordered chrome:
//   • primary   — filled forest, light ink, capsule, spring press + soft shadow
//   • secondary — tinted forest wash, capsule
//   • tertiary  — sage text only, for low-emphasis actions ("Skip", "+30s")
// `dfPrimary`/`dfBackground` both invert in dark mode, so the filled CTA stays
// legible in both schemes without hardcoded colors.

struct DFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dfFont(.callout)
            .foregroundStyle(Color.dfBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dfPrimary, in: Capsule(style: .continuous))
            .dfShadow(CalmStrength.Elevation.card)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(CalmStrength.Motion.snappy, value: configuration.isPressed)
    }
}

struct DFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dfFont(.callout)
            .foregroundStyle(Color.dfPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dfPrimary.opacity(0.10), in: Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(CalmStrength.Motion.snappy, value: configuration.isPressed)
    }
}

struct DFTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dfFont(.callout)
            .foregroundStyle(Color.dfAccent)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(CalmStrength.Motion.snappy, value: configuration.isPressed)
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
    var body: some View { Button(title, action: action).buttonStyle(.dfPrimary) }
}

struct DFSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View { Button(title, action: action).buttonStyle(.dfSecondary) }
}

struct DFTertiaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View { Button(title, action: action).buttonStyle(.dfTertiary) }
}

// MARK: - Section header (DSS §6.3)

struct DFSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .dfFont(.heading)
                .foregroundStyle(Color.dfPrimary)
            Spacer()
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension DFSectionHeader where Trailing == EmptyView {
    init(title: String) { self.init(title: title) { EmptyView() } }
}

// MARK: - List row (DSS §6.4)

struct DFListRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: CalmStrength.Spacing.md) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).dfFont(.subheading)
                if let subtitle {
                    Text(subtitle)
                        .dfFont(.caption)
                        .foregroundStyle(Color.dfSecondaryText)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, CalmStrength.Spacing.xs)
        .frame(minHeight: 44)
    }
}

// MARK: - Inputs (DSS §6.5)

/// Card-system field style for set-row inputs — faint forest fill, hairline
/// border, continuous corners, monospaced digits. Replaces `.roundedBorder`.
struct DFFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                Color.dfFieldBackground,
                in: RoundedRectangle(cornerRadius: CalmStrength.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CalmStrength.Radius.sm, style: .continuous)
                    .strokeBorder(Color.dfHairline, lineWidth: 1)
            )
            .font(CalmStrength.Typography.subheading.font.monospacedDigit())
    }
}

extension View {
    /// Calm Strength input field styling — use on set-row `TextField`s.
    func dfField() -> some View { modifier(DFFieldStyle()) }
}

// MARK: - Chips / segmented selection (DSS §6.9)

struct DFChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dfFont(.caption)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    isSelected ? Color.dfAccent.opacity(0.18) : Color.dfPrimary.opacity(0.05),
                    in: Capsule(style: .continuous)
                )
                .foregroundStyle(isSelected ? Color.dfPrimary : Color.dfSecondaryText)
        }
        .buttonStyle(.plain)
        .animation(CalmStrength.Motion.snappy, value: isSelected)
    }
}

/// A horizontally-scrolling row of `DFChip`s bound to a single selection — a
/// calm replacement for stock `Picker(.segmented)`.
struct DFChipPicker<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CalmStrength.Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    DFChip(title: title(option), isSelected: option == selection) {
                        selection = option
                    }
                }
            }
        }
    }
}

// MARK: - Stat tile (DSS §6.10)

struct DFStatTile: View {
    let value: String   // e.g. "12,450 kg"
    let label: String   // e.g. "Volume"
    var icon: String? = nil

    var body: some View {
        DFCard(padding: CalmStrength.Spacing.md) {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                if let icon {
                    Image(systemName: icon).foregroundStyle(Color.dfAccent)
                }
                Text(value).dfFont(.title).foregroundStyle(Color.dfPrimary)
                Text(label).dfFont(.caption).foregroundStyle(Color.dfSecondaryText)
            }
        }
    }
}

// MARK: - Rest timer (DSS §6.7)

/// A calm sage countdown ring (never red, never flashing): a circular progress
/// track that smoothly depletes, the remaining seconds centered in display type,
/// plus Skip / +30s tertiary controls.
struct DFRestTimerRing: View {
    let restEndsAt: Date
    let totalSeconds: Int
    var onExtend: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
            let remaining = max(0, restEndsAt.timeIntervalSince(ctx.date))
            let progress = totalSeconds > 0 ? min(1, remaining / Double(totalSeconds)) : 0
            DFCard {
                HStack(spacing: CalmStrength.Spacing.lg) {
                    ZStack {
                        Circle().stroke(Color.dfAccent.opacity(0.15), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress)
                            // AA-safe sage for the informational progress arc (dfAccent alone is < 3:1).
                            .stroke(Color.dfAccentForeground, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(CalmStrength.Motion.calm, value: progress)
                        Text("\(Int(remaining))")
                            .dfFont(.display)
                            .monospacedDigit()
                            .foregroundStyle(Color.dfPrimary)
                    }
                    .frame(width: 88, height: 88)
                    // One VoiceOver element whose value updates each tick as it counts down.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rest timer")
                    .accessibilityValue("\(Int(remaining)) seconds remaining")
                    .accessibilityAddTraits(.updatesFrequently)

                    VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                        Text("Rest").dfFont(.heading)
                        HStack(spacing: CalmStrength.Spacing.md) {
                            if let onSkip { Button("Skip", action: onSkip).buttonStyle(.dfTertiary) }
                            if let onExtend {
                                Button("+30s", action: onExtend)
                                    .buttonStyle(.dfTertiary)
                                    .accessibilityLabel("Add 30 seconds")
                            }
                        }
                    }
                    Spacer()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            // In-app signal when rest ends, independent of the optional notification (US-053).
            .sensoryFeedback(.success, trigger: remaining == 0)
        }
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

// MARK: - Empty state (DSS §6.6)

/// Calm empty state: the abstract flow mark, a title + message, and an optional
/// CTA. Existing call sites pass only `title`/`message`; supply
/// `actionTitle`/`action` to surface a next step.
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
                    .dfFont(.body)
                    .foregroundStyle(Color.dfSecondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                DFSecondaryButton(title: actionTitle, action: action)
                    .fixedSize()
                    .padding(.top, CalmStrength.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CalmStrength.Spacing.xxl)
        .padding(.horizontal, CalmStrength.Spacing.lg)
    }
}
