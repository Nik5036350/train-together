import Foundation
import GRDB
import TrainTogetherCore

/// What the Workout tab shows around the routines: this week's training days
/// and the routine that's up next.
public struct HomeSnapshot: Equatable, Sendable {
    /// Start of each day of this week (epoch ms), from the calendar's first
    /// weekday.
    public var weekDays: [Int64]
    /// Per day of `weekDays`: whether a finished workout started that day.
    public var trained: [Bool]
    /// Index of today in `weekDays`.
    public var today: Int
    public var workoutsThisWeek: Int
    /// Start of each routine's latest finished workout.
    public var lastDone: [String: Int64]
    /// The routine to suggest: the first never done (in list order), else the
    /// one done longest ago. Routines without exercises are never suggested.
    public var nextUp: String?

    public static let empty = HomeSnapshot(
        weekDays: [], trained: [], today: 0, workoutsThisWeek: 0, lastDone: [:], nextUp: nil
    )
}

extension Queries {
    static func home(_ db: Database, now: Int64, calendar: Calendar) throws -> HomeSnapshot {
        let weekStart = Date(epochMilliseconds: Analytics.weekStart(now, calendar: calendar))
        let days = (0...7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)?.epochMilliseconds ?? 0 }
        let weekDays = Array(days.prefix(7))
        let weekEnd = days[7]

        var trained = Array(repeating: false, count: 7)
        var workoutsThisWeek = 0
        var lastDone: [String: Int64] = [:]
        let finished = try WorkoutSession.filter(Column("status") == SessionStatus.finished.rawValue).fetchAll(db)
        for session in finished {
            if session.startTime >= weekDays[0], session.startTime < weekEnd,
               let day = weekDays.lastIndex(where: { $0 <= session.startTime }) {
                trained[day] = true
                workoutsThisWeek += 1
            }
            if let templateId = session.templateId {
                lastDone[templateId] = max(lastDone[templateId] ?? .min, session.startTime)
            }
        }

        // The same order as the routine list (by name).
        let withExercises = Set(try String.fetchAll(db, sql: "SELECT DISTINCT templateId FROM template_exercise"))
        let routines = try WorkoutTemplate.fetchAll(db)
            .filter { withExercises.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let nextUp = routines.first { lastDone[$0.id] == nil }
            ?? routines.min { (lastDone[$0.id] ?? 0) < (lastDone[$1.id] ?? 0) }

        return HomeSnapshot(
            weekDays: weekDays, trained: trained,
            today: weekDays.lastIndex { $0 <= now } ?? 0,
            workoutsThisWeek: workoutsThisWeek, lastDone: lastDone, nextUp: nextUp?.id
        )
    }
}
