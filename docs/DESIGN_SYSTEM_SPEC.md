# Calm Strength — SwiftUI Design System Specification

**Status:** Implementation spec (v1) · **Owner:** next eng/design workflow
**Target file:** `DailyFitness/DesignSystem/CalmStrength.swift` (replace/extend) + mechanical restyle of feature views
**Grounded in:** PRD §6 "Branding & Visual Identity (Calm Strength)" + the design audit verdict ("systemic design-language gap, not a cosmetic skin")

---

## 0. Why this exists (the one-paragraph problem)

The app "looks horrible" not because the palette is wrong — the Calm Strength colors (warm stone, forest, sage) are already correctly defined in the asset catalog, light + dark. It looks horrible because **the SwiftUI layer that paints with them is a ~101-line token stub**: spacing + radius + 5 colors + one flat depthless card + two stock system buttons. There is **no typography scale, no elevation/shadow, no motion system, no component variants, no iconography**. Every screen therefore composes raw SwiftUI defaults around brand colors and reads as an unfinished Xcode scaffold wearing a green tint. This document specifies the missing design **language** so the app reads as "Apple Health meets calm studio" (PRD §6), not "default Form with a tint".

**Guiding feel (PRD §6):** Calm, capable, welcoming. Steady daily practice. *Not* aggressive, *not* bro-culture, *not* guilt/streak-shaming, *not* "PR or die". Gentle springs, smooth countdowns — never flashing red. Abstract movement marks (arcs, balance, flow lines) — never barbells or flexed biceps.

**Scope of this spec:** the design SYSTEM (tokens + components) plus the restyle pattern for views. It does NOT cover feature/content gaps (more exercises, paywall triggers, etc.) — those are tracked separately.

---

## 1. Color roles (semantic mapping)

The asset catalog already ships these colorsets. **Do not rename the asset names** (`Background`, `Primary`, `Accent`, `Surface`, `SecondaryText`) — code references `Color("Background")` etc. Instead, give each a **semantic role** and add the small number of missing tokens.

### 1.1 Existing assets → semantic roles

| Asset name | Role | Light (sRGB) | Dark (sRGB) | Usage |
|---|---|---|---|---|
| `Background` | App canvas | `#F5F2ED` warm stone | `#22201E` warm charcoal | Screen background behind everything. Set on every screen via `.dfScreenBackground()`. |
| `Surface` | Card / elevated surface | `#FFFFFF` | `#33302E` | Cards, sheets, grouped rows. NOTE: white-on-stone has near-zero contrast — see §3. |
| `Primary` | Brand ink / headings / primary fill | `#2D4A3E` deep forest | `#D8E0D1` pale sage-grey | Headings, primary button fill, key glyphs. In dark mode it inverts to a light ink (correct). |
| `Accent` | Single accent (sage) | `#7A9E8E` | *(missing — see below)* | Rest timer ring, completion checkmark, active states, links. Use sparingly — ONE accent. |
| `SecondaryText` | Muted text | `#6B7A6B` | `#9EA89E` | Captions, set labels, metadata, placeholder copy. |

### 1.2 New tokens to ADD

1. **`Accent` dark variant (REQUIRED FIX).** `Accent.colorset` currently has only a universal value, so the sage looks muddy/off-balance in dark mode while every other color has a dark variant. Add a dark appearance to `Accent.colorset/Contents.json`:
   - Dark (luminosity=dark): `#8FB2A3` (slightly lighter, more legible sage) → `red 0.560, green 0.700, blue 0.640`.

2. **`SurfaceElevated` (new colorset, light only differs).** A faint warm off-white so stacked/elevated cards read above plain `Surface` and above the stone background where shadow alone is weak.
   - Light: `#FFFDFA` (`red 1.000, green 0.992, blue 0.980`)
   - Dark: `#3A3734` (one step lighter than `Surface` dark)

3. **`Hairline` (new colorset).** A 1px separator/stroke color for dark mode where shadows read poorly, and for input borders.
   - Light: forest at 8% → implement in code as `Color.dfPrimary.opacity(0.08)` (no asset needed).
   - Dark: `Color.white.opacity(0.10)`.
   - Provide as a computed token (see §1.3), not necessarily an asset.

4. **Semantic status colors** (used calmly, never alarmingly):
   - `Success` = reuse `Accent` (sage) — completion, PRs.
   - `Warning` = muted terracotta `#C4785A` (PRD §6 lists terracotta as an alternate accent; reserve it for non-destructive emphasis like a deload nudge). Add `Terracotta.colorset` if/when needed; not required for Phase 1.
   - **No red urgency color.** Destructive actions use `.red` ONLY for "Discard/Delete" confirmations — never the rest timer.

### 1.3 Color extension (replace current `extension Color`)

```swift
extension Color {
    // Canvas & surfaces
    static let dfBackground      = Color("Background")
    static let dfSurface         = Color("Surface")
    static let dfSurfaceElevated = Color("SurfaceElevated")

    // Ink & accent
    static let dfPrimary       = Color("Primary")
    static let dfAccent        = Color("Accent")
    static let dfSecondaryText = Color("SecondaryText")

    // Derived / computed tokens (no asset needed)
    static let dfHairline = Color.dfPrimary.opacity(0.08)        // light; pair with .white.opacity(0.10) in dark via overlay logic
    static let dfFieldBackground = Color.dfPrimary.opacity(0.04) // input fill that matches the card system
}
```

> **Contrast note (root cause #1 of "flat"):** On the warm-stone `#F5F2ED` background, `#FFFFFF` cards differ by only a few % luminance, so cards "disappear". The fix is NOT a darker background — it is **elevation (shadow) + a hairline + correct surface token** (see §3). Keep the warm palette; make cards lift off it.

---

## 2. Typography scale

PRD §6: *"SF Pro; medium-weight headings, generous line height."* Today every view uses raw `.headline/.subheadline/.caption` with ad-hoc inline `.weight()` and zero `.lineSpacing`. Replace with a named scale.

### 2.1 The scale

| Token | Use | Font | Size | Weight | Line spacing |
|---|---|---|---|---|---|
| `dfDisplay` | Big numbers (rest timer, today's date hero, summary stats) | SF Pro Rounded | 40 | `.medium` | 0 |
| `dfTitle` | Screen titles / large section intros | SF Pro | 28 | `.medium` | 2 |
| `dfHeading` | Card titles, section headers | SF Pro | 20 | `.medium` | 2 |
| `dfSubheading` | Row primary text, sub-section | SF Pro | 17 | `.medium` | 2 |
| `dfBody` | Body copy, descriptions | SF Pro | 16 | `.regular` | 4 (generous) |
| `dfCallout` | Buttons, emphasized inline | SF Pro | 16 | `.semibold` | 0 |
| `dfCaption` | Metadata, set labels, helper text | SF Pro | 13 | `.regular` | 2 |
| `dfMono` | Weight/reps/timer digits | SF Pro (`.monospacedDigit()`) | inherits | inherits | 0 |

**Headings are `.medium`, never `.bold`** — this is the single biggest "calm not aggressive" signal. Reserve `.semibold` for buttons/callouts only.

### 2.2 Implementation

```swift
extension CalmStrength {
    enum Typography {
        static let display    = Font.system(size: 40, weight: .medium, design: .rounded)
        static let title      = Font.system(size: 28, weight: .medium)
        static let heading    = Font.system(size: 20, weight: .medium)
        static let subheading = Font.system(size: 17, weight: .medium)
        static let body       = Font.system(size: 16, weight: .regular)
        static let callout    = Font.system(size: 16, weight: .semibold)
        static let caption    = Font.system(size: 13, weight: .regular)
    }
}

// View sugar so call sites read cleanly and line spacing comes for free.
extension View {
    func dfText(_ token: Font, lineSpacing: CGFloat = 0) -> some View {
        self.font(token).lineSpacing(lineSpacing)
    }
}
```

Usage: `Text("Today").dfText(CalmStrength.Typography.heading)` · body copy: `Text(desc).dfText(CalmStrength.Typography.body, lineSpacing: 4)`.

> Prefer Dynamic Type later by switching to `Font.custom(...).relativeTo(...)`/`.system(.title, design:)` mappings — Phase 1 may ship fixed sizes, but keep the token names so the migration is mechanical.

---

## 3. Elevation & surfaces

Root cause of the "flat" look: **0 `.shadow(` calls in the whole app** and a `DFCard` that is just `.background + clipShape`. Introduce an elevation ladder.

### 3.1 Elevation tokens

```swift
extension CalmStrength {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Elevation {
        // Soft, low-opacity, large-blur — calm, not "material design" hard.
        static let card     = Shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let raised   = Shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 8)  // sheets, active workout banner
        static let pressed  = Shadow(color: .black.opacity(0.04), radius: 6,  x: 0, y: 2)  // while a card is pressed
    }
}

extension View {
    func dfShadow(_ s: CalmStrength.Shadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}
```

### 3.2 Dark-mode rule
Shadows read poorly on dark backgrounds. In dark mode, **also** apply a 1px hairline stroke so the card edge is legible:

```swift
.overlay(
    RoundedRectangle(cornerRadius: r, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        .opacity(colorScheme == .dark ? 1 : 0)
)
```

### 3.3 Corner radii (use `.continuous` everywhere)
Keep existing `Radius` but add an `xl` and standardize on **continuous** (squircle) corners — `RoundedRectangle(cornerRadius:style:.continuous)` — which reads softer/more Apple than the default circular arc.

```swift
enum Radius {
    static let sm: CGFloat = 8     // chips, small controls
    static let md: CGFloat = 14    // cards (bumped from 12 for softer feel)
    static let lg: CGFloat = 20    // sheets, hero cards
    static let pill: CGFloat = 999 // capsule buttons, chips
}
```

---

## 4. Spacing rhythm & layout

Keep the existing 4/8/16/24/32 scale; add `xxl` and document the rhythm so screens stop feeling cramped/inconsistent.

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48   // top-of-screen breathing room, empty-state vertical pad
}
```

**Layout rules:**
- **Screen content inset:** horizontal `Spacing.md` (16); top `Spacing.lg` (24) below the nav title.
- **Between sections:** `Spacing.xl` (32). Between a section header and its content: `Spacing.sm` (8).
- **Inside a card:** padding `Spacing.md` (16); between stacked cards in a list: `Spacing.md` (16).
- **Vertical rhythm in a card:** title → `Spacing.xs` → metadata; content groups separated by `Spacing.sm`.
- **Tap targets:** keep the existing 44pt minimum (already honored on complete buttons).
- **Hierarchy:** one screen = one `dfTitle` (or branded nav title), section = `dfHeading`, card title = `dfSubheading`, supporting = `dfCaption`. Never stack two `.bold` blacks adjacent.

Helper for consistent screen scaffolding:

```swift
extension View {
    func dfScreenBackground() -> some View {
        self.background(Color.dfBackground.ignoresSafeArea())
            .scrollContentBackground(.hidden) // so Form/List don't paint grey
    }
}
```

---

## 5. Motion

Root cause: only 3 animation calls exist, all in one toast; PRD §6 wants "gentle springs". Add a Motion namespace and wire it into presses, completions, transitions, and the rest timer.

```swift
extension CalmStrength {
    enum Motion {
        // Calm, slightly underdamped springs — settle without bounce.
        static let standard = Animation.spring(response: 0.40, dampingFraction: 0.85)
        static let gentle   = Animation.spring(response: 0.55, dampingFraction: 0.90) // screen/step transitions
        static let snappy   = Animation.spring(response: 0.30, dampingFraction: 0.80) // button press feedback
        static let calm     = Animation.easeInOut(duration: 0.8)                      // rest-timer ring depletion
    }
}
```

**Where motion must land (Phase 1):**
- **Button press:** scale to `0.97` on press, spring back (`Motion.snappy`). Built into the ButtonStyle (§6.2) — free everywhere.
- **Card tap (tappable rows):** scale `0.98` + elevation drop to `.pressed` while pressed (`Motion.standard`).
- **Set completion:** checkmark scales in (`0.6 → 1.0`) and the row gets a soft sage fill sweep (`Motion.standard`). This is the most-used interaction; making it feel rewarding-but-calm is high ROI (also satisfies the LOG-04 haptic gap when paired with `.sensoryFeedback(.success, ...)`).
- **Onboarding step change & full-screen workout present:** `Motion.gentle` with `.opacity.combined(with: .move(edge: .trailing))`.
- **Rest timer ring:** smooth `Motion.calm` depletion (§6.7) — NEVER color-flash, NEVER red.

> **Haptics (closes LOG-04):** pair completion animations with `.sensoryFeedback(.success, trigger: set.isCompleted)` and `.sensoryFeedback(.impact(weight: .light), trigger:)` on rest start. This is a system-level addition the design system should mandate, not a separate feature.

---

## 6. Component specs

### 6.1 `DFCard` (redesigned — fixes the #1 flat-look driver)

**Before:** `content.padding(16).background(Surface).clipShape(rounded 12)` — no shadow, no border, invisible on stone.
**After:** elevated, continuous corners, soft shadow, dark-mode hairline, optional pressable variant.

```swift
struct DFCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var elevation: CalmStrength.Shadow = CalmStrength.Elevation.card
    var padding: CGFloat = CalmStrength.Spacing.md
    let content: Content

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
            .background(Color.dfSurface, in: RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CalmStrength.Radius.md, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .opacity(scheme == .dark ? 1 : 0)
            )
            .dfShadow(scheme == .dark ? CalmStrength.Elevation.pressed : elevation)
    }
}
```

**Tappable card variant** (HomeView routine rows, Programs rows) — add a button style so the whole card springs on tap:

```swift
struct DFCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(CalmStrength.Motion.standard, value: configuration.isPressed)
    }
}
// Usage: Button { ... } label: { DFCard { rowContent } }.buttonStyle(DFCardButtonStyle())
```

### 6.2 Buttons (primary / secondary / tertiary)

**Before:** `.borderedProminent` / `.bordered` — the canonical "default SwiftUI / unfinished" look.
**After:** custom `ButtonStyle`s with forest fill, capsule shape, spring press, soft shadow.

```swift
struct DFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CalmStrength.Typography.callout)
            .foregroundStyle(Color.dfBackground)            // light ink on forest
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dfPrimary, in: Capsule(style: .continuous))
            .dfShadow(CalmStrength.Elevation.card)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(CalmStrength.Motion.snappy, value: configuration.isPressed)
    }
}

struct DFSecondaryButtonStyle: ButtonStyle {   // ghost / tinted
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CalmStrength.Typography.callout)
            .foregroundStyle(Color.dfPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dfPrimary.opacity(0.10), in: Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(CalmStrength.Motion.snappy, value: configuration.isPressed)
    }
}

struct DFTertiaryButtonStyle: ButtonStyle {    // text-only: "Skip", "Restore purchases", "+30s"
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CalmStrength.Typography.callout)
            .foregroundStyle(Color.dfAccent)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(CalmStrength.Motion.snappy, value: configuration.isPressed)
    }
}
```

Keep `DFPrimaryButton` / `DFSecondaryButton` wrapper views for source compatibility, but have them apply the new styles. Add a `DFTertiaryButton`.

### 6.3 Section header

**Before:** `Text(title).font(.title3.weight(.semibold)).foregroundStyle(Primary)`.
**After:** medium-weight heading token, optional trailing accessory (e.g. "See all"), consistent leading.

```swift
struct DFSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).dfText(CalmStrength.Typography.heading)
                .foregroundStyle(Color.dfPrimary)
            Spacer()
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
extension DFSectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}
```

### 6.4 List / rows

**Before:** four stock `Form` screens (RoutineEditorView, ProgramDetailView, ProfileView, CustomExerciseEditorView) render as grey grouped iOS Settings UI and clash with the hand-rolled card screens — "looks like two different apps."
**After (two acceptable paths):**
1. **Restyle the Form** (cheaper): `Form { ... }.scrollContentBackground(.hidden).background(Color.dfBackground)` + custom section headers via `Section { } header: { DFSectionHeader(...) }`, and set row backgrounds with `.listRowBackground(Color.dfSurface)`.
2. **Replace with card sections** (preferred for editors): vertical `ScrollView` of `DFCard` groups using `DFSectionHeader` + `DFListRow` items.

```swift
struct DFListRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(spacing: CalmStrength.Spacing.md) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).dfText(CalmStrength.Typography.subheading)
                if let subtitle {
                    Text(subtitle).dfText(CalmStrength.Typography.caption)
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
```

### 6.5 Inputs (set rows — the most-used screen)

**Before:** `StrengthSetRow`/`DurationSetRow`/`HoldSetRow` use `.textFieldStyle(.roundedBorder)` (default iOS form look) and the RIR input is a bare `TextField`. Completion is just a symbol swap.
**After:** card-system field style + spring completion + row fill.

```swift
struct DFFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8).padding(.horizontal, 10)
            .background(Color.dfFieldBackground, in: RoundedRectangle(cornerRadius: CalmStrength.Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CalmStrength.Radius.sm, style: .continuous)
                        .strokeBorder(Color.dfHairline, lineWidth: 1))
            .font(CalmStrength.Typography.subheading.monospacedDigit())
    }
}
extension View { func dfField() -> some View { modifier(DFFieldStyle()) } }
```

Replace each `.textFieldStyle(.roundedBorder)` with `.dfField()`. For the completion button, animate the checkmark and fill the row:

```swift
// completeButton
Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
    .font(.title2)
    .foregroundStyle(set.isCompleted ? Color.dfAccent : Color.dfSecondaryText)
    .scaleEffect(set.isCompleted ? 1.0 : 0.9)
    .animation(CalmStrength.Motion.standard, value: set.isCompleted)
// on the row container:
.background(set.isCompleted ? Color.dfAccent.opacity(0.08) : .clear)
.animation(CalmStrength.Motion.standard, value: set.isCompleted)
.sensoryFeedback(.success, trigger: set.isCompleted)
```
> The RIR free-text field should become a 0–5 picker per the progression gap, but that is a feature change; the design system just provides `.dfField()` and a `DFChipPicker` (below) it can adopt.

### 6.6 Empty states (with abstract flow iconography — NOT dumbbells)

**Before:** two lines of text → reads as a broken/blank screen.
**After:** an abstract movement glyph + title + message + optional inline CTA. PRD §6 mandates "arcs, balance, flow lines", explicitly bans barbell/biceps marks.

```swift
struct DFEmptyState: View {
    var systemImage: String = "wind"   // Phase-1 placeholder SF Symbol (abstract/flowing), NOT a dumbbell
    let title: String
    let message: String
    var cta: (title: String, action: () -> Void)? = nil

    var body: some View {
        VStack(spacing: CalmStrength.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.dfAccent.opacity(0.7))
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: CalmStrength.Spacing.xs) {
                Text(title).dfText(CalmStrength.Typography.heading).foregroundStyle(Color.dfPrimary)
                Text(message).dfText(CalmStrength.Typography.body, lineSpacing: 4)
                    .foregroundStyle(Color.dfSecondaryText)
                    .multilineTextAlignment(.center)
            }
            if let cta {
                Button(cta.title, action: cta.action).buttonStyle(DFSecondaryButtonStyle())
                    .fixedSize()
            }
        }
        .padding(.vertical, CalmStrength.Spacing.xxl)
        .padding(.horizontal, CalmStrength.Spacing.lg)
    }
}
```

**Phase-1 SF Symbol stand-ins for the abstract-flow language** (calm, non-gym): `wind`, `circle.hexagongrid`, `figure.mind.and.body`, `infinity`, `point.topleft.down.curvedto.point.bottomright.up` (a flow arc). **Phase 2:** replace with custom PDF/SVG flow-mark vectors (arcs + balance lines) shipped in the asset catalog, plus a real abstract **app icon** (the AppIcon set is currently an empty 177-byte placeholder — PRD §6 demands an abstract flow/balance mark, not a barbell).

### 6.7 Rest timer (calm circular countdown — NOT a flashing number)

**Before:** `RestTimerBanner` shows plain `Text("\(remaining)s")` inside a flat card — no presence, no calm motion.
**After:** a sage circular progress ring that smoothly depletes, large monospaced remaining time centered, gentle scale-in. Explicitly no red, no flashing (PRD §6 + LOCK-02 "calm treatment").

```swift
struct DFRestTimerRing: View {
    let restEndsAt: Date
    let totalSeconds: Int
    var onExtend: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
            let remaining = max(0, restEndsAt.timeIntervalSince(ctx.date))
            let progress = totalSeconds > 0 ? remaining / Double(totalSeconds) : 0
            DFCard {
                HStack(spacing: CalmStrength.Spacing.lg) {
                    ZStack {
                        Circle().stroke(Color.dfAccent.opacity(0.15), lineWidth: 6)
                        Circle().trim(from: 0, to: progress)
                            .stroke(Color.dfAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(CalmStrength.Motion.calm, value: progress)
                        Text("\(Int(remaining))")
                            .dfText(CalmStrength.Typography.display)
                            .monospacedDigit()
                            .foregroundStyle(Color.dfPrimary)
                    }
                    .frame(width: 88, height: 88)

                    VStack(alignment: .leading, spacing: CalmStrength.Spacing.sm) {
                        Text("Rest").dfText(CalmStrength.Typography.heading)
                        HStack(spacing: CalmStrength.Spacing.md) {
                            if let onSkip   { Button("Skip",  action: onSkip).buttonStyle(DFTertiaryButtonStyle()) }
                            if let onExtend { Button("+30s",  action: onExtend).buttonStyle(DFTertiaryButtonStyle()) }
                        }
                    }
                    Spacer()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}
```
> Adds the missing **Skip** control (LOG-05 gap) as a tertiary button while we're here. The lock-screen Live Activity already uses `Text(timerInterval:)` correctly — mirror the calm ring treatment there using a `Gauge`/`ProgressView(timerInterval:)` if widget budget allows; at minimum keep sage, never red.

### 6.8 Chrome — navigation bar & tab bar

**Before:** stock `TabView` with only `.tint`; every tab shows a large **bold-black** `navigationTitle` — the two most prominent chrome elements are 100% iOS default.
**After:** branded appearance with warm-stone background and medium-weight forest titles.

```swift
// Call once at app launch (e.g. in DailyFitnessApp.init or an .onAppear on RootView).
enum AppearanceConfigurator {
    static func apply() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Color.dfBackground)
        nav.shadowColor = .clear  // remove the default hairline under the bar
        let titleColor = UIColor(Color.dfPrimary)
        nav.largeTitleTextAttributes = [.foregroundColor: titleColor,
                                        .font: UIFont.systemFont(ofSize: 30, weight: .medium)]
        nav.titleTextAttributes = [.foregroundColor: titleColor,
                                   .font: UIFont.systemFont(ofSize: 17, weight: .medium)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Color.dfBackground)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
```
Set the SwiftUI tab tint to `.dfAccent` (sage) for selected items so it matches the single-accent rule. Consider `.toolbarBackground(Color.dfBackground, for: .navigationBar)` on screens that need it.

### 6.9 Chips / segmented selection (`DFChip` / `DFChipPicker`)

Needed by category/muscle filters (ExercisePicker), the RIR 0–5 picker, and set-type selection. Provides a calm pill alternative to stock `Picker(.segmented)`.

```swift
struct DFChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).dfText(CalmStrength.Typography.caption)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(isSelected ? Color.dfAccent.opacity(0.18) : Color.dfPrimary.opacity(0.05),
                            in: Capsule(style: .continuous))
                .foregroundStyle(isSelected ? Color.dfPrimary : Color.dfSecondaryText)
        }
        .buttonStyle(.plain)
        .animation(CalmStrength.Motion.snappy, value: isSelected)
    }
}
```

### 6.10 Stat tile / badge (for PR shelf, progress summary, end-of-workout)

```swift
struct DFStatTile: View {
    let value: String   // e.g. "12,450 kg"
    let label: String   // e.g. "Volume"
    var icon: String? = nil
    var body: some View {
        DFCard(padding: CalmStrength.Spacing.md) {
            VStack(alignment: .leading, spacing: CalmStrength.Spacing.xs) {
                if let icon { Image(systemName: icon).foregroundStyle(Color.dfAccent) }
                Text(value).dfText(CalmStrength.Typography.title).foregroundStyle(Color.dfPrimary)
                Text(label).dfText(CalmStrength.Typography.caption).foregroundStyle(Color.dfSecondaryText)
            }
        }
    }
}
```

---

## 7. Before / after rationale (each fix → audit root cause)

| # | Change | Audit root cause it fixes | Why it works |
|---|---|---|---|
| 1 | `DFCard` gets soft shadow + dark hairline + continuous corners | "0 `.shadow(` calls; flat depthless card; white-on-stone near-zero contrast" (audit #1 flat driver) | Cards lift off the stone background, so every screen stops reading as an undifferentiated text list — the single highest-impact change. |
| 2 | Typography token scale, medium-weight headings, line spacing | "No typography system; raw `.headline/.subheadline`; PRD wants medium headings + generous line height" | Establishes hierarchy and the "calm, not aggressive" tone; medium (not bold) headings are the core brand signal. |
| 3 | Custom primary/secondary/tertiary `ButtonStyle` with spring press | "Stock `.borderedProminent`/`.bordered` = canonical default-SwiftUI look" | Removes the most recognizable "unfinished" tell and adds the gentle-spring feedback PRD §6 mandates. |
| 4 | Motion namespace + completion/press/transition animations + haptics | "Only 3 animation calls; 0 haptics (LOG-04 unmet)" | Makes the core logging loop feel rewarding-but-calm and closes an explicit P0 acceptance criterion. |
| 5 | Restyle/replace the 4 stock `Form` screens | "Stock Form = grey Settings UI; app looks like two different apps" | Unifies the visual language so editors match card screens. |
| 6 | Branded nav + tab appearance (warm stone bg, medium forest titles, sage tint) | "Two most-visible chrome elements are 100% iOS default large-bold-black titles" | The brand finally shows in the frame around every screen. |
| 7 | Calm circular rest-timer ring (sage, smooth, no red) + Skip | "Bare 'NNs' text; PRD wants calm countdown not flashing red; LOG-05 missing Skip" | Turns the signature rest moment into an on-brand calm focal point and fills a control gap. |
| 8 | Illustrated empty states with abstract-flow glyph | "Text-only empty states read as broken; PRD bans dumbbells, wants flow marks" | Empty screens look intentional and seed the brand's abstract-movement iconography. |
| 9 | `Accent` dark variant + `SurfaceElevated` + hairline tokens | "Accent has no dark variant; surface ladder undefined; dark shadows read poorly" | Completes dark mode and the surface contrast ladder so cards work in both schemes. |
| 10 | Reusable `DFChip`, `DFListRow`, `DFStatTile` components | "Component kit is one flat card + two stock buttons; no variants" | Gives feature views a shared, on-brand vocabulary instead of ad-hoc stock controls. |

---

## 8. Implementation order (highest ROI first)

**Phase 1 — design language lands (do before any ship; mostly `CalmStrength.swift` + mechanical view edits):**
1. Add typography scale + color/elevation/motion tokens to `CalmStrength.swift`; add `Accent` dark variant + `SurfaceElevated` colorsets.
2. Redesign `DFCard` (shadow + hairline + continuous corners) and add `DFCardButtonStyle`.
3. Replace buttons with `DFPrimary/Secondary/TertiaryButtonStyle`.
4. Apply `AppearanceConfigurator` + sage tab tint; add `.dfScreenBackground()` to all four tab roots.
5. Migrate sampled views' fonts to typography tokens; add `.dfField()` to set rows; animate set completion + add `.sensoryFeedback`.
6. Restyle the 4 `Form` screens (`.scrollContentBackground(.hidden)` + branded sections).
7. Replace `RestTimerBanner` with `DFRestTimerRing`; upgrade `DFEmptyState`.

**Phase 2 — needs design assets/time:**
8. Custom abstract flow/balance vector glyph set (arcs, balance lines) in the asset catalog.
9. Real abstract **app icon** (replace empty placeholder).
10. Soft natural hero/section imagery (onboarding, program cards, empty states) per PRD §6 (real environments, motion blur, mixed bodies/ages).
11. Mirror the calm ring treatment into the Live Activity widget.

**Do NOT ship before Phase 1 lands** — per the audit, the current state reads as broken regardless of feature completeness.

---

## 9. Acceptance checklist (how to know it's done)

- [ ] `grep -r ".shadow(" DailyFitness` returns elevation usage on cards (was 0).
- [ ] No `.borderedProminent` / `.bordered` remain in feature views (`grep`).
- [ ] No `.textFieldStyle(.roundedBorder)` remain in set rows; `.dfField()` used.
- [ ] No raw `.font(.headline/.subheadline/.caption)` in migrated views; typography tokens used.
- [ ] Every screen sets `Color.dfBackground` and `.scrollContentBackground(.hidden)`; no grey grouped Form background visible.
- [ ] Nav titles render medium-weight forest (not bold black); tab tint is sage.
- [ ] Set completion animates + fires `.sensoryFeedback`; rest timer is a sage ring with Skip/+30s, no red.
- [ ] `Accent.colorset` has a dark appearance; cards have a visible edge in both light and dark.
- [ ] Empty states show an abstract-flow glyph (no dumbbell/biceps) + optional CTA.
- [ ] Light AND dark mode both look intentional (run on device per `ios-design-review`).
