import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

struct ExerciseLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var deleting: Exercise?

    var body: some View {
        let catalog = model.catalog
        let exercises = catalog.exercises.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        List {
            ForEach(exercises) { exercise in
                NavigationLink(value: SettingsRoute.exercise(exercise.id)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name).font(Typeface.condensed(17)).textCase(.uppercase)
                        Text([exercise.category, exercise.tracksSummary].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Typeface.body(13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .listRowBackground(Palette.canvas)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = exercise }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .searchable(text: $query)
        .navigationTitle("EXERCISES")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink(value: SettingsRoute.exercise(nil)) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("New exercise")
        }
        .modifier(DeleteExerciseDialog(exercise: $deleting))
    }
}

/// Confirms deleting an exercise, naming the routines that lose it.
struct DeleteExerciseDialog: ViewModifier {
    @Binding var exercise: Exercise?
    var onDeleted: () -> Void = {}
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete \(exercise?.name ?? "exercise")?",
            isPresented: Binding(get: { exercise != nil }, set: { if !$0 { exercise = nil } }),
            titleVisibility: .visible, presenting: exercise
        ) { exercise in
            Button("Delete exercise", role: .destructive) {
                if model.perform("DELETING THE EXERCISE", { try $0.deleteExercise(id: exercise.id) }) { onDeleted() }
            }
        } message: { exercise in
            let routines = model.catalog.templates.filter { $0.exercises.contains { $0.exerciseId == exercise.id } }
            if routines.isEmpty {
                Text("Past logged sets stay in history.")
            } else {
                Text("It'll be removed from \(routines.map(\.template.name).joined(separator: ", ")) too. Past logged sets stay in history.")
            }
        }
    }
}

/// Everything about an exercise, including each person's own rest, machine
/// setup and cues.
struct ExerciseEditorView: View {
    let exerciseId: String?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ExerciseDraft(name: "")
    @State private var loaded = false
    @State private var deleting: Exercise?

    var body: some View {
        let people = model.catalog.pair
        Form {
            Section {
                TextField("Name", text: $draft.name).font(Typeface.condensed(20))
                TextField("Category (e.g. Chest)", text: $draft.category)
                TextField("Equipment (e.g. Barbell)", text: $draft.equipment)
            }
            Section {
                Toggle("Weight", isOn: $draft.tracksWeight)
                Toggle("Reps", isOn: $draft.tracksReps)
                Toggle("Duration", isOn: $draft.tracksDuration)
            } header: {
                Text("Tracks")
            } footer: {
                Text("At least one.")
            }
            Section("Rest") {
                Stepper(value: $draft.defaultRestSeconds, in: 0...900, step: 15) {
                    LabeledContent("Default rest", value: Format.duration(draft.defaultRestSeconds))
                }
            }
            ForEach(people) { person in
                Section {
                    let index = profileIndex(person.id)
                    Toggle("Own rest time", isOn: Binding(
                        get: { draft.profiles[index].restSeconds != nil },
                        set: { draft.profiles[index].restSeconds = $0 ? draft.defaultRestSeconds : nil }
                    ))
                    if let rest = draft.profiles[index].restSeconds {
                        Stepper(value: Binding(get: { rest }, set: { draft.profiles[index].restSeconds = $0 }), in: 0...900, step: 15) {
                            LabeledContent("Rest", value: Format.duration(rest))
                        }
                    }
                    TextField("Machine setup (e.g. seat 4)", text: $draft.profiles[index].machineSetup)
                    TextField("Cues (e.g. tuck elbows)", text: $draft.profiles[index].cues)
                } header: {
                    Text(person.name).foregroundStyle(person.style.text)
                }
            }
            if let exerciseId, let exercise = model.catalog.exercise(exerciseId) {
                Section {
                    Button("Delete exercise", role: .destructive) { deleting = exercise }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle(exerciseId == nil ? "NEW EXERCISE" : "EDIT EXERCISE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty
                              || !(draft.tracksWeight || draft.tracksReps || draft.tracksDuration))
            }
        }
        .onAppear(perform: load)
        .modifier(DeleteExerciseDialog(exercise: $deleting, onDeleted: { dismiss() }))
    }

    private func profileIndex(_ personId: String) -> Int {
        draft.profiles.firstIndex { $0.personId == personId } ?? 0
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let catalog = model.catalog
        if let exercise = catalog.exercise(exerciseId) {
            draft = ExerciseDraft(exercise)
        }
        draft.profiles = catalog.pair.map { person in
            let profile = exerciseId.flatMap { catalog.profile(personId: person.id, exerciseId: $0) }
            return ProfileDraft(
                personId: person.id, restSeconds: profile?.restSeconds,
                machineSetup: profile?.machineSetup ?? "", cues: profile?.cues ?? ""
            )
        }
    }

    private func save() {
        if model.perform("SAVING THE EXERCISE", { try $0.saveExercise(draft) }) { dismiss() }
    }
}
