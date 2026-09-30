import SwiftUI
import TrainTogetherCore

// Design tokens for the Constructivist visual system
// (styleguide/train-together-style-guide.md), ported from frontend/src/theme.js.
// Compiled into the app and the widget extension, so it depends on nothing but
// SwiftUI and the Core records.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    // Surfaces
    static let paper = Color(hex: 0xF1E6D0) // main warm background
    static let canvas = Color(hex: 0xFAF5EA) // cards, inputs, raised surfaces
    static let ink = Color(hex: 0x181816) // text, rules, dark blocks
    static let scrim = Color(hex: 0x181816, opacity: 0.55)

    // Text. Concrete fails contrast as text on Canvas (§29), so secondary text
    // uses a warm ink tint (~5.2:1) and Concrete is kept for rules/disabled.
    static let text = ink
    static let textSecondary = Color(hex: 0x6B665C)
    static let onDark = paper
    static let onDarkMuted = Color(hex: 0xF1E6D0, opacity: 0.62)
    // Canvas, not Paper, on red fills: Paper is 4.40:1 on Revolution Red,
    // just under AA; Canvas clears it at 5.00:1.
    static let onAccent = canvas

    // Rules — the system separates with borders, not shadows.
    static let rule = ink
    static let ruleSoft = Color(hex: 0xA69D8D)

    // Semantic
    static let red = Color(hex: 0xC92C1C) // Revolution Red — primary action fills
    static let redDark = Color(hex: 0x8F1E16) // pressed; red *text* on light surfaces
    static let steel = Color(hex: 0x3F6070) // resting
    static let green = Color(hex: 0x52634B) // ready / complete
    static let mustard = Color(hex: 0xC48A28) // warning / substituted
    static let concrete = Color(hex: 0xA69D8D) // disabled, inactive
}

/// A person's identity colors (§4.2).
struct PersonStyle: Equatable {
    let accent: Color
    let onAccent: Color
    let text: Color
    let tint: Color
    let press: Color
}

extension PersonColor {
    var style: PersonStyle {
        let p = palette
        return PersonStyle(
            accent: Color(hex: p.accent), onAccent: Color(hex: p.onAccent), text: Color(hex: p.text),
            tint: Color(hex: p.tint), press: Color(hex: p.press)
        )
    }
}

extension Person {
    var style: PersonStyle { personColor.style }
}

extension RestPhase {
    /// Resting steel, ready green, overdue red (§14.2).
    var color: Color {
        switch self {
        case .resting: Palette.steel
        case .ready: Palette.green
        case .overdue: Palette.red
        }
    }

    /// Label color: red text on light surfaces uses the dark red for contrast.
    var labelColor: Color {
        if case .overdue = self { return Palette.redDark }
        return color
    }
}

/// Type scale (§5.3).
enum TypeScale {
    static let displayXL: CGFloat = 64
    static let display: CGFloat = 44
    static let section: CGFloat = 24
    static let title: CGFloat = 19
    static let body: CGFloat = 16
    static let label: CGFloat = 14
    static let meta: CGFloat = 12
}

/// The two families (§5): Roboto Condensed for display, labels and every
/// numeral; Inter for body text. Sizes scale with Dynamic Type.
enum Typeface {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("RobotoCondensed-ExtraBold", size: size, relativeTo: style)
    }

    static func condensed(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("RobotoCondensed-Bold", size: size, relativeTo: style)
    }

    enum Weight { case regular, medium, semibold, bold }

    static func body(_ size: CGFloat = TypeScale.body, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name = switch weight {
        case .regular: "Inter-Regular"
        case .medium: "Inter-Medium"
        case .semibold: "Inter-SemiBold"
        case .bold: "Inter-Bold"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
}

/// Clear borders instead of soft shadows (§7.2).
enum Stroke {
    static let width: CGFloat = 2
}

/// Mechanical, decisive motion (§21): ease-out, 120–180 ms, never springs.
enum Motion {
    static let fast = Animation.easeOut(duration: 0.12)
    static let standard = Animation.easeOut(duration: 0.16)
    static let slow = Animation.easeOut(duration: 0.18)
}

extension View {
    /// Uppercase, tracked meta label (§5.3 "Meta").
    func metaStyle(_ color: Color = Palette.textSecondary, size: CGFloat = TypeScale.meta) -> some View {
        font(Typeface.body(size, .semibold, relativeTo: .caption))
            .textCase(.uppercase)
            .tracking(size * 0.08)
            .foregroundStyle(color)
    }

    /// Poster-like condensed heading.
    func displayStyle(_ size: CGFloat, relativeTo style: Font.TextStyle = .title, uppercase: Bool = true) -> some View {
        font(Typeface.display(size, relativeTo: style))
            .textCase(uppercase ? .uppercase : nil)
            .tracking(-size * 0.01)
    }

    /// Condensed uppercase control label (buttons, chips).
    func labelStyle(_ size: CGFloat = 15) -> some View {
        font(Typeface.condensed(size, relativeTo: .headline))
            .textCase(.uppercase)
            .tracking(size * 0.04)
    }
}
