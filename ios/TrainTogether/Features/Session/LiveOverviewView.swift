import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// The workout at a glance: the planned exercises, what's been added today,
/// and the rest of the library to add from. The card the workout is "on" is
/// expanded with whose turn it is and the rest timers.
struct LiveOverviewView: View {
    let sessionId: String
    @Binding var path: [String]
    @Environment(AppModel.self) private var model
    @State private var finishing = false
    @State private var confirmDiscard = false
    @State private var findingExercise = false
    /// A card added from the exercise sheet, opened once the sheet is gone.
    @State private var addedCard: String?

    var body: some View {
        if let active = model.active, active.session.id == sessionId {
            content(active)
        } else {
            Color.clear.paperBackground()
        }
    }

    private func content(_ active: ActiveSessionSnapshot) -> some View {
        let catalog = model.catalog
        let participants = active.participantIds.compactMap { catalog.person($0) }
        let planned = active.cards.filter { !$0.exercise.addedDuringSession }
        let added = active.cards.filter(\.exercise.addedDuringSession)
        let inWorkout = Set(active.cards.map(\.exercise.exerciseId))
        let optional = catalog.exercises.filter { !inWorkout.contains($0.id) }
        let currentID = active.currentCardID

        return TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date.epochMilliseconds
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(active.session.displayName).displayStyle(34, relativeTo: .largeTitle)
                        TitleRule()
                        HStack(spacing: 9) {
                            PersonPair(people: participants)
                            Text(participants.map(\.name).joined(separator: " + ")).metaStyle()
                            Spacer()
                            Text(Format.elapsed(now - active.session.startTime))
                                .font(Typeface.display(20, relativeTo: .title3))
                                .monospacedDigit()
                                .accessibilityLabel("Elapsed \(Format.elapsed(now - active.session.startTime))")
                        }
                    }

                    if !planned.isEmpty {
                        SectionLabel("Standard plan")
                        cardList(planned, active: active, currentID: currentID, now: now)
                    }
                    if !added.isEmpty {
                        SectionLabel("Added today")
                        cardList(added, active: active, currentID: currentID, now: now)
                    }
                    if active.cards.isEmpty {
                        Text("Add the first exercise from the list below.")
                            .font(Typeface.body(15))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    if !optional.isEmpty {
                        SectionLabel("Optional exercises")
                        VStack(spacing: 0) {
                            ForEach(optional) { exercise in
                                Button { add(exercise.id, to: active) } label: {
                                    HStack(spacing: 12) {
                                        ExerciseTile(exercise.resolvedIcon, size: 30)
                                        Text(exercise.name).font(Typeface.condensed(16)).textCase(.uppercase)
                                        Spacer()
                                        Icon(.plus, size: 12)
                                    }
                                    .foregroundStyle(Palette.ink)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .bottom) { Rectangle().fill(Palette.ruleSoft).frame(height: 1) }
                                .accessibilityLabel("Add \(exercise.name)")
                            }
                        }
                    }
                    Button { findingExercise = true } label: {
                        Label("Find an exercise", systemImage: "magnifyingglass")
                            .labelStyle(15)
                            .foregroundStyle(Palette.redDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("find-exercise")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .paperBackground()
        .solidTopEdge()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { model.workoutCover = nil } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel("Minimize workout")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Discard workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { finishing = true }
                    .fontWeight(.bold)
            }
        }
        .sheet(isPresented: $finishing) {
            FinishSheet(active: active) { model.finishWorkout(sessionId) }
        }
        .sheet(isPresented: $findingExercise, onDismiss: openAddedCard) {
            ExercisePicker(title: "Add exercise", exclude: Set(active.cards.map(\.exercise.exerciseId))) { exerciseId in
                addedCard = addCard(exerciseId, to: active)
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { model.discardWorkout() }
        } message: {
            Text("Everything logged in it will be deleted.")
        }
    }

    private func cardList(_ cards: [ActiveSessionSnapshot.Card], active: ActiveSessionSnapshot, currentID: String?, now: Int64) -> some View {
        VStack(spacing: 10) {
            ForEach(cards) { card in
                let number = active.cards.firstIndex { $0.id == card.id }.map { $0 + 1 } ?? 0
                Button { path.append(card.id) } label: {
                    if card.id == currentID {
                        CurrentCardRow(card: card, active: active, catalog: model.catalog, now: now)
                    } else {
                        CardRow(number: number, card: card, active: active, catalog: model.catalog)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("card-\(number)")
            }
        }
    }

    private func add(_ exerciseId: String, to active: ActiveSessionSnapshot) {
        if let cardId = addCard(exerciseId, to: active) { path.append(cardId) }
    }

    private func addCard(_ exerciseId: String, to active: ActiveSessionSnapshot) -> String? {
        var cardId: String?
        let ok = model.perform("ADDING THE EXERCISE") {
            cardId = try $0.addSessionExercise(sessionId: active.session.id, exerciseId: exerciseId)
        }
        return ok ? cardId : nil
    }

    private func openAddedCard() {
        if let addedCard { path.append(addedCard) }
        addedCard = nil
    }
}

/// The card the workout is on: whose turn, and everyone's rest.
private struct CurrentCardRow: View {
    let card: ActiveSessionSnapshot.Card
    let active: ActiveSessionSnapshot
    let catalog: CatalogSnapshot
    let now: Int64

    var body: some View {
        let turn = catalog.person(card.exercise.activePersonId)
        let timer = turn.flatMap { active.timers[$0.id] }
        HStack(spacing: 0) {
            if let turn { IdentityBand(person: turn, active: true, width: 30) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(catalog.exercise(card.exercise.exerciseId)?.name ?? "Exercise").displayStyle(24)
                        if let turn, card.visiblePeople.count > 1 {
                            Text("Next · \(turn.name)").metaStyle(turn.style.text)
                        }
                    }
                    Spacer()
                    TimerRing(
                        phase: timer.flatMap { $0.sessionExerciseId == card.id ? $0.phase(now: now) : nil },
                        total: timer?.durationSeconds ?? 0, size: 64, stroke: 5
                    )
                }
                ForEach(card.visiblePeople, id: \.personId) { row in
                    if let person = catalog.person(row.personId) {
                        PersonRestLine(person: person, card: card, active: active, now: now)
                    }
                }
            }
            .padding(14)
        }
        .background(Palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(turn?.style.accent ?? Palette.rule, lineWidth: Stroke.width))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the exercise")
    }
}

private struct PersonRestLine: View {
    let person: Person
    let card: ActiveSessionSnapshot.Card
    let active: ActiveSessionSnapshot
    let now: Int64

    var body: some View {
        let sets = active.sets(cardId: card.id, personId: person.id).count
        let timer = active.timers[person.id]
        let phase = timer.flatMap { $0.sessionExerciseId == card.id ? $0.phase(now: now) : nil }
        HStack {
            Avatar(person: person, size: 20)
            Text(person.name).font(Typeface.condensed(15)).textCase(.uppercase)
            Spacer()
            if let phase {
                Text(restText(phase))
                    .font(Typeface.condensed(14))
                    .monospacedDigit()
                    .textCase(.uppercase)
                    .foregroundStyle(phase.labelColor)
            }
            Text("\(sets) \(sets == 1 ? "set" : "sets")")
                .font(Typeface.condensed(14))
                .textCase(.uppercase)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func restText(_ phase: RestPhase) -> String {
        switch phase {
        case .resting(let remaining): "Rest \(Format.clock(remaining))"
        case .ready: "Ready"
        case .overdue: "Overdue"
        }
    }
}

private struct CardRow: View {
    let number: Int
    let card: ActiveSessionSnapshot.Card
    let active: ActiveSessionSnapshot
    let catalog: CatalogSnapshot

    var body: some View {
        let people = card.people.compactMap { catalog.person($0.personId) }
        let allSkipped = card.people.allSatisfy { $0.status == .skipped }
        let substituted = card.people.contains { $0.substituteExerciseId != nil }
        HStack(spacing: 12) {
            if card.exercise.addedDuringSession {
                Tag(text: "Extra", fill: Palette.ink, foreground: Palette.onDark)
            } else {
                Text(Format.ordinal(number))
                    .font(Typeface.display(18))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            ExerciseTile(catalog.exercise(card.exercise.exerciseId)?.resolvedIcon ?? .generic, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(catalog.exercise(card.exercise.exerciseId)?.name ?? "Exercise")
                        .font(Typeface.condensed(17))
                        .textCase(.uppercase)
                    if substituted { Tag(text: "Substituted", fill: Palette.mustard, foreground: Palette.ink) }
                }
                Text(subtitle).font(Typeface.body(13)).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            PersonPair(people: people, size: 20)
            Icon(.chevronRight, size: 7).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.ruleSoft, lineWidth: 1))
        .opacity(allSkipped ? 0.65 : 1)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let skipped = card.people.filter { $0.status == .skipped }
        if !skipped.isEmpty {
            return skipped.map { row in
                let name = catalog.person(row.personId)?.name ?? ""
                return "Skipped for \(name)" + (row.skipReason.map { " · \($0)" } ?? "")
            }.joined(separator: "; ")
        }
        return active.sets.contains { $0.sessionExerciseId == card.id } ? "In progress" : "Not started yet"
    }
}

/// "Finish workout?" — lists exercises nobody finished.
private struct FinishSheet: View {
    let active: ActiveSessionSnapshot
    let onFinish: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let unfinished = active.unfinishedCards
        VStack(alignment: .leading, spacing: 16) {
            Text("Finish workout?").displayStyle(28)
            TitleRule(height: Stroke.width)
            if unfinished.isEmpty {
                Text("Everything's logged. Nice work, both of you.")
                    .font(Typeface.body(15))
                    .foregroundStyle(Palette.textSecondary)
            } else {
                Text("Not done yet").metaStyle()
                ForEach(unfinished) { card in
                    Text(model.catalog.exercise(card.exercise.exerciseId)?.name ?? "Exercise")
                        .font(Typeface.condensed(17))
                        .textCase(.uppercase)
                }
            }
            Spacer(minLength: 0)
            Button(unfinished.isEmpty ? "Finish & see summary" : "Finish anyway") {
                dismiss()
                onFinish()
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Return to workout") { dismiss() }
                .buttonStyle(GhostButtonStyle())
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationBackground(Palette.paper)
        .presentationCornerRadius(Radius.lg)
    }
}
