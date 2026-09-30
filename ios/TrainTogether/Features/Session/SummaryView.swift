import SwiftUI
import TrainTogetherCore
import TrainTogetherKit

/// Post-workout summary (§25): shared totals, then each person's block in
/// their color and their own unit. A restrained diagonal instead of confetti.
struct SummaryView: View {
    let sessionId: String
    @Environment(AppModel.self) private var model
    @State private var detail: WorkoutDetail?

    var body: some View {
        let catalog = model.catalog
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(detail?.session.displayName ?? "")
                if let detail {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            StatBlock(value: detail.durationMs.map(Format.elapsed) ?? "—", label: "Total time", size: 34)
                            StatBlock(value: "\(detail.sets.count)", label: detail.sets.count == 1 ? "Total set" : "Total sets", size: 34)
                            let exercises = Set(detail.sets.map(\.exerciseId)).count
                            StatBlock(value: "\(exercises)", label: exercises == 1 ? "Exercise" : "Exercises", size: 34)
                        }
                        TitleRule(height: Stroke.width)
                        VStack(spacing: 10) {
                            ForEach(detail.personIds, id: \.self) { id in
                                if let person = catalog.person(id) {
                                    PersonSummary(person: person, totals: PersonTotals(sets: detail.sets(personId: id)))
                                }
                            }
                        }
                        Text("Logged separately, trained together.")
                            .font(Typeface.body(14))
                            .foregroundStyle(Palette.textSecondary)
                        Button("View details") { model.showWorkoutInHistory(sessionId) }
                            .buttonStyle(GhostButtonStyle())
                        Button("Done") { model.workoutCover = nil }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(20)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .paperBackground()
        .task {
            do {
                for try await value in model.store.observeWorkout(id: sessionId) { detail = value }
            } catch {}
        }
    }

    private func hero(_ name: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            Palette.red
            // The completion motif: an Ink diagonal cutting the red field.
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width * 0.55, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.18))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(Palette.ink)
            }
            Grain(opacity: 0.05)
            VStack(alignment: .leading, spacing: 6) {
                Text("Workout complete").displayStyle(TypeScale.display, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.onAccent)
                Text(name).metaStyle(Palette.onAccent)
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .frame(height: 260)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct PersonSummary: View {
    let person: Person
    let totals: PersonTotals

    var body: some View {
        HStack(spacing: 0) {
            IdentityBand(person: person, active: true, width: 30)
            HStack(spacing: 12) {
                StatBlock(value: "\(Format.volume(totals.volume)) \(person.unit.rawValue.uppercased())", label: "Volume", size: 26)
                StatBlock(value: "\(totals.sets)", label: totals.sets == 1 ? "Set" : "Sets", size: 26)
                StatBlock(value: "\(totals.reps)", label: totals.reps == 1 ? "Rep" : "Reps", size: 26)
            }
            .padding(14)
        }
        .background(Palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(person.style.accent, lineWidth: Stroke.width))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(person.name): \(Format.volume(totals.volume)) \(person.unit.rawValue) volume, \(totals.sets) sets, \(totals.reps) reps")
    }
}
