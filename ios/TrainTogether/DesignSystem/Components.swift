import SwiftUI
import TrainTogetherCore

// Reusable pieces of the visual system, ported from frontend/src/components.

// MARK: - Buttons (§10)

/// The dominant next action: a solid block, red or the person's color.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Palette.red
    var pressed: Color = Palette.redDark
    var foreground: Color = Palette.onAccent
    var height: CGFloat = 52
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(17)
            .foregroundStyle(isEnabled ? foreground : Palette.canvas)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(!isEnabled ? Palette.concrete : configuration.isPressed ? pressed : fill)
            )
            .contentShape(Rectangle())
    }
}

extension PrimaryButtonStyle {
    static func person(_ style: PersonStyle) -> PrimaryButtonStyle {
        PrimaryButtonStyle(fill: style.accent, pressed: style.press, foreground: style.onAccent)
    }
}

/// Secondary: Canvas block with a 2px Ink border.
struct GhostButtonStyle: ButtonStyle {
    var height: CGFloat = 48
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(15)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(configuration.isPressed ? Palette.paper : Palette.canvas)
            )
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.ink, lineWidth: Stroke.width))
            .contentShape(Rectangle())
    }
}

/// Destructive, with explicit wording (§10.4): outlined, not a solid red block.
struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(15)
            .foregroundStyle(configuration.isPressed ? Palette.onAccent : Palette.redDark)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(configuration.isPressed ? Palette.red : Palette.canvas)
            )
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.red, lineWidth: Stroke.width))
            .contentShape(Rectangle())
    }
}

// MARK: - People

/// Square initial block in the person's color. Square, not round: circles are
/// reserved for timers (§3). The initial means identity never relies on color.
struct Avatar: View {
    let person: Person?
    var size: CGFloat = 28

    var body: some View {
        let style = person?.style ?? PersonColor.concrete.style
        Text(person?.initials.isEmpty == false ? person!.initials : String(person?.name.prefix(1) ?? "?"))
            .font(Typeface.display(size * 0.52, relativeTo: .caption))
            .foregroundStyle(style.onAccent)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(style.accent))
            .accessibilityLabel(person?.name ?? "")
    }
}

/// Two identity blocks butted together — RED | STEEL, never blended (§4.2).
struct PersonPair: View {
    let people: [Person]
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: Stroke.width) {
            ForEach(people) { Avatar(person: $0, size: size) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(people.map(\.name).joined(separator: " and "))
    }
}

/// The vertical identity band (§13): the person's color running the full
/// height of their row, with their name set into it. It wipes in when the turn
/// moves to this person.
struct IdentityBand: View {
    let person: Person
    var active: Bool
    var width: CGFloat = 30
    var leading = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let style = person.style
        ZStack {
            Rectangle().fill(style.tint)
            Rectangle()
                .fill(style.accent)
                .scaleEffect(x: 1, y: active ? 1 : 0, anchor: leading ? .top : .bottom)
            GeometryReader { geo in
                Text(person.name.uppercased())
                    .font(Typeface.display(width * 0.52, relativeTo: .caption))
                    .tracking(width * 0.03)
                    .lineLimit(1)
                    .foregroundStyle(active ? style.onAccent : style.text)
                    .frame(width: max(0, geo.size.height - 20))
                    .rotationEffect(.degrees(-90))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .frame(width: width)
        .clipped()
        .animation(reduceMotion ? nil : Motion.slow, value: active)
        .accessibilityHidden(true)
    }
}

// MARK: - Rest timer (§14)

/// Thick ring, dashed track, clear central time and a state word — timer
/// state never depends on color alone.
struct TimerRing: View {
    let phase: RestPhase?
    /// Full rest duration, for the remaining arc.
    let total: Int
    var size: CGFloat = 88
    var stroke: CGFloat = 7

    var body: some View {
        let phase = phase ?? .ready
        let remaining: Double = if case .resting(let r) = phase { r } else { 0 }
        let progress = total > 0 ? min(1, remaining / Double(total)) : 0
        ZStack {
            Circle()
                .inset(by: stroke / 2)
                .stroke(Palette.concrete, style: StrokeStyle(lineWidth: stroke, dash: [2, 7]))
            if progress > 0 {
                Circle()
                    .inset(by: stroke / 2)
                    .trim(from: 0, to: progress)
                    .stroke(phase.color, style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            } else {
                // Rest complete reads as a closed band — a structural change,
                // not just a hue.
                Circle().inset(by: stroke / 2).stroke(phase.color, lineWidth: stroke)
            }
            VStack(spacing: 1) {
                Text(Format.clock(phase.clockSeconds))
                    .font(Typeface.display(size * 0.26, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(phase.label.uppercased())
                    .font(Typeface.body(max(9, size * 0.1), .bold, relativeTo: .caption2))
                    .tracking(size * 0.008)
                    .foregroundStyle(phase.labelColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phase.label) \(Format.clock(phase.clockSeconds))")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Sets (§15)

/// Sets as a numbered ledger: prominent ordinal, a rule to the values.
/// `01 ──── 60 KG × 10 ✓`. Two columns unless the values are too long.
struct SetLedger<Menu: View>: View {
    let sets: [SetEntry]
    let exercise: Exercise?
    let unit: WeightUnit
    var accent: Color = Palette.ink
    var muted = false
    /// A row to point out (0-based), e.g. the set the next inputs came from.
    var highlight: Int?
    var onEdit: ((SetEntry) -> Void)?
    var onSelect: ((SetEntry) -> Void)?
    @ViewBuilder var menu: (SetEntry) -> Menu

    var body: some View {
        let rows = sets.enumerated().map { (index: $0.offset, set: $0.element, text: rowText($0.element)) }
        // Pair rows only when the longest value fits half the width.
        let columns = (rows.map(\.text.count).max() ?? 0) > 11 ? 1 : 2
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 0) {
            ForEach(rows, id: \.set.id) { row in
                let highlighted = row.index == highlight
                SetLedgerRow(
                    ordinal: row.index + 1, text: row.text, hasNote: row.set.note != nil,
                    accent: muted && !highlighted ? Palette.textSecondary : accent, muted: muted && !highlighted,
                    highlighted: highlighted,
                    editable: onEdit != nil, fillOption: onSelect != nil && onEdit == nil,
                    divider: row.index >= columns
                ) {
                    if let onEdit { onEdit(row.set) } else { onSelect?(row.set) }
                }
                .contextMenu { menu(row.set) }
            }
        }
    }

    private func rowText(_ set: SetEntry) -> String {
        let text = Format.setSummary(set, exercise: exercise, unit: unit)
        return text.isEmpty ? "—" : text.uppercased()
    }
}

extension SetLedger where Menu == EmptyView {
    init(sets: [SetEntry], exercise: Exercise?, unit: WeightUnit, accent: Color = Palette.ink, muted: Bool = false,
         highlight: Int? = nil, onEdit: ((SetEntry) -> Void)? = nil, onSelect: ((SetEntry) -> Void)? = nil) {
        self.init(sets: sets, exercise: exercise, unit: unit, accent: accent, muted: muted, highlight: highlight,
                  onEdit: onEdit, onSelect: onSelect, menu: { _ in EmptyView() })
    }
}

private struct SetLedgerRow: View {
    let ordinal: Int
    let text: String
    let hasNote: Bool
    let accent: Color
    let muted: Bool
    var highlighted = false
    let editable: Bool
    let fillOption: Bool
    let divider: Bool
    let action: () -> Void

    var body: some View {
        let content = HStack(spacing: 7) {
            if highlighted { Icon(.arrowRight, size: 9).foregroundStyle(accent) }
            Text(Format.ordinal(ordinal))
                .font(Typeface.display(fillOption ? 15 : 14, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(accent)
                .frame(minWidth: 18, alignment: .leading)
            Rectangle()
                .fill(muted ? Palette.ruleSoft : Palette.rule)
                .opacity(muted ? 0.6 : 0.75)
                .frame(minWidth: 6, maxWidth: .infinity)
                .frame(height: 1)
            if hasNote { Icon(.pencil, size: 9).foregroundStyle(Palette.textSecondary) }
            // The values win over the rule: the rule shrinks, numbers never truncate.
            Text(text)
                .font(Typeface.condensed(fillOption ? 15 : 14, relativeTo: .footnote))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
                .foregroundStyle(muted ? Palette.textSecondary : Palette.ink)
            if editable { Icon(.check, size: 9).foregroundStyle(accent) }
        }
        .frame(minHeight: fillOption ? 44 : 30)
        .overlay(alignment: .top) {
            if divider { Rectangle().fill(Palette.ruleSoft).frame(height: 1) }
        }
        .contentShape(Rectangle())

        if editable || fillOption {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityLabel("\(editable ? "Edit" : "Use") set \(ordinal): \(text)")
        } else {
            content.accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Inputs (§11)

/// A big numeric well styled as an equipment label: uppercase label, Canvas
/// well with a 2px border (the person's color when focused), −/+ blocks.
struct ValueInput: View {
    let label: String
    @Binding var value: Double?
    var step: Double = 1
    var integer = false
    var accent: Color = Palette.ink
    var highlighted = false
    @FocusState private var focused: Bool
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).metaStyle(size: 11)
            VStack(spacing: 7) {
                TextField("", text: $text)
                    .font(Typeface.display(30, relativeTo: .title))
                    .monospacedDigit()
                    .keyboardType(integer ? .numberPad : .decimalPad)
                    .focused($focused)
                    .foregroundStyle(Palette.ink)
                    .onChange(of: text) { _, new in
                        let cleaned = new.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
                        if cleaned != new { text = cleaned; return }
                        let parsed = cleaned.isEmpty ? nil : Double(cleaned)
                        if parsed != value { value = parsed.map { integer ? $0.rounded() : $0 } }
                    }
                    .accessibilityLabel(label)
                HStack(spacing: 6) {
                    stepButton("−", "Decrease \(label)") { bump(-1) }
                    stepButton("+", "Increase \(label)") { bump(1) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Palette.canvas))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .strokeBorder(focused || highlighted ? accent : Palette.rule, lineWidth: Stroke.width)
            )
        }
        .onAppear { text = format(value) }
        .onChange(of: value) { _, new in
            if Double(text) != new { text = format(new) }
        }
    }

    private func stepButton(_ symbol: String, _ a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(Typeface.condensed(18))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(RoundedRectangle(cornerRadius: Radius.sm - 2).fill(Palette.paper))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm - 2).strokeBorder(Palette.rule, lineWidth: Stroke.width))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }

    private func bump(_ direction: Double) {
        let next = max(0, ((value ?? 0) + direction * step) * 100).rounded() / 100
        value = next
        text = format(next)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return integer ? String(Int(value)) : Format.trimNum(value)
    }
}

/// Flat bordered segmented control — no pills, no sliding thumb (§11).
struct Segmented<Value: Hashable>: View {
    enum Variant { case track, cards }
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var variant: Variant = .track

    var body: some View {
        switch variant {
        case .cards:
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { option in
                    let selected = option.value == selection
                    Button { selection = option.value } label: {
                        Text(option.label)
                            .labelStyle(15)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(selected ? Palette.onDark : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: Radius.md).fill(selected ? Palette.ink : Palette.canvas))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.rule, lineWidth: Stroke.width))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        case .track:
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.value) { index, option in
                    let selected = option.value == selection
                    Button { selection = option.value } label: {
                        Text(option.label)
                            .labelStyle(14)
                            .foregroundStyle(selected ? Palette.onDark : Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(selected ? Palette.ink : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .leading) {
                        if index > 0 { Rectangle().fill(Palette.rule).frame(width: Stroke.width) }
                    }
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .background(Palette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.rule, lineWidth: Stroke.width))
        }
    }
}

// MARK: - Structure

/// Uppercase section header over a bold rule (§3, §12).
struct SectionLabel<Trailing: View>: View {
    let title: String
    var dark = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                Text(title).metaStyle(dark ? Palette.onDarkMuted : Palette.textSecondary)
                Spacer(minLength: 12)
                trailing()
            }
            Rectangle().fill(dark ? Palette.onDarkMuted : Palette.rule).frame(height: Stroke.width)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(_ title: String, dark: Bool = false) {
        self.init(title: title, dark: dark, trailing: { EmptyView() })
    }
}

/// A number and what it counts (§24).
struct StatBlock: View {
    enum Tone { case light, dark, accent }
    let value: String
    let label: String
    var size: CGFloat = 30
    var tone: Tone = .light
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(value)
                .font(Typeface.display(size, relativeTo: .title))
                .monospacedDigit()
                .tracking(-size * 0.01)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(tone == .dark ? Palette.onDark : tone == .accent ? Palette.redDark : Palette.ink)
            Text(label).metaStyle(tone == .dark ? Palette.onDarkMuted : Palette.textSecondary, size: 11)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .accessibilityElement(children: .combine)
    }
}

/// A small bordered label: header pills, tags.
struct Chip: View {
    let text: String
    var tint: Color = Palette.ink
    var filled = false

    var body: some View {
        Text(text)
            .labelStyle(13)
            .foregroundStyle(filled ? Palette.onAccent : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(filled ? tint : Palette.canvas))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(tint, lineWidth: Stroke.width))
    }
}

/// A square filled status tag ("YOUR TURN", "SUBSTITUTED").
struct Tag: View {
    let text: String
    var fill: Color
    var foreground: Color = Palette.onAccent

    var body: some View {
        Text(text)
            .font(Typeface.condensed(12, relativeTo: .caption))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(fill)
    }
}

/// Ink square holding an icon, for link rows.
struct IconTile: View {
    let icon: IconName

    var body: some View {
        Icon(icon, size: 13)
            .foregroundStyle(Palette.paper)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.ink))
    }
}

/// An exercise in a list: its pictogram tile, name and a line of detail.
struct ExerciseRowLabel: View {
    let icon: ExerciseIcon
    let name: String
    var detail = ""

    var body: some View {
        HStack(spacing: 12) {
            ExerciseTile(icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(Typeface.condensed(17)).textCase(.uppercase)
                if !detail.isEmpty {
                    Text(detail).font(Typeface.body(13)).foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

extension ExerciseRowLabel {
    /// A library exercise, detailed by category and what it tracks.
    init(_ exercise: Exercise) {
        self.init(
            icon: exercise.resolvedIcon, name: exercise.name,
            detail: [exercise.category, exercise.tracksSummary].filter { !$0.isEmpty }.joined(separator: " · ")
        )
    }

    /// A popular exercise, detailed by equipment and what it tracks.
    init(_ entry: PopularExercise) {
        self.init(
            icon: entry.icon, name: entry.name,
            detail: [entry.equipment, entry.exercise.tracksSummary].filter { !$0.isEmpty }.joined(separator: " · ")
        )
    }
}

/// Muscle-group chips (All, Chest, Back, …) for filtering exercise lists.
struct MuscleGroupFilter: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip("All", nil)
                ForEach(MuscleGroup.allCases, id: \.self) { chip($0.label, $0) }
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ label: String, _ group: MuscleGroup?) -> some View {
        let selected = selection == group
        return Button { selection = group } label: { Chip(text: label, filled: selected) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The heavy rule under a screen title.
struct TitleRule: View {
    var height: CGFloat = 4
    var body: some View { Rectangle().fill(Palette.rule).frame(height: height) }
}

/// A flat card: Canvas block, 2px Ink border (§12).
struct CardBackground: ViewModifier {
    var radius: CGFloat = Radius.md
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(Palette.canvas))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Palette.rule, lineWidth: Stroke.width))
    }
}

extension View {
    func card(radius: CGFloat = Radius.md) -> some View { modifier(CardBackground(radius: radius)) }

    /// The warm paper background behind a screen.
    func paperBackground() -> some View {
        background(Palette.paper.ignoresSafeArea())
    }

    /// For screens whose big title is part of the scrolling content: a hard
    /// edge under the bars, so display type scrolled up doesn't show through
    /// behind the clock and the toolbar buttons.
    func solidTopEdge() -> some View {
        scrollEdgeEffectStyle(.hard, for: .top)
    }
}

// MARK: - Texture (§18)

/// Subtle warm paper grain at 3.5% — only on brand surfaces and empty states.
struct Grain: View {
    var opacity: Double = 0.035

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(1 << 31)
            }
            let count = Int(size.width * size.height / 18)
            for _ in 0..<count {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1.2, height: 1.2)
                context.fill(Path(rect), with: .color(next() > 0.5 ? .black : .white))
            }
        }
        .opacity(opacity * 4)
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

// MARK: - Feedback

/// Post-log confirmation on Ink with the acting person's color (6 s, UNDO).
struct SnackbarView: View {
    let message: AttributedString
    let color: Color
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(Typeface.body(14, relativeTo: .subheadline))
                .foregroundStyle(Palette.onDark)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onUndo {
                Button("Undo", action: onUndo)
                    .labelStyle(15)
                    .foregroundStyle(Palette.onDark)
                    .padding(.bottom, 2)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.red).frame(height: 2) }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Palette.ink)
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 6) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .accessibilityElement(children: .combine)
    }
}

/// A failed action, pinned to the top; stays until dismissed (§28).
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(Palette.red).frame(width: 5)
            Text(message)
                .font(Typeface.condensed(15, relativeTo: .subheadline))
                .textCase(.uppercase)
                .foregroundStyle(Palette.onDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            Button("Dismiss", action: onDismiss)
                .labelStyle(13)
                .foregroundStyle(Palette.onDarkMuted)
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                .padding(.trailing, 12)
        }
        .background(Palette.ink)
        .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(Palette.red, lineWidth: Stroke.width))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// An empty state with a little more graphic weight (§27).
struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).displayStyle(26)
            Text(message)
                .font(Typeface.body(15))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.canvas)
        .overlay(Grain())
        .overlay(alignment: .leading) { Rectangle().fill(Palette.ink).frame(width: 4) }
        .overlay(Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: 1))
    }
}
