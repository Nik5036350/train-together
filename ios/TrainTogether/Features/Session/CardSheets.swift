import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Shared chrome for the small sheets: paper, a condensed title over a rule.
private struct SheetScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).displayStyle(26)
                    TitleRule(height: Stroke.width)
                }
                content()
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationBackground(Palette.paper)
        .presentationCornerRadius(Radius.lg)
    }
}

/// Picks which person an action is for (only shown with two people).
private struct PersonPicker: View {
    let people: [Person]
    @Binding var selection: String

    var body: some View {
        if people.count > 1 {
            Segmented(options: people.map { ($0.id, $0.name) }, selection: $selection, variant: .cards)
        }
    }
}

struct NotesSheet: View {
    let people: [Person]
    let initialPerson: String
    let onSave: (String, String) -> Void
    let currentNote: (String) -> String
    @Environment(\.dismiss) private var dismiss
    @State private var personId = ""
    @State private var note = ""

    var body: some View {
        SheetScaffold(title: "Note for next set") {
            PersonPicker(people: people, selection: $personId)
            TextField("e.g. belt on, paused reps", text: $note, axis: .vertical)
                .font(Typeface.body(16))
                .lineLimit(3...6)
                .padding(12)
                .card(radius: Radius.sm)
            Button("Save note") {
                onSave(personId, note)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .presentationDetents([.medium])
        .onAppear {
            personId = initialPerson
            note = currentNote(initialPerson)
        }
        .onChange(of: personId) { _, id in note = currentNote(id) }
    }
}

struct SkipSheet: View {
    let card: ActiveSessionSnapshot.Card
    let people: [Person]
    let initialPerson: String
    /// Called with true when the whole exercise was skipped.
    let onDone: (Bool) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var personId = ""
    @State private var reason = ""

    var body: some View {
        let name = people.first { $0.id == personId }?.name ?? ""
        SheetScaffold(title: "Skip") {
            PersonPicker(people: people, selection: $personId)
            if people.count > 1 {
                Button("Skip \(name)'s turn") {
                    model.perform("SKIPPING THE TURN") { try $0.skipTurn(sessionExerciseId: card.id, personId: personId) }
                    dismiss()
                    onDone(false)
                }
                .buttonStyle(GhostButtonStyle())
            }
            SectionLabel("Skip the exercise")
            TextField("Reason (optional)", text: $reason)
                .font(Typeface.body(16))
                .padding(12)
                .card(radius: Radius.sm)
            Button("Skip exercise for \(name)") {
                let ok = model.perform("SKIPPING THE EXERCISE") {
                    try $0.skipExercise(sessionExerciseId: card.id, personId: personId, reason: reason)
                }
                dismiss()
                if ok { onDone(people.count <= 1) }
            }
            .buttonStyle(DangerButtonStyle())
        }
        .presentationDetents([.medium, .large])
        .onAppear { personId = initialPerson }
    }
}

struct SubstituteSheet: View {
    let card: ActiveSessionSnapshot.Card
    let people: [Person]
    let initialPerson: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var personId = ""
    @State private var query = ""

    var body: some View {
        let current = card.row(for: personId)?.substituteExerciseId
        let exercises = model.catalog.exercises.filter {
            $0.id != card.exercise.exerciseId && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
        // Popular exercises only once searching, so the list stays short.
        let popular = query.isEmpty ? [] : PopularExercises.missing(from: model.catalog.exercises).filter { entry in
            ([entry.name] + entry.aliases).contains { $0.localizedCaseInsensitiveContains(query) }
        }
        SheetScaffold(title: "Substitute") {
            PersonPicker(people: people, selection: $personId)
            if current != nil {
                Button("Back to \(model.catalog.exercise(card.exercise.exerciseId)?.name ?? "the plan")") { pick(nil) }
                    .buttonStyle(GhostButtonStyle())
            }
            TextField("Search exercises", text: $query)
                .font(Typeface.body(16))
                .padding(12)
                .card(radius: Radius.sm)
            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    Button { pick(exercise.id) } label: {
                        row(exercise.resolvedIcon, exercise.name, checked: exercise.id == current)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.ruleSoft).frame(height: 1) }
                }
            }
            if !popular.isEmpty {
                SectionLabel("Popular")
                VStack(spacing: 0) {
                    ForEach(popular) { entry in
                        Button { pickPopular(entry) } label: { row(entry.icon, entry.name, checked: false) }
                            .buttonStyle(.plain)
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ruleSoft).frame(height: 1) }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { personId = initialPerson }
    }

    private func row(_ icon: ExerciseIcon, _ name: String, checked: Bool) -> some View {
        HStack(spacing: 12) {
            ExerciseTile(icon, size: 30)
            Text(name).font(Typeface.condensed(17)).textCase(.uppercase)
            Spacer()
            if checked { Icon(.check, size: 12) }
        }
        .foregroundStyle(Palette.ink)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func pick(_ exerciseId: String?) {
        model.perform("SUBSTITUTING") {
            try $0.substituteExercise(sessionExerciseId: card.id, personId: personId, substituteExerciseId: exerciseId)
        }
        dismiss()
    }

    /// Adds the popular exercise to the library, then substitutes it.
    private func pickPopular(_ entry: PopularExercise) {
        var id: String?
        guard model.perform("ADDING THE EXERCISE", { id = try $0.addPopularExercise(id: entry.id) }), let id else { return }
        pick(id)
    }
}

/// Correct a logged set: values, the person it belongs to, or delete it.
/// Works for the live workout and for history.
struct EditSetSheet: View {
    let set: SetEntry
    let ordinal: Int
    let person: Person
    let other: Person?
    let exercise: Exercise?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var values = InputValues()
    @State private var confirmDelete = false
    @State private var deleteTick = 0

    var body: some View {
        SheetScaffold(title: "Edit set") {
            HStack(spacing: 10) {
                Avatar(person: person, size: 30)
                Text(person.name).displayStyle(20).foregroundStyle(person.style.text)
                Spacer()
                Text("Set \(Format.ordinal(ordinal))").font(Typeface.condensed(16)).textCase(.uppercase).monospacedDigit()
            }
            HStack(spacing: 10) {
                if exercise?.tracksWeight ?? true {
                    ValueInput(label: person.unit.rawValue, value: $values.weight, step: 2.5, accent: person.style.accent)
                }
                if exercise?.tracksReps ?? true {
                    ValueInput(label: "Reps", value: $values.reps, step: 1, integer: true, accent: person.style.accent)
                }
                if exercise?.tracksDuration ?? (set.duration != nil) {
                    ValueInput(label: "Sec", value: $values.duration, step: 5, integer: true, accent: person.style.accent)
                }
            }
            TextField("Note", text: $values.note, axis: .vertical)
                .font(Typeface.body(16))
                .lineLimit(1...4)
                .padding(12)
                .card(radius: Radius.sm)
            Button("Save changes") {
                if model.perform("SAVING THE SET", { try $0.editSet(id: set.id, values: values.setValues) }) { dismiss() }
            }
            .buttonStyle(PrimaryButtonStyle())
            if let other {
                Button {
                    if model.perform("MOVING THE SET", { try $0.reassignSet(id: set.id, toPersonId: other.id) }) { dismiss() }
                } label: {
                    HStack(spacing: 8) {
                        Icon(.swap, size: 15)
                        Text("Move to \(other.name)")
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            Button("Delete set") { confirmDelete = true }
                .buttonStyle(DangerButtonStyle())
        }
        .presentationDetents([.large]) // at half height the delete button was cut off
        .sensoryFeedback(.warning, trigger: deleteTick)
        .onAppear {
            values = InputValues(set.values)
            values.note = set.note ?? ""
        }
        .confirmationDialog("Delete this set?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete set", role: .destructive) {
                deleteTick += 1
                if model.perform("DELETING THE SET", { try $0.deleteSet(id: set.id) }) { dismiss() }
            }
        }
    }
}

/// "Set default rest…": this person's rest for this exercise.
struct RestLengthSheet: View {
    let person: Person
    let exerciseId: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var seconds = 90

    var body: some View {
        let exercise = model.catalog.exercise(exerciseId)
        SheetScaffold(title: "Rest for \(person.name)") {
            Text(exercise?.name ?? "").metaStyle()
            HStack {
                Text(Format.duration(seconds)).font(Typeface.display(44)).monospacedDigit()
                Spacer()
                Stepper("Rest", value: $seconds, in: 0...900, step: 15).labelsHidden()
            }
            Text("Used from the next set on. The exercise default is \(Format.duration(exercise?.defaultRestSeconds ?? Exercise.defaultRestSeconds)).")
                .font(Typeface.body(14))
                .foregroundStyle(Palette.textSecondary)
            Button("Save rest") {
                if model.perform("SAVING REST", { try $0.setProfileRest(personId: person.id, exerciseId: exerciseId, restSeconds: seconds) }) {
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Use exercise default") {
                if model.perform("SAVING REST", { try $0.setProfileRest(personId: person.id, exerciseId: exerciseId, restSeconds: nil) }) {
                    dismiss()
                }
            }
            .buttonStyle(GhostButtonStyle())
        }
        .presentationDetents([.medium])
        .onAppear {
            seconds = model.catalog.profile(personId: person.id, exerciseId: exerciseId)?.restSeconds
                ?? exercise?.defaultRestSeconds ?? Exercise.defaultRestSeconds
        }
    }
}
