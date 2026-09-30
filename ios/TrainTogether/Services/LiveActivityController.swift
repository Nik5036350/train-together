import ActivityKit
import Foundation
import TrainTogetherCore
import TrainTogetherKit

/// Keeps one Live Activity in step with the workout in progress. Updates are
/// local (`pushType: nil`): a Personal Team has no push entitlement. Countdowns
/// render with `Text(timerInterval:)`, so they tick without updates.
@MainActor
final class LiveActivityController {
    private var lastState: WorkoutActivityAttributes.ContentState?

    func sync(snapshot: AppSnapshot, enabled: Bool) {
        let activities = Activity<WorkoutActivityAttributes>.activities
        guard enabled, let active = snapshot.active else {
            end(activities)
            return
        }
        // Strays from an earlier workout (or a crash) are ended.
        end(activities.filter { $0.attributes.sessionId != active.session.id })
        let state = Self.state(snapshot: snapshot, active: active)
        let content = ActivityContent(state: state, staleDate: Self.staleDate(state))

        if let current = activities.first(where: { $0.attributes.sessionId == active.session.id }) {
            guard state != lastState else { return }
            lastState = state
            // Activity isn't Sendable; look it up again inside the task.
            let id = current.id
            Task {
                for activity in Activity<WorkoutActivityAttributes>.activities where activity.id == id {
                    await activity.update(content)
                }
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WorkoutActivityAttributes(
            sessionId: active.session.id, workoutName: active.session.displayName,
            startedAt: Date(epochMilliseconds: active.session.startTime)
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            lastState = state
        } catch {
            // Starting only works in the foreground; the next change retries.
        }
    }

    private func end(_ activities: [Activity<WorkoutActivityAttributes>]) {
        guard !activities.isEmpty else { return }
        lastState = nil
        let ids = Set(activities.map(\.id))
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func state(snapshot: AppSnapshot, active: ActiveSessionSnapshot) -> WorkoutActivityAttributes.ContentState {
        let catalog = snapshot.catalog
        let card = active.card(active.currentCardID) ?? active.cards.last
        let people = active.participantIds.compactMap { id -> WorkoutActivityAttributes.Participant? in
            guard let person = catalog.person(id) else { return nil }
            let timer = active.timers[id]
            return .init(
                name: person.name, initials: person.initials, color: person.color,
                restStartedAt: timer.map { Date(epochMilliseconds: $0.startedAt) },
                restEndsAt: timer.map { Date(epochMilliseconds: $0.endsAt) }
            )
        }
        let turn = active.participantIds.count > 1
            ? catalog.person(card?.exercise.activePersonId).flatMap { p in people.first { $0.name == p.name } }
            : nil
        return .init(
            exerciseName: card.flatMap { catalog.exercise($0.exercise.exerciseId)?.name } ?? active.session.displayName,
            turn: turn, people: people
        )
    }

    /// Once the earliest rest ends the system shows the activity as stale,
    /// which the widget renders as READY without needing an update.
    private static func staleDate(_ state: WorkoutActivityAttributes.ContentState) -> Date? {
        state.people.compactMap(\.restEndsAt).filter { $0 > .now }.min()
    }
}
