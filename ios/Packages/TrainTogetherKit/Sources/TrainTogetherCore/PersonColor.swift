// The participants' identity colors (styleguide §4.2), ported from
// frontend/src/theme.js PERSON_COLORS. Revolution Red and Steel Blue are the
// primary pairing — equal but distinct, never blended.
//
// Colors are 0xRRGGBB values so this module stays UI-framework free; the app's
// design system turns them into SwiftUI colors.

public enum PersonColor: String, CaseIterable, Sendable {
    case red, steel, mustard, green, concrete

    /// Resolves any stored key, including the pre-redesign keys still present in
    /// old data ("blue", "orange", …). Unknown keys fall back to steel, like
    /// the web client's `resolveColorKey`.
    public init(key: String) {
        if let color = PersonColor(rawValue: key) {
            self = color
            return
        }
        switch key {
        case "orange", "pink": self = .red
        default: self = .steel
        }
    }

    public struct Palette: Hashable, Sendable {
        /// Fills identity blocks.
        public let accent: UInt32
        /// Text drawn on `accent`.
        public let onAccent: UInt32
        /// Darkened variant that stays readable on `tint`.
        public let text: UInt32
        /// A wash for secondary surfaces.
        public let tint: UInt32
        /// Pressed fill.
        public let press: UInt32
    }

    public var palette: Palette {
        switch self {
        case .red:
            Palette(accent: 0xC92C1C, onAccent: 0xFAF5EA, text: 0x8F1E16, tint: 0xF4DFDA, press: 0x8F1E16)
        case .steel:
            Palette(accent: 0x3F6070, onAccent: 0xFAF5EA, text: 0x2F4855, tint: 0xDFE6E9, press: 0x2F4855)
        case .mustard:
            Palette(accent: 0xC48A28, onAccent: 0x181816, text: 0x7A5514, tint: 0xF6EAD3, press: 0x9A6C1B)
        case .green:
            Palette(accent: 0x52634B, onAccent: 0xFAF5EA, text: 0x3B4837, tint: 0xE4E9E1, press: 0x3B4837)
        case .concrete:
            Palette(accent: 0xA69D8D, onAccent: 0x181816, text: 0x5E574C, tint: 0xEDE8DF, press: 0x8A8272)
        }
    }

    public var label: String { rawValue.capitalized }
}
