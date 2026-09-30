import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// The Workout tab: resume what's in progress, start a routine or an empty
/// workout, manage routines.
struct WorkoutHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var starting: StartRequest?
    @State private var conflict: StartRequest?
    @State private var startedSession: String?

    var body: some View {
        let catalog = model.catalog
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    PersonPair(people: catalog.pair)
                    Text(catalog.pair.map(\.name).joined(separator: " + ")).metaStyle()
                }
                TitleRule()

                if let active = model.active {
                    ResumeCard(session: active.session) { model.resumeWorkout() }
                }

                SectionLabel(title: "Routines") {
                    Button("Quick start") { requestStart(nil) }
                        .labelStyle(13)
                        .foregroundStyle(Palette.redDark)
                }

                if catalog.templates.isEmpty {
                    EmptyState(title: "No routines yet", message: "Create one below, or bring back the example Push Day.")
                    Button("Restore example Push Day") {
                        model.perform("RESTORING PUSH DAY") { try $0.restoreDemoRoutine() }
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                ForEach(catalog.templates) { routine in
                    RoutineCard(routine: routine, catalog: catalog) {
                        model.workoutPath.append(.routine(routine.id))
                    } onStart: {
                        requestStart(routine.id)
                    }
                }

                Button {
                    var id: String?
                    if model.perform("CREATING THE ROUTINE", { id = try $0.createTemplate() }), let id {
                        model.workoutPath.append(.routine(id))
                    }
                } label: {
                    Label("New routine", systemImage: "plus")
                        .labelStyle(15)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: Stroke.width, dash: [6, 4]))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .paperBackground()
        .navigationTitle("WORKOUTS")
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

struct RoutineCard: View {
    let routine: RoutineSummary
    let catalog: CatalogSnapshot
    let onEdit: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onEdit) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routine.template.name).displayStyle(22)
                        Text("\(routine.exercises.count) \(routine.exercises.count == 1 ? "exercise" : "exercises") · \(routine.template.defaultMode.label) sets")
                            .font(Typeface.body(14))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Icon(.chevronRight, size: 8).foregroundStyle(Palette.ink).padding(.top, 6)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(routine.template.name)")

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("Start workout").labelStyle(16)
                    Icon(.arrowRight, size: 15)
                }
                .foregroundStyle(Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Palette.red)
            }
            .buttonStyle(.plain)
        }
        .background(Palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.rule, lineWidth: Stroke.width))
    }
}
