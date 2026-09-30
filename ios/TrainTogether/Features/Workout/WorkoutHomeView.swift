import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// The Workout tab: this week at a glance, the routine that's up next (or
/// the workout in progress), the other routines, and ways to start fresh.
struct WorkoutHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var starting: StartRequest?
    @State private var conflict: StartRequest?
    @State private var startedSession: String?
    /// Nil until first read, so nothing shows as "not done yet" before the
    /// history is known.
    @State private var home: HomeSnapshot?

    var body: some View {
        let catalog = model.catalog
        let home = self.home ?? .empty
        // While a workout runs, resuming it is the one thing to suggest.
        let nextUp = model.active == nil ? catalog.routine(home.nextUp) : nil
        let others = catalog.templates.filter { $0.id != nextUp?.id }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 9) {
                        PersonPair(people: catalog.pair)
                        Text(catalog.pair.map(\.name).joined(separator: " + ")).metaStyle()
                    }
                    TitleRule()
                }

                if self.home != nil { WeekStrip(home: home) }

                if let active = model.active {
                    ResumeCard(session: active.session) { model.resumeWorkout() }
                } else if let nextUp {
                    NextUpCard(routine: nextUp, lastDone: home.lastDone[nextUp.id], catalog: catalog) {
                        model.workoutPath.append(.routine(nextUp.id))
                    } onStart: {
                        requestStart(nextUp.id)
                    }
                }

                if catalog.templates.isEmpty {
                    EmptyState(title: "No routines yet", message: "Create one below, or bring back the example Push Day.")
                    Button("Restore example Push Day") {
                        model.perform("RESTORING PUSH DAY") { try $0.restoreDemoRoutine() }
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                if self.home != nil, !others.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(nextUp == nil ? "Routines" : "Other routines")
                        VStack(spacing: 0) {
                            ForEach(others) { routine in
                                RoutineRow(routine: routine, lastDone: home.lastDone[routine.id], catalog: catalog) {
                                    model.workoutPath.append(.routine(routine.id))
                                } onStart: {
                                    requestStart(routine.id)
                                }
                                if routine.id != others.last?.id {
                                    Rectangle().fill(Palette.ruleSoft).frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .card()
                    }
                }

                HStack(spacing: 10) {
                    Button { requestStart(nil) } label: {
                        Label("Quick start", systemImage: "bolt.fill")
                    }
                    Button {
                        var id: String?
                        if model.perform("CREATING THE ROUTINE", { id = try $0.createTemplate() }), let id {
                            model.workoutPath.append(.routine(id))
                        }
                    } label: {
                        Label("New routine", systemImage: "plus")
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .paperBackground()
        .navigationTitle("WORKOUTS")
        .onAppear {
            // A first read now, so the screen doesn't redraw once the
            // observation below delivers.
            if self.home == nil { self.home = try? model.store.home() }
        }
        // Again when the day rolls over, so the week strip and "days ago" move.
        .task(id: Calendar.current.startOfDay(for: .now)) {
            do {
                for try await value in model.store.observeHome() { self.home = value }
            } catch {
                model.errorMessage = "COULD NOT LOAD THE WEEK — \(error.localizedDescription)"
            }
        }
        .sheet(item: $starting, onDismiss: {
            if let id = startedSession {
                startedSession = nil
                model.workoutCover = .live(sessionId: id)
            }
        }) { request in
            StartWorkoutSheet(templateId: request.templateId) { startedSession = $0 }
        }
        .alert("Workout in progress", isPresented: Binding(get: { conflict != nil }, set: { if !$0 { conflict = nil } }),
               presenting: conflict) { request in
            Button("Resume") { model.resumeWorkout() }
            Button("Discard & start new", role: .destructive) {
                model.discardWorkout()
                starting = request
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Finish or discard \(model.active?.session.displayName ?? "it") before starting another.")
        }
    }

    /// Only one workout at a time: an active one must be resumed or
    /// discarded first — never silently thrown away.
    private func requestStart(_ templateId: String?) {
        let request = StartRequest(templateId: templateId)
        if model.active != nil { conflict = request } else { starting = request }
    }
}

struct StartRequest: Identifiable {
    let id = UUID()
    let templateId: String?
}

private struct ResumeCard: View {
    let session: WorkoutSession
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In progress").metaStyle(Palette.onDarkMuted)
                    Text(session.displayName).displayStyle(24).foregroundStyle(Palette.onDark)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("Resume").labelStyle(15)
                    Icon(.arrowRight, size: 15)
                }
                .foregroundStyle(Palette.onDark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.ink)
            .overlay(alignment: .leading) { Rectangle().fill(Palette.red).frame(width: 6) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume \(session.displayName)")
    }
}

/// This week, a square per day: filled when you trained, today outlined red.
private struct WeekStrip: View {
    let home: HomeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "This week") {
                Text(home.workoutsThisWeek == 1 ? "1 workout" : "\(home.workoutsThisWeek) workouts").metaStyle(Palette.ink)
            }
            HStack(spacing: 6) {
                ForEach(Array(home.weekDays.enumerated()), id: \.offset) { index, start in
                    day(start, trained: home.trained[index], today: index == home.today, future: index > home.today)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func day(_ start: Int64, trained: Bool, today: Bool, future: Bool) -> some View {
        let date = Date(epochMilliseconds: start)
        return VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.narrow))).metaStyle(trained ? Palette.onDarkMuted : Palette.textSecondary, size: 10)
            Text(date.formatted(.dateTime.day()))
                .font(Typeface.condensed(17))
                .monospacedDigit()
                .foregroundStyle(trained ? Palette.onDark : future ? Palette.textSecondary : Palette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(RoundedRectangle(cornerRadius: Radius.sm).fill(trained ? Palette.ink : Palette.canvas))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .strokeBorder(today ? Palette.red : trained ? Palette.ink : Palette.ruleSoft, lineWidth: Stroke.width)
        )
    }

    private var accessibilityText: String {
        let days = home.weekDays.enumerated().filter { home.trained[$0.offset] }
            .map { Date(epochMilliseconds: $0.element).formatted(.dateTime.weekday(.wide)) }
        let count = home.workoutsThisWeek == 1 ? "1 workout" : "\(home.workoutsThisWeek) workouts"
        return days.isEmpty ? "This week: no workouts yet" : "This week: \(count), on \(days.joined(separator: ", "))"
    }
}

/// "Last done 6 days ago", or "Not done yet".
private func lastDoneText(_ lastDone: Int64?) -> String {
    lastDone.map { "Last done \(Format.daysAgo($0, now: Date().epochMilliseconds))" } ?? "Not done yet"
}

private func routineDetail(_ routine: RoutineSummary) -> String {
    "\(routine.exercises.count) \(routine.exercises.count == 1 ? "exercise" : "exercises") · \(routine.template.defaultMode.label) sets"
}

/// The routine to do next, big: its exercises as pictograms and one Start.
private struct NextUpCard: View {
    let routine: RoutineSummary
    let lastDone: Int64?
    let catalog: CatalogSnapshot
    let onOpen: () -> Void
    let onStart: () -> Void

    var body: some View {
        let icons = routine.exercises.map { catalog.exercise($0.exerciseId)?.resolvedIcon ?? .generic }
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Next up · \(lastDoneText(lastDone))").metaStyle(Palette.onDarkMuted)
                        Spacer()
                        Icon(.chevronRight, size: 8).foregroundStyle(Palette.onDark)
                    }
                    Text(routine.template.name).displayStyle(32).foregroundStyle(Palette.onDark)
                    if !icons.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(icons.prefix(6).enumerated()), id: \.offset) { _, icon in
                                ExerciseTile(icon, size: 34, onDark: true)
                            }
                            if icons.count > 6 {
                                Text("+\(icons.count - 6)").font(Typeface.condensed(15)).foregroundStyle(Palette.onDark)
                            }
                        }
                    }
                    Text(routineDetail(routine)).font(Typeface.body(14)).foregroundStyle(Palette.onDarkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Edit \(routine.template.name)")
            .accessibilityHint("\(lastDoneText(lastDone)). \(routineDetail(routine))")

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("Start workout")
                    Icon(.arrowRight, size: 15)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Start workout")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Palette.ink))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: Radius.md, bottomLeadingRadius: Radius.md).fill(Palette.red).frame(width: 6)
        }
    }
}

/// A routine in the list: its first exercise's pictogram, when it was last
/// done, and a start button.
private struct RoutineRow: View {
    let routine: RoutineSummary
    let lastDone: Int64?
    let catalog: CatalogSnapshot
    let onOpen: () -> Void
    let onStart: () -> Void

    var body: some View {
        let icon = routine.exercises.first.flatMap { catalog.exercise($0.exerciseId)?.resolvedIcon } ?? .generic
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ExerciseTile(icon, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.template.name).font(Typeface.condensed(19)).textCase(.uppercase).lineLimit(1)
                        Text(lastDoneText(lastDone)).metaStyle(size: 11).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Edit \(routine.template.name)")
            .accessibilityHint("\(lastDoneText(lastDone)). \(routineDetail(routine))")

            Button(action: onStart) {
                Icon(.arrowRight, size: 15)
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Palette.red))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(routine.template.name)")
        }
        .padding(.vertical, 12)
    }
}
