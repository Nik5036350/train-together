import Foundation
import GRDB
import TrainTogetherCore

// MARK: - Workout lifecycle

extension WorkoutEngine {
    /// Starts a workout from a routine, or an empty "Quick workout" when
    /// `templateId` is nil. Only one workout can be active: the caller must
    /// resume, finish or discard the current one first.
    @discardableResult
    public func startSession(templateId: String?, participantIds: [String], loggingStyle: LoggingMode? = nil) throws -> String {
        try write { db in
            if try activeSession(db) != nil {
                throw EngineError(kind: .activeSessionExists, message: "A WORKOUT IS ALREADY IN PROGRESS")
            }
            if participantIds.isEmpty { throw EngineError.invalid("PICK WHO IS TRAINING") }
            for id in participantIds {
                if try !Person.exists(db, key: id) { throw EngineError.notFound("PERSON") }
            }

            let template = try templateId.map { id in
                guard let t = try WorkoutTemplate.fetchOne(db, key: id) else { throw EngineError.notFound("ROUTINE") }
                return t
            }
            let style = try loggingStyle ?? template?.defaultMode ?? settings(db).defaultLoggingStyle
            let session = WorkoutSession(
                id: newID(), templateId: template?.id, name: template?.name ?? "Quick workout",
                startTime: now(), loggingStyle: style, status: .active
            )
            try session.insert(db)
            for (i, personId) in participantIds.enumerated() {
                try SessionParticipant(sessionId: session.id, personId: personId, orderIndex: i).insert(db)
            }

            guard let template else { return session.id }
            let rows = try TemplateExercise
                .filter(Column("templateId") == template.id)
                .order(Column("orderIndex"), Col.rowID)
                .fetchAll(db)
            var order = 0
            for row in rows {
                // Exercises that apply to nobody in this workout are left out.
                let people = try appliesTo(db, assignment: row.assignment, participantIds: participantIds)
                if people.isEmpty { continue }
                let se = SessionExercise(
                    id: newID(), sessionId: session.id, exerciseId: row.exerciseId,
                    loggingMode: row.defaultLoggingMode ?? style, activePersonId: people[0],
                    addedDuringSession: false, orderIndex: order
                )
                try se.insert(db)
                order += 1
                for (i, personId) in people.enumerated() {
                    try SessionExercisePerson(sessionExerciseId: se.id, personId: personId, orderIndex: i).insert(db)
                }
            }
            return session.id
        }
    }

    public func finishSession(id: String) throws {
        try write { db in
            var session = try requireSession(db, id)
            guard session.status == .active else { throw EngineError.invalid("WORKOUT IS ALREADY FINISHED") }
            session.status = .finished
            session.endTime = now()
            try session.update(db)
            // Rest timers are transient countdowns — meaningless in history.
            try RestTimer.filter(Column("sessionId") == id).deleteAll(db)
        }
    }

    /// Throws away the workout in progress and everything logged in it.
    public func discardActiveSession() throws {
        try write { db in
            if let active = try activeSession(db) { try deleteSessionGraph(db, active.id) }
        }
    }

    /// Deletes a finished workout. The active one is discarded, not deleted.
    public func deleteSession(id: String) throws {
        try write { db in
            let session = try requireSession(db, id)
            if session.status == .active {
                throw EngineError.invalid("FINISH THE WORKOUT BEFORE DELETING IT")
            }
            try deleteSessionGraph(db, id)
        }
    }

    func deleteSessionGraph(_ db: Database, _ sessionId: String) throws {
        try RestTimer.filter(Column("sessionId") == sessionId).deleteAll(db)
        try SetEntry.filter(Column("sessionId") == sessionId).deleteAll(db)
        let cardIDs = try SessionExercise.filter(Column("sessionId") == sessionId).fetchAll(db).map(\.id)
        try SessionExercisePerson.filter(cardIDs.contains(Column("sessionExerciseId"))).deleteAll(db)
        try SessionExercise.filter(Column("sessionId") == sessionId).deleteAll(db)
        try SessionParticipant.filter(Column("sessionId") == sessionId).deleteAll(db)
        _ = try WorkoutSession.deleteOne(db, key: sessionId)
    }
}

// MARK: - Logging sets

extension WorkoutEngine {
    /// Logs a set, passes the turn if the card's mode says so, marks the
    /// person logged and (re)starts their rest timer. Returns the new set id.
    @discardableResult
    public func logSet(
        sessionExerciseId: String, personId: String, values: SetValues,
        setType: String = "working", variant: Variant? = nil
    ) throws -> String {
        try write { db in
            var se = try requireSessionExercise(db, sessionExerciseId)
            let session = try requireSession(db, se.sessionId)
            guard session.status == .active else { throw EngineError.invalid("WORKOUT IS FINISHED") }
            let people = try people(db, onCard: se.id)
            guard people.contains(where: { $0.personId == personId }) else {
                throw EngineError.invalid("PERSON IS NOT ON THIS EXERCISE")
            }
            let exerciseId = try effectiveExerciseId(db, se, personId: personId)

            let set = SetEntry(
                id: newID(), sessionId: session.id, sessionExerciseId: se.id, exerciseId: exerciseId,
                personId: personId,
                setIndex: try nextSetIndex(db, sessionId: session.id, sessionExerciseId: se.id, personId: personId),
                weight: values.weight, reps: values.reps, duration: values.duration, setType: setType,
                // Each variant keeps its own history line: stamp the card's
                // current variant unless the caller pins one.
                variant: variant ?? se.variant, timestamp: now(), note: nonBlank(values.note)
            )
            try set.insert(db)

            // Alternate and turns hand the turn to the other person; in
            // independent mode it stays with whoever logged.
            let others = people.map(\.personId).filter { $0 != personId }
            se.activePersonId = se.loggingMode.passesTurn && !others.isEmpty ? others[0] : personId
            try se.update(db)

            if var row = people.first(where: { $0.personId == personId }), row.status != .logged {
                row.status = .logged
                try row.update(db)
            }

            try RestTimer(
                sessionId: session.id, personId: personId, sessionExerciseId: se.id, startedAt: now(),
                durationSeconds: try restSeconds(db, personId: personId, exerciseId: exerciseId)
            ).save(db)
            return set.id
        }
    }

    /// Undoes a just-logged set: the turn returns to that person and their
    /// rest timer is cleared if it was started by this exercise.
    public func undoSet(id: String) throws {
        try write { db in
            let removed = try requireSet(db, id)
            try removed.delete(db)
            if let seID = removed.sessionExerciseId, var se = try SessionExercise.fetchOne(db, key: seID) {
                se.activePersonId = removed.personId
                try se.update(db)
            }
            if let timer = try RestTimer.fetchOne(db, key: ["sessionId": removed.sessionId, "personId": removed.personId]),
               timer.sessionExerciseId == removed.sessionExerciseId {
                try timer.delete(db)
            }
            try afterSetRemoved(db, removed)
        }
    }

    /// Replaces a set's values (active or finished workouts).
    public func editSet(id: String, values: SetValues) throws {
        try write { db in
            var set = try requireSet(db, id)
            set.weight = values.weight
            set.reps = values.reps
            set.duration = values.duration
            set.note = nonBlank(values.note)
            try set.update(db)
        }
    }

    public func deleteSet(id: String) throws {
        try write { db in
            let removed = try requireSet(db, id)
            try removed.delete(db)
            try afterSetRemoved(db, removed)
        }
    }

    /// Moves a set logged for the wrong person to the other one.
    public func reassignSet(id: String, toPersonId: String) throws {
        try write { db in
            var set = try requireSet(db, id)
            guard set.personId != toPersonId else { return }
            guard try Person.exists(db, key: toPersonId) else { throw EngineError.notFound("PERSON") }
            let before = set
            set.personId = toPersonId
            // Use the new person's effective exercise when they're on the card
            // (they may have substituted it). Legacy history sets have no card
            // and keep their exercise.
            if let seID = set.sessionExerciseId, let se = try SessionExercise.fetchOne(db, key: seID),
               try SessionExercisePerson.exists(db, key: SessionExercisePerson.id(sessionExerciseId: seID, personId: toPersonId)) {
                set.exerciseId = try effectiveExerciseId(db, se, personId: toPersonId)
            }
            // Append to the target's group; renumbering below sorts it into place.
            set.setIndex = Int.max / 2
            try set.update(db)
            try afterSetRemoved(db, before)
            try renumber(db, set)
            try recomputeStatus(db, set)
        }
    }

    /// Next storage index in a person's group. max+1 rather than a count, so
    /// indexes stay unique even if a group ever has gaps.
    private func nextSetIndex(_ db: Database, sessionId: String, sessionExerciseId: String, personId: String) throws -> Int {
        let maxIndex = try Int.fetchOne(db, sql: """
            SELECT MAX(setIndex) FROM set_entry
            WHERE sessionId = ? AND sessionExerciseId = ? AND personId = ?
            """, arguments: [sessionId, sessionExerciseId, personId])
        return maxIndex.map { $0 + 1 } ?? 0
    }

    private func afterSetRemoved(_ db: Database, _ removed: SetEntry) throws {
        try renumber(db, removed)
        try recomputeStatus(db, removed)
    }

    /// Keeps setIndex contiguous in the set's group: (session, card, person)
    /// in an active workout, (session, exercise, person) in a finished one —
    /// legacy history sets have no card. Variants share one sequence.
    func renumber(_ db: Database, _ member: SetEntry) throws {
        let session = try requireSession(db, member.sessionId)
        var request = SetEntry
            .filter(Column("sessionId") == member.sessionId && Column("personId") == member.personId)
        if session.status == .active {
            request = request.filter(Column("sessionExerciseId") == member.sessionExerciseId)
        } else {
            request = request.filter(Column("exerciseId") == member.exerciseId)
        }
        let group = try request
            .order(sql: "COALESCE(timestamp, 0), setIndex, rowid")
            .fetchAll(db)
        for (index, var set) in group.enumerated() where set.setIndex != index {
            set.setIndex = index
            try set.update(db)
        }
    }

    /// A person's status on a card follows their sets: skipped stays skipped,
    /// otherwise "logged" while they have at least one set, else pending.
    func recomputeStatus(_ db: Database, _ member: SetEntry) throws {
        guard let seID = member.sessionExerciseId,
              var row = try SessionExercisePerson.fetchOne(
                db, key: SessionExercisePerson.id(sessionExerciseId: seID, personId: member.personId)
              ),
              row.status != .skipped
        else { return }
        let hasSets = try SetEntry
            .filter(Column("sessionExerciseId") == seID && Column("personId") == member.personId)
            .fetchCount(db) > 0
        let status: PersonStatus = hasSets ? .logged : .pending
        if row.status != status {
            row.status = status
            try row.update(db)
        }
    }
}

// MARK: - Cards: turns, skips, substitution, modes

extension WorkoutEngine {
    /// Adds a library exercise to the workout in progress. Returns the new
    /// card's id, or nil when the exercise applies to nobody training.
    @discardableResult
    public func addSessionExercise(sessionId: String, exerciseId: String, assignment: Assignment = .both) throws -> String? {
        try write { db in
            let session = try requireSession(db, sessionId)
            let people = try appliesTo(
                db, assignment: assignment, participantIds: try participantIds(db, sessionId: sessionId)
            )
            if people.isEmpty { return nil }
            let maxOrder = try Int.fetchOne(
                db, sql: "SELECT MAX(orderIndex) FROM session_exercise WHERE sessionId = ?", arguments: [sessionId]
            )
            let se = SessionExercise(
                id: newID(), sessionId: sessionId, exerciseId: exerciseId,
                loggingMode: session.loggingStyle, activePersonId: people[0],
                addedDuringSession: true, orderIndex: maxOrder.map { $0 + 1 } ?? 0
            )
            try se.insert(db)
            for (i, personId) in people.enumerated() {
                try SessionExercisePerson(sessionExerciseId: se.id, personId: personId, orderIndex: i).insert(db)
            }
            return se.id
        }
    }

    /// Passes the turn without logging, to the first other person who hasn't
    /// skipped the exercise.
    public func skipTurn(sessionExerciseId: String, personId: String) throws {
        try write { db in
            var se = try requireSessionExercise(db, sessionExerciseId)
            let people = try people(db, onCard: se.id)
            if let next = people.first(where: { $0.personId != personId && $0.status != .skipped }) {
                se.activePersonId = next.personId
                try se.update(db)
            }
        }
    }

    /// A person skips the exercise entirely (optionally saying why). The turn
    /// moves to the first other person, whatever their status.
    public func skipExercise(sessionExerciseId: String, personId: String, reason: String?) throws {
        try write { db in
            var se = try requireSessionExercise(db, sessionExerciseId)
            let people = try people(db, onCard: se.id)
            guard var row = people.first(where: { $0.personId == personId }) else {
                throw EngineError.invalid("PERSON IS NOT ON THIS EXERCISE")
            }
            if let next = people.first(where: { $0.personId != personId }) {
                se.activePersonId = next.personId
                try se.update(db)
            }
            row.status = .skipped
            row.skipReason = nonBlank(reason)
            try row.update(db)
        }
    }

    /// "Doing X instead today". Nil clears the substitution. Affects sets
    /// logged from now on.
    public func substituteExercise(sessionExerciseId: String, personId: String, substituteExerciseId: String?) throws {
        try updatePersonRow(sessionExerciseId, personId) { $0.substituteExerciseId = substituteExerciseId }
    }

    public func setPersonStatus(sessionExerciseId: String, personId: String, status: PersonStatus) throws {
        try updatePersonRow(sessionExerciseId, personId) { $0.status = status }
    }

    public func setLoggingMode(sessionExerciseId: String, mode: LoggingMode) throws {
        try updateCard(sessionExerciseId) { $0.loggingMode = mode }
    }

    public func setVariant(sessionExerciseId: String, variant: Variant) throws {
        try updateCard(sessionExerciseId) { $0.variant = variant }
    }

    /// Tapping an inactive person's row makes it their turn.
    public func setActiveRow(sessionExerciseId: String, personId: String) throws {
        try updateCard(sessionExerciseId) { $0.activePersonId = personId }
    }

    private func updateCard(_ id: String, _ change: (inout SessionExercise) -> Void) throws {
        try write { db in
            var se = try requireSessionExercise(db, id)
            change(&se)
            try se.update(db)
        }
    }

    private func updatePersonRow(_ seID: String, _ personId: String, _ change: (inout SessionExercisePerson) -> Void) throws {
        try write { db in
            guard var row = try SessionExercisePerson.fetchOne(
                db, key: SessionExercisePerson.id(sessionExerciseId: seID, personId: personId)
            ) else { throw EngineError.invalid("PERSON IS NOT ON THIS EXERCISE") }
            change(&row)
            try row.update(db)
        }
    }
}

// MARK: - Rest timer controls

extension WorkoutEngine {
    /// +30s: adds to the remaining rest, or starts a fresh countdown of
    /// `seconds` if rest is already over.
    public func adjustRest(sessionId: String, personId: String, by seconds: Int) throws {
        try write { db in
            guard var timer = try RestTimer.fetchOne(db, key: ["sessionId": sessionId, "personId": personId]) else { return }
            let now = now()
            if timer.endsAt > now {
                timer.durationSeconds = max(0, timer.durationSeconds + seconds)
            } else {
                timer.startedAt = now
                timer.durationSeconds = max(0, seconds)
            }
            try timer.update(db)
        }
    }

    /// Ends the rest now, so the person shows as ready.
    public func skipRest(sessionId: String, personId: String) throws {
        try write { db in
            guard var timer = try RestTimer.fetchOne(db, key: ["sessionId": sessionId, "personId": personId]) else { return }
            timer.durationSeconds = max(0, Int((now() - timer.startedAt) / 1000))
            try timer.update(db)
        }
    }
}
