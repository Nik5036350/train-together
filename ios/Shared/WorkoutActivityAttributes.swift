import ActivityKit
import Foundation

/// The rest-timer Live Activity (Lock Screen and Dynamic Island). Shared by the
/// app, which starts and updates it locally, and the widget extension, which
/// renders it. Free signing has no push, so every update comes from the app.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The exercise the workout is on.
        var exerciseName: String
        /// Whose turn it is on that exercise (nil with one person).
        var turn: Participant?
        var people: [Participant]
    }

    struct Participant: Codable, Hashable {
        var name: String
        var initials: String
        /// A PersonColor key.
        var color: String
        var restStartedAt: Date?
        var restEndsAt: Date?
    }

    var sessionId: String
    var workoutName: String
    var startedAt: Date
}
