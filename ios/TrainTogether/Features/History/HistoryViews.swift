import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// History as a training ledger (§26), newest first.
struct HistoryListView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [HistoryItem] = []
    @State private var deleting: HistoryItem?

    var body: some View {
        let catalog = model.catalog
        List {
            if items.isEmpty {
                EmptyState(title: "No workouts yet", message: "Start your first session. Your history will appear here.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
            }
            ForEach(items) { item in
                NavigationLink(value: HistoryRoute.workout(item.id)) {
                    HistoryRow(item: item, catalog: catalog)
                }
                .listRowBackground(Palette.canvas)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = item }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("HISTORY")
        .task {
            do {
                for try await value in model.store.observeHistory() { items = value }
            } catch {
                model.errorMessage = "COULD NOT LOAD HISTORY — \(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            "Delete \(deleting?.session.displayName ?? "workout")?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible, presenting: deleting
        ) { item in
            Button("Delete workout", role: .destructive) {
                model.perform("DELETING THE WORKOUT") { try $0.deleteSession(id: item.id) }
            }
        } message: { _ in
            Text("Its sets are removed for both of you. This can't be undone.")
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let catalog: CatalogSnapshot

    var body: some View {
        let people = item.personIds.compactMap { catalog.person($0) }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Format.date(item.session.startTime)).metaStyle()
                Spacer()
                PersonPair(people: people, size: 18)
            }
            Text(item.session.displayName).font(Typeface.display(21)).textCase(.uppercase)
            HStack(spacing: 14) {
                if let ms = item.durationMs { stat(Format.elapsed(ms), "Time") }
                stat("\(item.setCount)", "Sets")
                ForEach(people) { person in
                    stat("\(Format.volume(item.volumeByPerson[person.id] ?? 0)) \(person.unit.rawValue)", person.name, color: person.style.text)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String, color: Color = Palette.ink) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Typeface.condensed(16)).monospacedDigit().foregroundStyle(color)
            Text(label).metaStyle(size: 10)
        }
    }
}

/// One workout in full: shared and per-person totals, then each exercise's
/// sets per person and variant. Sets stay editable.
struct WorkoutDetailView: View {
    let sessionId: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var detail: WorkoutDetail?
    @State private var editing: SetEntry?
    @State private var confirmDelete = false

    var body: some View {
        let catalog = model.catalog
        ScrollView {
            if let detail {
                let people = detail.personIds.compactMap { catalog.person($0) }
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Format.date(detail.session.startTime)).metaStyle(Palette.redDark)
                        Text(detail.session.displayName).displayStyle(34, relativeTo: .largeTitle)
                        TitleRule()
                        HStack(spacing: 9) {
                            PersonPair(people: people)
                            Text(people.map(\.name).joined(separator: " + ")).metaStyle()
                        }
                    }

                    SectionLabel("Shared session")
                    HStack(spacing: 12) {
                        StatBlock(value: detail.durationMs.map(Format.elapsed) ?? "—", label: "Duration")
                        StatBlock(value: "\(detail.exerciseOrder.count)", label: detail.exerciseOrder.count == 1 ? "Exercise" : "Exercises")
                        StatBlock(value: "\(detail.sets.count)", label: "Total sets")
                    }

                    ForEach(people) { person in
                        let totals = PersonTotals(sets: detail.sets(personId: person.id))
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name).font(Typeface.display(18)).textCase(.uppercase).foregroundStyle(person.style.text)
                            }
                            .frame(width: 70, alignment: .leading)
                            StatBlock(value: "\(totals.exercises)", label: totals.exercises == 1 ? "Exercise" : "Exercises", size: 22)
                            StatBlock(value: "\(totals.sets)", label: totals.sets == 1 ? "Set" : "Sets", size: 22)
                            StatBlock(value: "\(Format.volume(totals.volume)) \(person.unit.rawValue.uppercased())", label: "Volume", size: 22)
                        }
                        .padding(12)
                        .background(Palette.canvas)
                        .overlay(alignment: .leading) { Rectangle().fill(person.style.accent).frame(width: 6) }
                        .overlay(Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: 1))
                    }

                    ForEach(detail.exerciseOrder, id: \.self) { exerciseId in
                        exerciseBlock(exerciseId, detail: detail, people: people)
                    }

                    if detail.session.status == .finished {
                        Button("Delete workout") { confirmDelete = true }
                            .buttonStyle(DangerButtonStyle())
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                for try await value in model.store.observeWorkout(id: sessionId) {
                    if value == nil, detail != nil { dismiss() }
                    detail = value
                }
            } catch {}
        }
        .sheet(item: $editing) { set in
            if let person = catalog.person(set.personId) {
                EditSetSheet(
                    set: set, ordinal: ordinal(set), person: person,
                    other: detail?.personIds.first { $0 != set.personId }.flatMap { catalog.person($0) },
                    exercise: catalog.exercise(set.exerciseId)
                )
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                if model.perform("DELETING THE WORKOUT", { try $0.deleteSession(id: sessionId) }) { dismiss() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its sets are removed for both of you. This can't be undone.")
        }
    }

    @ViewBuilder
    private func exerciseBlock(_ exerciseId: String, detail: WorkoutDetail, people: [Person]) -> some View {
        let exercise = model.catalog.exercise(exerciseId)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(exercise?.name ?? "Deleted exercise")
            ForEach(people) { person in
                let sets = detail.sets(exerciseId: exerciseId, personId: person.id)
                let variants = Variant.allCases.filter { v in sets.contains { $0.variant == v } }
                ForEach(variants, id: \.self) { variant in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(variant == .normal ? person.name : "\(person.name) · \(variant.label)")
                            .metaStyle(person.style.text)
                        SetLedger(
                            sets: sets.filter { $0.variant == variant }.sorted { $0.setIndex < $1.setIndex },
                            exercise: exercise, unit: person.unit, accent: person.style.accent,
                            onEdit: { editing = $0 }
                        )
                    }
                }
            }
        }
    }

    private func ordinal(_ set: SetEntry) -> Int {
        guard let detail else { return 1 }
        let group = detail.sets(exerciseId: set.exerciseId, personId: set.personId)
            .filter { $0.variant == set.variant }
            .sorted { $0.setIndex < $1.setIndex }
        return (group.firstIndex { $0.id == set.id } ?? 0) + 1
    }
}
