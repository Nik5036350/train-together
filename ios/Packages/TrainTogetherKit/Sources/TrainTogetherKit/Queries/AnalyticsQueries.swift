import Foundation
import GRDB
import TrainTogetherCore

/// An exercise in the analytics list.
public struct ExerciseSummary: Equatable, Sendable, Identifiable {
    public var exercise: Exercise
    /// The variant the row reflects (the one trained most).
    public var variant: Variant
    public var sessionCount: Int
    public var lastDate: Int64
    /// Best top-set weight per person.
    public var bestTopWeight: [String: Double]
    /// Top-set weight of the last sessions per person, oldest first.
    public var sparkline: [String: [Double]]
    /// Someone set a record in the most recent session.
    public var recordLastTime: Bool
    public var id: String { exercise.id }
}

public struct WeekBucket: Equatable, Sendable, Identifiable {
    /// Start of the week (epoch ms).
    public var start: Int64
    public var workouts: Int
    /// Σ weight × reps per person, each in their own unit.
    public var volumeByPerson: [String: Double]
    public var id: Int64 { start }
}

public struct TrainingOverview: Equatable, Sendable {
    public var workouts30: Int
    public var sets30: Int
    public var records30: Int
    public var lastWorkout: Int64?
    /// The last 12 weeks, oldest first.
    public var weeks: [WeekBucket]
    /// Newest first.
    public var recentRecords: [RecordEvent]
}

public struct AnalyticsSnapshot: Equatable, Sendable {
    /// Library exercises with history, most recently trained first.
    public var exercises: [ExerciseSummary]
    public var overview: TrainingOverview
}

/// Everything the progress screen for one exercise shows.
public struct ExerciseProgress: Equatable, Sendable {
    public var exercise: Exercise
    /// Variants with history, most sessions first.
    public var variants: [Variant]
    /// Per variant, per person: session points, oldest first.
    public var points: [Variant: [String: [SessionPoint]]]
    /// Sessions that trained this exercise, newest first.
    public var sessions: [Session]

    public struct Session: Equatable, Sendable, Identifiable {
        public var sessionId: String
        public var name: String
        public var date: Int64
        /// Per person: their points in this session (any variant).
        public var byPerson: [String: [SessionPoint]]
        public var id: String { sessionId }
    }

    public func series(variant: Variant, personId: String) -> [SessionPoint] {
        points[variant]?[personId] ?? []
    }
}

extension Queries {
    /// Every set from a finished workout, as analytics reads it.
    static func analyticsSets(_ db: Database, exerciseId: String? = nil) throws -> [AnalyticsSet] {
        var sql = """
            SELECT e.exerciseId, e.personId, e.sessionId, e.variant, s.startTime, e.weight, e.reps, e.duration
            FROM set_entry e JOIN workout_session s ON s.id = e.sessionId
            WHERE s.status = 'finished'
            """
        var arguments: StatementArguments = []
        if let exerciseId {
            sql += " AND e.exerciseId = ?"
            arguments = [exerciseId]
        }
        return try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
            AnalyticsSet(
                exerciseId: row["exerciseId"], personId: row["personId"], sessionId: row["sessionId"],
                variant: Variant(rawValue: row["variant"]) ?? .normal, date: row["startTime"],
                weight: row["weight"], reps: row["reps"], duration: row["duration"]
            )
        }
    }

    /// Per variant, per person session points for one exercise's sets.
    static func points(_ sets: [AnalyticsSet], people: [String: Person]) -> [Variant: [String: [SessionPoint]]] {
        var result: [Variant: [String: [SessionPoint]]] = [:]
        for (variant, variantSets) in Dictionary(grouping: sets, by: \.variant) {
            for (personId, personSets) in Dictionary(grouping: variantSets, by: \.personId) {
                // Sets of someone no longer on the phone still chart, unnamed.
                let person = people[personId]
                    ?? Person(id: personId, name: "", initials: "", color: "", unit: .kg, isOwner: false)
                result[variant, default: [:]][personId] = Analytics.sessionPoints(personSets, person: person)
            }
        }
        return result
    }

    static func analytics(_ db: Database, now: Int64, calendar: Calendar) throws -> AnalyticsSnapshot {
        let people = Dictionary(try Person.fetchAll(db).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let library = Dictionary(try Exercise.fetchAll(db).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let sets = try analyticsSets(db)
        let monthAgo = now - 30 * 86_400_000

        // Per-exercise items: library exercises only (removed ones stay in
        // history and in the totals below).
        var summaries: [ExerciseSummary] = []
        var records: [RecordEvent] = []
        for (exerciseId, exerciseSets) in Dictionary(grouping: sets, by: \.exerciseId) {
            guard let exercise = library[exerciseId] else { continue }
            let byVariant = points(exerciseSets, people: people)
            for series in byVariant.values.flatMap(\.values) {
                records += Analytics.recordEvents(series, exercise: exercise)
            }
            let variant = byVariant.max { a, b in
                Set(a.value.values.flatMap { $0.map(\.sessionId) }).count
                    < Set(b.value.values.flatMap { $0.map(\.sessionId) }).count
            }?.key ?? .normal
            let series = byVariant[variant] ?? [:]
            let sessionIDs = Set(exerciseSets.map(\.sessionId))
            let lastDate = exerciseSets.map(\.date).max() ?? 0
            let lastSession = exerciseSets.filter { $0.date == lastDate }.map(\.sessionId).max()
            summaries.append(ExerciseSummary(
                exercise: exercise, variant: variant, sessionCount: sessionIDs.count, lastDate: lastDate,
                bestTopWeight: series.compactMapValues { $0.compactMap(\.topWeight).max() },
                sparkline: series.mapValues { Array($0.compactMap(\.topWeight).suffix(12)) },
                recordLastTime: records.contains { $0.point.exerciseId == exerciseId && $0.point.sessionId == lastSession }
            ))
        }
        summaries.sort { ($0.lastDate, $0.exercise.name) > ($1.lastDate, $1.exercise.name) }
        records.sort { ($0.point.date, $0.point.id) > ($1.point.date, $1.point.id) }

        // Totals match the History ledger: every finished workout counts.
        let history = try history(db)
        let recent = history.filter { $0.session.startTime >= monthAgo }
        let thisWeek = Analytics.weekStart(now, calendar: calendar)
        let weekStarts = (0..<12).reversed().compactMap { back -> Int64? in
            calendar.date(byAdding: .weekOfYear, value: -back, to: Date(epochMilliseconds: thisWeek))?.epochMilliseconds
        }
        var buckets = Dictionary(uniqueKeysWithValues: weekStarts.map { ($0, WeekBucket(start: $0, workouts: 0, volumeByPerson: [:])) })
        for item in history {
            let week = Analytics.weekStart(item.session.startTime, calendar: calendar)
            guard buckets[week] != nil else { continue }
            buckets[week]!.workouts += 1
            for (personId, volume) in item.volumeByPerson {
                buckets[week]!.volumeByPerson[personId, default: 0] += volume
            }
        }

        return AnalyticsSnapshot(
            exercises: summaries,
            overview: TrainingOverview(
                workouts30: recent.count,
                sets30: recent.reduce(0) { $0 + $1.setCount },
                records30: records.filter { $0.point.date >= monthAgo }.count,
                lastWorkout: history.first?.session.startTime,
                weeks: weekStarts.compactMap { buckets[$0] },
                recentRecords: Array(records.prefix(6))
            )
        )
    }

    static func exerciseProgress(_ db: Database, exerciseId: String) throws -> ExerciseProgress? {
        guard let exercise = try Exercise.fetchOne(db, key: exerciseId) else { return nil }
        let people = Dictionary(try Person.fetchAll(db).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let sets = try analyticsSets(db, exerciseId: exerciseId)
        let byVariant = points(sets, people: people)
        let sessionCounts = byVariant.mapValues { Set($0.values.flatMap { $0.map(\.sessionId) }).count }
        let variants = sessionCounts.sorted { ($0.value, $1.key.rawValue) > ($1.value, $0.key.rawValue) }.map(\.key)

        let names = Dictionary(
            try WorkoutSession.filter(Set(sets.map(\.sessionId)).contains(Column("id"))).fetchAll(db)
                .map { ($0.id, $0.displayName) },
            uniquingKeysWith: { a, _ in a }
        )
        let allPoints = byVariant.values.flatMap { $0.values.flatMap { $0 } }
        let sessions = Dictionary(grouping: allPoints, by: \.sessionId).map { sessionId, points in
            ExerciseProgress.Session(
                sessionId: sessionId, name: names[sessionId] ?? "Workout", date: points.first?.date ?? 0,
                byPerson: Dictionary(grouping: points, by: \.personId)
            )
        }
        .sorted { ($0.date, $0.sessionId) > ($1.date, $1.sessionId) }

        return ExerciseProgress(exercise: exercise, variants: variants, points: byVariant, sessions: sessions)
    }
}
