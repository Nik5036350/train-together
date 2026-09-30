import GRDB
import TrainTogetherCore

/// Read-side fetches. Pure functions of the database, so they back both
/// one-shot reads and observations.
enum Queries {
    static func catalog(_ db: Database) throws -> CatalogSnapshot {
        let rows = try TemplateExercise.order(Column("orderIndex"), Col.rowID).fetchAll(db)
        let byTemplate = Dictionary(grouping: rows, by: \.templateId)
        let templates = try WorkoutTemplate.fetchAll(db)
            .map { RoutineSummary(template: $0, exercises: byTemplate[$0.id] ?? []) }
            .sorted { $0.template.name.localizedStandardCompare($1.template.name) == .orderedAscending }
        let exercises = try Exercise.fetchAll(db)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let profiles = try ExerciseProfile.fetchAll(db)
        return CatalogSnapshot(
            people: try Person.order(Col.rowID).fetchAll(db),
            settings: try AppSettings.fetchOne(db, key: AppSettings.singletonID) ?? AppSettings(),
            exercises: exercises,
            profiles: Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }),
            templates: templates
        )
    }

    static func activeSession(_ db: Database) throws -> ActiveSessionSnapshot? {
        guard let session = try WorkoutSession
            .filter(Column("status") == SessionStatus.active.rawValue)
            .fetchOne(db)
        else { return nil }
        let exercises = try SessionExercise
            .filter(Column("sessionId") == session.id)
            .order(Column("orderIndex"), Col.rowID)
            .fetchAll(db)
        let rows = try SessionExercisePerson
            .filter(exercises.map(\.id).contains(Column("sessionExerciseId")))
            .order(Column("orderIndex"))
            .fetchAll(db)
        let rowsByCard = Dictionary(grouping: rows, by: \.sessionExerciseId)
        let cards = exercises.map { ActiveSessionSnapshot.Card(exercise: $0, people: rowsByCard[$0.id] ?? []) }

        var lastTimes: [String: LastTime] = [:]
        for card in cards {
            for row in card.people {
                if let last = try lastTime(
                    db, personId: row.personId, exerciseId: card.exerciseId(for: row.personId),
                    variant: card.exercise.variant
                ) {
                    lastTimes[ActiveSessionSnapshot.lastTimeKey(cardId: card.id, personId: row.personId)] = last
                }
            }
        }

        let timers = try RestTimer.filter(Column("sessionId") == session.id).fetchAll(db)
        return ActiveSessionSnapshot(
            session: session,
            participantIds: try participantIds(db, sessionId: session.id),
            cards: cards,
            sets: try orderedSets(db, sessionId: session.id),
            timers: Dictionary(timers.map { ($0.personId, $0) }, uniquingKeysWith: { a, _ in a }),
            lastTimes: lastTimes
        )
    }

    /// The most recent finished workout with sets for this person, exercise
    /// and variant.
    static func lastTime(_ db: Database, personId: String, exerciseId: String, variant: Variant) throws -> LastTime? {
        guard let session = try WorkoutSession.fetchOne(db, sql: """
            SELECT s.* FROM workout_session s
            WHERE s.status = 'finished' AND EXISTS (
                SELECT 1 FROM set_entry e
                WHERE e.sessionId = s.id AND e.personId = ? AND e.exerciseId = ? AND e.variant = ?
            )
            ORDER BY s.startTime DESC LIMIT 1
            """, arguments: [personId, exerciseId, variant.rawValue])
        else { return nil }
        let sets = try SetEntry
            .filter(Column("sessionId") == session.id && Column("personId") == personId
                && Column("exerciseId") == exerciseId && Column("variant") == variant.rawValue)
            .order(Column("setIndex"), Col.rowID)
            .fetchAll(db)
        return LastTime(label: session.label ?? Format.weekday(session.startTime), sessionId: session.id, sets: sets)
    }

    static func history(_ db: Database) throws -> [HistoryItem] {
        let sessions = try WorkoutSession
            .filter(Column("status") == SessionStatus.finished.rawValue)
            .order(Column("startTime").desc)
            .fetchAll(db)
        let participants = try SessionParticipant.order(Column("orderIndex")).fetchAll(db)
        let participantsBySession = Dictionary(grouping: participants, by: \.sessionId)
        let aggregates = try Row.fetchAll(db, sql: """
            SELECT e.sessionId, e.personId, COUNT(*) AS sets,
                   SUM(COALESCE(e.weight, 0) * COALESCE(e.reps, 0)) AS volume,
                   MIN(e.rowid) AS firstRow
            FROM set_entry e JOIN workout_session s ON s.id = e.sessionId
            WHERE s.status = 'finished'
            GROUP BY e.sessionId, e.personId
            ORDER BY firstRow
            """)
        let exerciseCounts = try Row.fetchAll(db, sql: """
            SELECT e.sessionId, COUNT(DISTINCT e.exerciseId) AS n
            FROM set_entry e JOIN workout_session s ON s.id = e.sessionId
            WHERE s.status = 'finished'
            GROUP BY e.sessionId
            """)
        var perSession: [String: [(personId: String, sets: Int, volume: Double)]] = [:]
        for row in aggregates {
            perSession[row["sessionId"], default: []].append((row["personId"], row["sets"], row["volume"]))
        }
        let exercisesBySession = Dictionary(
            exerciseCounts.map { (row: Row) -> (String, Int) in (row["sessionId"], row["n"]) },
            uniquingKeysWith: { a, _ in a }
        )
        return sessions.map { session in
            let stats = perSession[session.id] ?? []
            let listed = participantsBySession[session.id]?.map(\.personId) ?? []
            return HistoryItem(
                session: session,
                personIds: listed.isEmpty ? stats.map(\.personId) : listed,
                setCount: stats.reduce(0) { $0 + $1.sets },
                exerciseCount: exercisesBySession[session.id] ?? 0,
                volumeByPerson: Dictionary(stats.map { ($0.personId, $0.volume) }, uniquingKeysWith: +)
            )
        }
    }

    static func workoutDetail(_ db: Database, id: String) throws -> WorkoutDetail? {
        guard let session = try WorkoutSession.fetchOne(db, key: id) else { return nil }
        let sets = try orderedSets(db, sessionId: id)
        let cardOrder = Dictionary(
            try SessionExercise.filter(Column("sessionId") == id).fetchAll(db).map { ($0.id, $0.orderIndex) },
            uniquingKeysWith: { a, _ in a }
        )
        // Rank each exercise by its earliest set: card order first where known,
        // then position in the (timestamp, setIndex, rowid) ordering.
        var rank: [String: (Int, Int)] = [:]
        for (position, set) in sets.enumerated() {
            let key = (set.sessionExerciseId.flatMap { cardOrder[$0] } ?? Int.max, position)
            if let existing = rank[set.exerciseId], existing <= key { continue }
            rank[set.exerciseId] = key
        }
        let listed = try participantIds(db, sessionId: id)
        var inSets: [String] = []
        for set in sets where !inSets.contains(set.personId) { inSets.append(set.personId) }
        return WorkoutDetail(
            session: session,
            personIds: listed.isEmpty ? inSets : listed,
            sets: sets,
            exerciseOrder: rank.sorted { $0.value < $1.value }.map(\.key)
        )
    }

    /// Non-deleted record counts per synced entity (Settings → Data).
    static func recordCounts(_ db: Database) throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for table in SyncedTypes.tableNames {
            counts[table] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \"\(table)\"") ?? 0
        }
        return counts
    }

    static func pendingChanges(_ db: Database) throws -> Int {
        try OutboxEntry.fetchCount(db)
    }

    private static func participantIds(_ db: Database, sessionId: String) throws -> [String] {
        try SessionParticipant
            .filter(Column("sessionId") == sessionId)
            .order(Column("orderIndex"))
            .fetchAll(db)
            .map(\.personId)
    }

    private static func orderedSets(_ db: Database, sessionId: String) throws -> [SetEntry] {
        try SetEntry
            .filter(Column("sessionId") == sessionId)
            .order(sql: "COALESCE(timestamp, 0), setIndex, rowid")
            .fetchAll(db)
    }
}
