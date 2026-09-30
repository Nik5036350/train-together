import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Choose an exercise: the library first, then popular exercises it doesn't
/// have yet (picking one adds it), narrowed by search and muscle group. A new
/// exercise can be made on the spot in the full editor, named from the search.
struct ExercisePicker: View {
    let title: String
    var exclude: Set<String> = []
    /// Called with the chosen (or just added) exercise's id.
    let onPick: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var group: MuscleGroup?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            let library = model.catalog.exercises
            let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let mine = library.filter { !exclude.contains($0.id) && shows([$0.name], in: $0.muscleGroup) }
            let popular = PopularExercises.missing(from: library).filter { shows([$0.name] + $0.aliases, in: $0.group) }
            let known = library.contains { $0.name.compare(typed, options: .caseInsensitive) == .orderedSame }
                || PopularExercises.all.contains { $0.matches(name: typed) }
            List {
                Button { creating = true } label: {
                    Label(typed.isEmpty || known ? "New exercise" : "Create \u{201C}\(typed)\u{201D}", systemImage: "plus")
                        .labelStyle(15)
                        .foregroundStyle(Palette.redDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.canvas)
                .accessibilityIdentifier("create-exercise")

                if !mine.isEmpty {
                    Section {
                        ForEach(mine) { exercise in
                            Button { pick(exercise.id) } label: { ExerciseRowLabel(exercise) }
                                .buttonStyle(.plain)
                                .listRowBackground(Palette.canvas)
                        }
                    } header: {
                        SectionLabel("Your exercises")
                    }
                }

                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    let entries = popular.filter { $0.group == muscle }
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { entry in
                                Button { add(entry) } label: { ExerciseRowLabel(entry) }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Palette.canvas)
                                    .accessibilityIdentifier("popular-\(entry.id)")
                            }
                        } header: {
                            SectionLabel("Popular · \(muscle.label)")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .searchable(text: $query)
            .safeAreaBar(edge: .top) {
                MuscleGroupFilter(selection: $group).padding(.bottom, 6)
            }
            .navigationTitle(title.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(isPresented: $creating) {
                ExerciseEditorView(exerciseId: nil, initialName: known ? "" : typed) { id in pick(id) }
            }
        }
        .presentationBackground(Palette.paper)
    }

    /// Whether an exercise with these names, in this muscle group, passes the
    /// search and the group filter.
    private func shows(_ names: [String], in muscle: MuscleGroup?) -> Bool {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (group == nil || group == muscle)
            && (typed.isEmpty || names.contains { $0.localizedCaseInsensitiveContains(typed) })
    }

    private func pick(_ id: String) {
        onPick(id)
        dismiss()
    }

    private func add(_ entry: PopularExercise) {
        var id: String?
        guard model.perform("ADDING THE EXERCISE", { id = try $0.addPopularExercise(id: entry.id) }), let id else { return }
        pick(id)
    }
}
