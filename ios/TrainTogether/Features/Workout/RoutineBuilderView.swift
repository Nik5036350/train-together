import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Edit a routine: name, default logging style, exercises (drag to reorder,
/// swipe to remove, tap for who does it). Every change saves immediately.
struct RoutineBuilderView: View {
    let templateId: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var nameSave: Task<Void, Never>?
    @State private var assigning: TemplateExercise?
    @State private var addingExercise = false
    @State private var confirmDelete = false

    var body: some View {
        if let routine = model.catalog.routine(templateId) {
            content(routine)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func content(_ routine: RoutineSummary) -> some View {
        let catalog = model.catalog
        return List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Routine name", text: $name)
                        .font(Typeface.display(30, relativeTo: .largeTitle))
                        .textCase(.uppercase)
                        .submitLabel(.done)
                        .onSubmit(saveName)
                    TitleRule()
                    HStack(spacing: 8) {
                        Menu {
                            Picker("Default logging style", selection: Binding(
                                get: { routine.template.defaultMode },
                                set: { mode in model.perform("SAVING THE ROUTINE") { try $0.updateTemplate(id: templateId, defaultMode: mode) } }
                            )) {
                                ForEach(LoggingMode.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(routine.template.defaultMode.label)
                                Icon(.chevronDown, size: 9)
                            }
                            .labelStyle(13)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Palette.canvas))
                            .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(Palette.ink, lineWidth: Stroke.width))
                        }
                        .accessibilityLabel("Default logging style: \(routine.template.defaultMode.label)")
                        Text("Default logging style").metaStyle()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, row in
                    Button { assigning = row } label: {
                        RoutineExerciseRow(index: index, row: row, catalog: catalog)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Palette.canvas)
                }
                .onMove { from, to in
                    model.perform("REORDERING") { try $0.moveTemplateExercises(templateId: templateId, fromOffsets: from, toOffset: to) }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let id = routine.exercises[index].id
                        model.perform("REMOVING THE EXERCISE") { try $0.removeTemplateExercise(id: id) }
                    }
                }

                Button { addingExercise = true } label: {
                    Label("Add exercise", systemImage: "plus").labelStyle(15).foregroundStyle(Palette.ink)
                }
                .listRowBackground(Palette.canvas)
            } header: {
                SectionLabel("Exercises")
            }

            Section {
                Button("Delete routine", role: .destructive) { confirmDelete = true }
                    .buttonStyle(DangerButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle(name.isEmpty ? "Routine" : name.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear { name = routine.template.name }
        .onChange(of: name) { _, _ in
            nameSave?.cancel()
            nameSave = Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                saveName()
            }
        }
        .onDisappear(perform: saveName)
        .confirmationDialog(
            "Who does \(assigning.flatMap { catalog.exercise($0.exerciseId)?.name } ?? "this")?",
            isPresented: Binding(get: { assigning != nil }, set: { if !$0 { assigning = nil } }),
            titleVisibility: .visible, presenting: assigning
        ) { row in
            if let owner = catalog.owner {
                Button("\(owner.name) only") { assign(row, .owner) }
            }
            if let partner = catalog.partner {
                Button("\(partner.name) only") { assign(row, .partner) }
                Button("Both of you") { assign(row, .both) }
            }
            Button("Remove from routine", role: .destructive) {
                model.perform("REMOVING THE EXERCISE") { try $0.removeTemplateExercise(id: row.id) }
            }
        }
        .confirmationDialog("Delete \(routine.template.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete routine", role: .destructive) {
                if model.perform("DELETING THE ROUTINE", { try $0.deleteTemplate(id: templateId) }) { dismiss() }
            }
        } message: {
            Text("Past workouts from this routine stay in history.")
        }
        .sheet(isPresented: $addingExercise) {
            ExercisePicker(
                title: "Add exercise",
                exclude: Set(routine.exercises.map(\.exerciseId))
            ) { exerciseId in
                model.perform("ADDING THE EXERCISE") { try $0.addTemplateExercise(templateId: templateId, exerciseId: exerciseId) }
            }
        }
    }

    private func saveName() {
        nameSave?.cancel()
        guard let routine = model.catalog.routine(templateId), name != routine.template.name else { return }
        model.perform("SAVING THE ROUTINE") { try $0.updateTemplate(id: templateId, name: name) }
    }

    private func assign(_ row: TemplateExercise, _ assignment: Assignment) {
        model.perform("SAVING THE ROUTINE") { try $0.setAssignment(templateExerciseId: row.id, assignment: assignment) }
    }
}

private struct RoutineExerciseRow: View {
    let index: Int
    let row: TemplateExercise
    let catalog: CatalogSnapshot

    var body: some View {
        let people: [Person] = switch row.assignment {
        case .both: catalog.pair
        case .owner: [catalog.owner].compactMap { $0 }
        case .partner: [catalog.partner].compactMap { $0 }
        }
        HStack(spacing: 12) {
            Text(Format.ordinal(index + 1))
                .font(Typeface.display(18))
                .monospacedDigit()
                .foregroundStyle(Palette.textSecondary)
            ExerciseTile(catalog.exercise(row.exerciseId)?.resolvedIcon ?? .generic, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(catalog.exercise(row.exerciseId)?.name ?? "Deleted exercise")
                    .font(Typeface.condensed(17))
                    .textCase(.uppercase)
                Text(assignmentLabel(people)).font(Typeface.body(13)).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            PersonPair(people: people, size: 20)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func assignmentLabel(_ people: [Person]) -> String {
        switch row.assignment {
        case .both where people.count > 1: "Both of you"
        default: people.first.map { "\($0.name) only" } ?? "Nobody (no partner yet)"
        }
    }
}
