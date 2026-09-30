import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// What a person has entered but not logged yet.
struct InputValues: Equatable {
    var weight: Double?
    var reps: Double?
    var duration: Double?
    var note = ""

    init(_ values: SetValues? = nil) {
        weight = values?.weight
        reps = values?.reps.map(Double.init)
        duration = values?.duration.map(Double.init)
    }

    var setValues: SetValues {
        SetValues(weight: weight, reps: reps.map { Int($0) }, duration: duration.map { Int($0) }, note: note)
    }
}

private enum CardSheet: Identifiable {
    case notes, skip, substitute
    case edit(SetEntry)

    var id: String {
        switch self {
        case .notes: "notes"
        case .skip: "skip"
        case .substitute: "substitute"
        case .edit(let set): "edit-\(set.id)"
        }
    }
}

/// The core screen: one exercise, a row per person. The identity band sits on
/// alternate sides, so the composition reads as the phone being passed back
/// and forth (§13).
struct LoggingCardView: View {
    let cardId: String
    @Binding var path: [String]
    @Environment(AppModel.self) private var model
    @State private var inputs: [String: InputValues] = [:]
    @State private var sheet: CardSheet?
    @State private var logTick = 0
    @State private var undoTick = 0

    var body: some View {
        if let active = model.active, let card = active.card(cardId) {
            content(active: active, card: card)
        } else {
            Color.clear.paperBackground()
        }
    }

    private func content(active: ActiveSessionSnapshot, card: ActiveSessionSnapshot.Card) -> some View {
        let catalog = model.catalog
        let people = card.visiblePeople.compactMap { catalog.person($0.personId) }
        let isSingle = people.count <= 1
        let isTurns = card.exercise.loggingMode == .turns && !isSingle
        let exercise = catalog.exercise(card.exercise.exerciseId)

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise?.name ?? "Exercise").displayStyle(30, relativeTo: .largeTitle)
                    Rectangle().fill(Palette.rule).frame(height: 3)
                    if let category = exercise?.category, !category.isEmpty {
                        Text(category).metaStyle()
                    }
                }

                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    let isActive = isSingle || card.exercise.activePersonId == person.id
                    let leading = index == 0
                    if isTurns && !isActive {
                        WaitingRow(person: person, leading: leading, card: card, active: active, catalog: catalog)
                    } else {
                        ActiveRow(
                            person: person, leading: leading, isActive: isActive, isTurns: isTurns,
                            other: people.first { $0.id != person.id }, card: card, active: active, catalog: catalog,
                            inputs: binding(for: person, card: card, active: active),
                            edited: inputs[person.id] != nil,
                            onLog: { log(person, card: card, active: active, isTurns: isTurns, others: people) },
                            onRepeat: { repeatLast(person, card: card, active: active, isTurns: isTurns, others: people) },
                            onEdit: { sheet = .edit($0) },
                            onMove: { set, to in move(set, to: to) },
                            onDelete: { set in model.perform("DELETING THE SET") { try $0.deleteSet(id: set.id) } },
                            onActivate: {
                                model.perform("SWITCHING TURNS") { try $0.setActiveRow(sessionExerciseId: card.id, personId: person.id) }
                            }
                        )
                    }
                }

                HStack(spacing: 4) {
                    ActionButton(icon: .pencil, label: "Notes") { sheet = .notes }
                    ActionButton(icon: .skip, label: "Skip") { sheet = .skip }
                    ActionButton(icon: .swap, label: "Substitute") { sheet = .substitute }
                    variantMenu(card) { ActionLabel(icon: .mode, label: "Variant") }
                    if !isSingle {
                        modeMenu(card) { ActionLabel(icon: .mode, label: "Mode") }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                variantMenu(card) {
                    MenuPill(text: card.exercise.variant.label, highlighted: card.exercise.variant != .normal)
                }
                if isSingle {
                    Text("\(people.first?.name ?? "") only").metaStyle()
                } else {
                    modeMenu(card) { MenuPill(text: card.exercise.loggingMode.label) }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let snackbar = model.snackbar, snackbar.cardId == card.id {
                SnackbarView(
                    message: snackbar.message,
                    color: catalog.person(snackbar.personId)?.style.accent ?? Palette.ink,
                    onUndo: snackbar.undoSetId.map { id in { undo(id) } }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.standard, value: model.snackbar)
        .sensoryFeedback(.success, trigger: logTick)
        .sensoryFeedback(.impact(weight: .light), trigger: undoTick)
        .sensoryFeedback(.impact(weight: .medium), trigger: isSingle ? nil : card.exercise.activePersonId)
        .onChange(of: card.exercise.variant) { _, _ in inputs = [:] }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .notes:
                NotesSheet(people: people, initialPerson: activePersonID(card, people)) { personId, note in
                    inputs[personId, default: InputValues(active.defaultValues(cardId: card.id, personId: personId))].note = note
                } currentNote: { personId in inputs[personId]?.note ?? "" }
            case .skip:
                SkipSheet(card: card, people: people, initialPerson: activePersonID(card, people)) { skippedExercise in
                    if skippedExercise { path.removeAll { $0 == card.id } }
                }
            case .substitute:
                SubstituteSheet(card: card, people: people, initialPerson: activePersonID(card, people))
            case .edit(let set):
                if let person = catalog.person(set.personId) {
                    EditSetSheet(
                        set: set, ordinal: ordinal(of: set, in: active), person: person,
                        other: people.first { $0.id != set.personId },
                        exercise: catalog.exercise(set.exerciseId)
                    )
                }
            }
        }
    }

    // MARK: Inputs

    private func binding(for person: Person, card: ActiveSessionSnapshot.Card, active: ActiveSessionSnapshot) -> Binding<InputValues> {
        Binding(
            get: { inputs[person.id] ?? InputValues(active.defaultValues(cardId: card.id, personId: person.id)) },
            set: { inputs[person.id] = $0 }
        )
    }

    private func activePersonID(_ card: ActiveSessionSnapshot.Card, _ people: [Person]) -> String {
        card.exercise.activePersonId.flatMap { id in people.first { $0.id == id }?.id } ?? people.first?.id ?? ""
    }

    // MARK: Actions

    private func log(_ person: Person, card: ActiveSessionSnapshot.Card, active: ActiveSessionSnapshot, isTurns: Bool, others: [Person]) {
        let values = (inputs[person.id] ?? InputValues(active.defaultValues(cardId: card.id, personId: person.id)))
        var setId: String?
        guard model.perform("LOGGING THE SET", {
            setId = try $0.logSet(sessionExerciseId: card.id, personId: person.id, values: values.setValues)
        }) else { return }
        inputs[person.id] = nil // the next set re-derives its pre-fill
        logTick += 1
        confirm("Logged", person: person, values: values.setValues, card: card, setId: setId, isTurns: isTurns, others: others)
    }

    private func repeatLast(_ person: Person, card: ActiveSessionSnapshot.Card, active: ActiveSessionSnapshot, isTurns: Bool, others: [Person]) {
        // Repeat the set just done today (or the pre-fill before the first set).
        guard let repeated = active.repeatValues(cardId: card.id, personId: person.id) else { return }
        var setId: String?
        guard model.perform("REPEATING THE SET", {
            setId = try $0.logSet(sessionExerciseId: card.id, personId: person.id, values: repeated)
        }) else { return }
        inputs[person.id] = nil
        logTick += 1
        confirm("Repeated", person: person, values: repeated, card: card, setId: setId, isTurns: isTurns, others: others)
    }

    /// "Logged **Maria** · 80 kg × 8 — Alex's turn"
    private func confirm(_ verb: String, person: Person, values: SetValues, card: ActiveSessionSnapshot.Card,
                         setId: String?, isTurns: Bool, others: [Person]) {
        let exercise = model.catalog.exercise(card.exerciseId(for: person.id))
        let preview = SetEntry(id: "", sessionId: "", sessionExerciseId: nil, exerciseId: "", personId: person.id, setIndex: 0,
                               weight: values.weight, reps: values.reps, duration: values.duration)
        var message = AttributedString("\(verb) ")
        var name = AttributedString(person.name)
        name.font = Typeface.body(14, .bold)
        message += name
        message += AttributedString(" · \(Format.setSummary(preview, exercise: exercise, unit: person.unit))")
        if isTurns, let next = others.first(where: { $0.id != person.id }) {
            message += AttributedString(" — \(next.name)'s turn")
        }
        model.showSnackbar(SnackbarState(cardId: card.id, personId: person.id, message: message, undoSetId: setId))
    }

    private func undo(_ setId: String) {
        if model.perform("UNDOING THE SET", { try $0.undoSet(id: setId) }) {
            undoTick += 1
            model.dismissSnackbar()
        }
    }

    private func move(_ set: SetEntry, to person: Person) {
        model.perform("MOVING THE SET") { try $0.reassignSet(id: set.id, toPersonId: person.id) }
    }

    /// The set's position in its variant's ledger — never the stored index.
    private func ordinal(of set: SetEntry, in active: ActiveSessionSnapshot) -> Int {
        guard let cardId = set.sessionExerciseId else { return 1 }
        let sets = active.sets(cardId: cardId, personId: set.personId, variant: set.variant)
        return (sets.firstIndex { $0.id == set.id } ?? 0) + 1
    }

    // MARK: Menus

    private func variantMenu<Label: View>(_ card: ActiveSessionSnapshot.Card, @ViewBuilder label: () -> Label) -> some View {
        Menu {
            Picker("Variant", selection: Binding(
                get: { card.exercise.variant },
                set: { variant in model.perform("CHANGING THE VARIANT") { try $0.setVariant(sessionExerciseId: card.id, variant: variant) } }
            )) {
                ForEach(Variant.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        } label: { label() }
        .accessibilityLabel("Variant: \(card.exercise.variant.label)")
    }

    private func modeMenu<Label: View>(_ card: ActiveSessionSnapshot.Card, @ViewBuilder label: () -> Label) -> some View {
        Menu {
            Picker("Logging mode", selection: Binding(
                get: { card.exercise.loggingMode },
                set: { mode in model.perform("CHANGING THE MODE") { try $0.setLoggingMode(sessionExerciseId: card.id, mode: mode) } }
            )) {
                ForEach(LoggingMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
        } label: { label() }
        .accessibilityLabel("Logging mode: \(card.exercise.loggingMode.label)")
    }
}

@MainActor func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Rows

private struct ActiveRow: View {
    let person: Person
    let leading: Bool
    let isActive: Bool
    let isTurns: Bool
    let other: Person?
    let card: ActiveSessionSnapshot.Card
    let active: ActiveSessionSnapshot
    let catalog: CatalogSnapshot
    @Binding var inputs: InputValues
    /// The person changed the pre-filled values by hand.
    let edited: Bool
    let onLog: () -> Void
    let onRepeat: () -> Void
    let onEdit: (SetEntry) -> Void
    let onMove: (SetEntry, Person) -> Void
    let onDelete: (SetEntry) -> Void
    let onActivate: () -> Void

    var body: some View {
        let style = person.style
        let exerciseId = card.exerciseId(for: person.id)
        let exercise = catalog.exercise(exerciseId)
        let done = active.sets(cardId: card.id, personId: person.id, variant: card.exercise.variant)
        let last = active.lastTime(cardId: card.id, personId: person.id)
        let timer = active.timers[person.id].flatMap { $0.sessionExerciseId == card.id ? $0 : nil }
        let profile = catalog.profile(personId: person.id, exerciseId: exerciseId)
        let substituted = card.row(for: person.id)?.substituteExerciseId != nil
        let canRepeat = active.repeatValues(cardId: card.id, personId: person.id) != nil
        let prefill = edited ? nil : active.prefill(cardId: card.id, personId: person.id)
        let sourceRow: Int? = if case .lastTime(let index, _)? = prefill?.source { index } else { nil }

        HStack(spacing: 0) {
            if leading { IdentityBand(person: person, active: isActive, width: 32, leading: true) }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.name).displayStyle(22).foregroundStyle(style.text)
                        Text("Set \(Format.ordinal(done.count + 1))")
                            .font(Typeface.condensed(15))
                            .textCase(.uppercase)
                            .tracking(0.9)
                            .monospacedDigit()
                        if isActive && isTurns {
                            Tag(text: "Your turn", fill: style.accent, foreground: style.onAccent).padding(.top, 5)
                        }
                    }
                    Spacer()
                    RestControls(person: person, timer: timer, sessionId: active.session.id, exerciseId: exerciseId)
                }

                if substituted, let exercise {
                    Text("Doing \(exercise.name) instead today")
                        .metaStyle(Palette.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Palette.mustard)
                }
                if let profile, !(profile.machineSetup.isEmpty && profile.cues.isEmpty) {
                    Text([profile.machineSetup, profile.cues].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.textSecondary)
                }

                if !done.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(title: "This session") {
                            Text("\(done.count) \(done.count == 1 ? "set" : "sets") · tap to edit").metaStyle()
                        }
                        SetLedger(sets: done, exercise: exercise, unit: person.unit, accent: style.accent, onEdit: onEdit) { set in
                            Button("Edit", systemImage: "pencil") { onEdit(set) }
                            if let other { Button("Move to \(other.name)", systemImage: "arrow.left.arrow.right") { onMove(set, other) } }
                            Button("Delete set", systemImage: "trash", role: .destructive) { onDelete(set) }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(title: last.map { "Last time · \($0.label)" } ?? "No previous sets") {
                        if let last { Text("\(last.sets.count) \(last.sets.count == 1 ? "set" : "sets") · tap to fill").metaStyle() }
                    }
                    if let last {
                        SetLedger(sets: last.sets, exercise: exercise, unit: person.unit, accent: style.accent, muted: true,
                                  highlight: sourceRow, onSelect: { set in
                            inputs = { var v = InputValues(set.values); v.note = inputs.note; return v }()
                        })
                    }
                }

                if let prefill {
                    Text(Self.caption(prefill, unit: person.unit)).metaStyle(style.text, size: 10)
                }
                HStack(spacing: 10) {
                    if exercise?.tracksWeight ?? true {
                        ValueInput(label: person.unit.rawValue, value: $inputs.weight, step: 2.5, accent: style.accent, highlighted: isActive)
                    }
                    if exercise?.tracksReps ?? true {
                        ValueInput(label: "Reps", value: $inputs.reps, step: 1, integer: true, accent: style.accent, highlighted: isActive)
                    }
                    if exercise?.tracksDuration ?? false {
                        ValueInput(label: "Sec", value: $inputs.duration, step: 5, integer: true, accent: style.accent, highlighted: isActive)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: onLog) {
                        if isTurns, let other {
                            HStack(spacing: 6) {
                                Text("Log & pass to \(other.name)")
                                Icon(.arrowRight, size: 15)
                            }
                        } else {
                            Text("Log set · \(person.name)")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle.person(style))
                    Button(action: onRepeat) {
                        Icon(.repeat, size: 18)
                            .foregroundStyle(canRepeat ? Palette.ink : Palette.concrete)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Palette.canvas))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md)
                                .strokeBorder(canRepeat ? Palette.rule : Palette.concrete, lineWidth: Stroke.width))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRepeat)
                    .accessibilityLabel("Repeat last set")
                }
            }
            .padding(14)
            if !leading { IdentityBand(person: person, active: isActive, width: 32, leading: false) }
        }
        .background(Palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(isActive ? style.accent : Palette.ruleSoft, lineWidth: isActive ? Stroke.width : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { if !isActive { onActivate() } }
        .accessibilityAction(named: "Make it \(person.name)'s turn") { onActivate() }
    }
}

extension ActiveRow {
    /// "FROM LAST TIME · SET 02 +2.5 KG" / "REPEATING SET 04".
    static func caption(_ prefill: Prefill, unit: WeightUnit) -> String {
        switch prefill.source {
        case .lastTime(let index, let change):
            let carried = change.map { " \($0 > 0 ? "+" : "−")\(Format.trimNum(abs($0))) \(unit.rawValue)" } ?? ""
            return "From last time · set \(Format.ordinal(index + 1))" + carried
        case .today(let ordinal):
            return "Repeating set \(Format.ordinal(ordinal))"
        }
    }
}

/// Turns mode: the person resting gets a compact row with their live timer.
private struct WaitingRow: View {
    let person: Person
    let leading: Bool
    let card: ActiveSessionSnapshot.Card
    let active: ActiveSessionSnapshot
    let catalog: CatalogSnapshot

    var body: some View {
        let done = active.sets(cardId: card.id, personId: person.id, variant: card.exercise.variant)
        let timer = active.timers[person.id].flatMap { $0.sessionExerciseId == card.id ? $0 : nil }
        let exercise = catalog.exercise(card.exerciseId(for: person.id))
        HStack(spacing: 0) {
            if leading { IdentityBand(person: person, active: false, width: 28, leading: true) }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name).displayStyle(18).foregroundStyle(person.style.text)
                    Text("Set \(Format.ordinal(done.count + 1)) · up next")
                        .font(Typeface.condensed(14))
                        .textCase(.uppercase)
                        .monospacedDigit()
                    Text(done.last.map { "Just logged \(Format.setSummary($0, exercise: exercise, unit: person.unit))" } ?? "Waiting for their turn")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    TimerRing(phase: timer?.phase(now: context.date.epochMilliseconds), total: timer?.durationSeconds ?? 0, size: 62, stroke: 5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if !leading { IdentityBand(person: person, active: false, width: 28, leading: false) }
        }
        .background(Palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.ruleSoft, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// The rest ring with its controls: +30s, skip rest, default rest.
private struct RestControls: View {
    let person: Person
    let timer: RestTimer?
    let sessionId: String
    let exerciseId: String
    @Environment(AppModel.self) private var model
    @State private var editingRest = false

    var body: some View {
        Menu {
            if timer != nil {
                Button("+30 seconds", systemImage: "plus") {
                    model.perform("ADDING REST") { try $0.adjustRest(sessionId: sessionId, personId: person.id, by: 30) }
                }
                Button("Skip rest", systemImage: "forward.end") {
                    model.perform("SKIPPING REST") { try $0.skipRest(sessionId: sessionId, personId: person.id) }
                }
            }
            Button("Set default rest…", systemImage: "timer") { editingRest = true }
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                TimerRing(phase: timer?.phase(now: context.date.epochMilliseconds), total: timer?.durationSeconds ?? 0, size: 74)
            }
        } primaryAction: {
            if timer != nil {
                model.perform("ADDING REST") { try $0.adjustRest(sessionId: sessionId, personId: person.id, by: 30) }
            } else {
                editingRest = true
            }
        }
        .accessibilityHint("Tap to add 30 seconds; hold for more")
        .sheet(isPresented: $editingRest) {
            RestLengthSheet(person: person, exerciseId: exerciseId)
        }
    }
}

private struct MenuPill: View {
    let text: String
    var highlighted = false

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
            Icon(.chevronDown, size: 9)
        }
        .labelStyle(13)
        .foregroundStyle(highlighted ? Palette.redDark : Palette.ink)
    }
}

private struct ActionButton: View {
    let icon: IconName
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { ActionLabel(icon: icon, label: label) }
            .buttonStyle(.plain)
    }
}

private struct ActionLabel: View {
    let icon: IconName
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Icon(icon, size: 15)
            Text(label).metaStyle(Palette.ink, size: 10)
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
    }
}
