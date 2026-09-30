import Foundation
import TrainTogetherCore
import TrainTogetherKit
import UserNotifications

/// Local "rest over" notifications, one pending per person ("rest-{personId}"),
/// kept in step with the rest timers. In the foreground the banner is
/// suppressed — the app's own timer state, haptic and announcement cover it.
@MainActor
final class RestAlerts: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    /// personId → the rest end we scheduled.
    private var scheduled: [String: Int64] = [:]
    private var askedForPermission = false

    func install() {
        center.delegate = self
    }

    func sync(snapshot: AppSnapshot, enabled: Bool) {
        let timers = enabled ? snapshot.active?.timers ?? [:] : [:]
        let now = Date().epochMilliseconds
        let live = timers.filter { $0.value.endsAt > now }

        let stale = scheduled.keys.filter { live[$0]?.endsAt != scheduled[$0] }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale.map(Self.identifier))
            for id in stale { scheduled[id] = nil }
        }
        guard !live.isEmpty else { return }
        if !askedForPermission {
            askedForPermission = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        for (personId, timer) in live where scheduled[personId] != timer.endsAt {
            let content = UNMutableNotificationContent()
            let name = snapshot.catalog.person(personId)?.name.uppercased() ?? ""
            content.title = "\(name) — READY"
            let card = snapshot.active?.card(timer.sessionExerciseId)
            content.body = card.flatMap { snapshot.catalog.exercise($0.exerciseId(for: personId))?.name } ?? "Rest is over"
            content.sound = .default
            let seconds = max(1, Double(timer.endsAt - now) / 1000)
            let request = UNNotificationRequest(
                identifier: Self.identifier(personId),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            )
            center.add(request)
            scheduled[personId] = timer.endsAt
        }
    }

    private static func identifier(_ personId: String) -> String { "rest-\(personId)" }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
