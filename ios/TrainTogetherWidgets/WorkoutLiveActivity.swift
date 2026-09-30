import ActivityKit
import SwiftUI
import TrainTogetherCore
import WidgetKit

@main
struct TrainTogetherWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

/// The rest timer on the Lock Screen and in the Dynamic Island. Countdowns
/// use `Text(timerInterval:)`, which ticks on its own — the app has no push to
/// wake it.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Palette.paper)
                .activitySystemActionForegroundColor(Palette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.exerciseName.uppercased())
                        .font(Typeface.condensed(15))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let turn = context.state.turn {
                        Text("\(turn.name.uppercased())'S TURN")
                            .font(Typeface.condensed(13))
                            .foregroundStyle(PersonColor(key: turn.color).style.tint)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        ForEach(context.state.people, id: \.name) { person in
                            PersonRest(person: person, dark: true)
                        }
                    }
                }
            } compactLeading: {
                if let person = context.state.turn ?? context.state.people.first {
                    InitialBlock(person: person, size: 20)
                }
            } compactTrailing: {
                if let end = soonestEnd(context.state), end > .now {
                    Text(timerInterval: .now...end, countsDown: true)
                        .font(Typeface.condensed(14))
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                        .foregroundStyle(.white)
                } else {
                    Text("READY").font(Typeface.condensed(12)).foregroundStyle(Palette.green)
                }
            } minimal: {
                if let person = context.state.turn ?? context.state.people.first {
                    InitialBlock(person: person, size: 18)
                }
            }
        }
    }

    private func soonestEnd(_ state: WorkoutActivityAttributes.ContentState) -> Date? {
        state.people.compactMap(\.restEndsAt).filter { $0 > .now }.min()
    }
}

private struct LockScreenView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 0) {
            if let turn = state.turn {
                let style = PersonColor(key: turn.color).style
                Text(turn.name.uppercased())
                    .font(Typeface.display(14))
                    .foregroundStyle(style.onAccent)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .frame(width: 26)
                    .frame(maxHeight: .infinity)
                    .background(style.accent)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(state.exerciseName.uppercased())
                        .font(Typeface.display(18))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(attributes.workoutName.uppercased())
                        .font(Typeface.condensed(12))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Rectangle().fill(Palette.ink).frame(height: 2)
                HStack(spacing: 12) {
                    ForEach(state.people, id: \.name) { person in
                        PersonRest(person: person, dark: false)
                    }
                }
            }
            .padding(12)
        }
    }
}

private struct PersonRest: View {
    let person: WorkoutActivityAttributes.Participant
    let dark: Bool

    var body: some View {
        HStack(spacing: 8) {
            InitialBlock(person: person, size: 24)
            VStack(alignment: .leading, spacing: 0) {
                if let start = person.restStartedAt, let end = person.restEndsAt, end > .now {
                    Text(timerInterval: start...end, countsDown: true)
                        .font(Typeface.display(22))
                        .monospacedDigit()
                        .foregroundStyle(dark ? .white : Palette.ink)
                    Text("RESTING").font(Typeface.condensed(11)).foregroundStyle(dark ? Palette.onDarkMuted : Palette.steel)
                } else {
                    Text("READY").font(Typeface.display(22)).foregroundStyle(Palette.green)
                    Text(person.name.uppercased()).font(Typeface.condensed(11)).foregroundStyle(dark ? Palette.onDarkMuted : Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InitialBlock: View {
    let person: WorkoutActivityAttributes.Participant
    let size: CGFloat

    var body: some View {
        let style = PersonColor(key: person.color).style
        Text(person.initials.isEmpty ? String(person.name.prefix(1)) : person.initials)
            .font(Typeface.display(size * 0.55))
            .foregroundStyle(style.onAccent)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 4).fill(style.accent))
    }
}
