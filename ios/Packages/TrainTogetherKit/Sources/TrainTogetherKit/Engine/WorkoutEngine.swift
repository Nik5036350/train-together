import Foundation
import GRDB
import TrainTogetherCore

/// A rule the engine refuses to break, phrased as UI copy (styleguide §28).
public struct EngineError: Error, Equatable, LocalizedError, Sendable {
    public enum Kind: Sendable { case notFound, invalid, activeSessionExists }
    public let kind: Kind
    public let message: String

    static func notFound(_ what: String) -> EngineError {
        EngineError(kind: .notFound, message: "\(what) NOT FOUND")
    }

    static func invalid(_ message: String) -> EngineError {
        EngineError(kind: .invalid, message: message)
    }

    public var errorDescription: String? { message }
}

/// Every mutation of workout data. These are the rules the Rust server used
/// to own (backend/src/services/session.rs, catalog.rs), ported to run on the
/// device. Each public method is one write transaction: it either fully
/// applies or leaves the database untouched, and the sync triggers queue
/// exactly the rows it changed.
public final class WorkoutEngine: Sendable {
    let database: AppDatabase
    let now: @Sendable () -> Int64
    let newID: @Sendable () -> String

    public init(
        database: AppDatabase,
        now: @escaping @Sendable () -> Int64 = { Date().epochMilliseconds },
        newID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.database = database
        self.now = now
        self.newID = newID
    }

    func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try database.writer.write(updates)
    }
}

// MARK: - Shared helpers (ports of the backend's selectors)

extension WorkoutEngine {
    func owner(_ db: Database) throws -> Person? {
        try Person.filter(Column("isOwner") == true).order(Col.rowID).fetchOne(db)
    }

    /// The first active non-owner.
    func partner(_ db: Database) throws -> Person? {
        try Person
            .filter(Column("isOwner") == false && Column("active") == true)
            .order(Col.rowID)
            .fetchOne(db)
    }

    func settings(_ db: Database) throws -> AppSettings {
        if let settings = try AppSettings.fetchOne(db, key: AppSettings.singletonID) {
            return settings
        }
        let settings = AppSettings()
        try settings.insert(db)
        return settings
    }

    /// Who a routine exercise applies to among the workout's participants.
    /// Always owner first, whatever order the participants were chosen in.
    func appliesTo(_ db: Database, assignment: Assignment, participantIds: [String]) throws -> [String] {
        let ownerID = try owner(db)?.id
        let partnerID = try partner(db)?.id
        let wanted: [String?] = switch assignment {
        case .both: [ownerID, partnerID]
        case .owner: [ownerID]
        case .partner: [partnerID]
        }
        return wanted.compactMap { $0 }.filter(participantIds.contains)
    }

    /// The person's own rest overrides the exercise default; 0 falls through,
    /// and 90 s is the last resort.
    func restSeconds(_ db: Database, personId: String, exerciseId: String) throws -> Int {
        let profileID = ExerciseProfile.id(personId: personId, exerciseId: exerciseId)
        if let rest = try ExerciseProfile.fetchOne(db, key: profileID)?.restSeconds, rest != 0 {
            return rest
        }
        let fallback = try Exercise.fetchOne(db, key: exerciseId)?.defaultRestSeconds ?? Exercise.defaultRestSeconds
        return fallback == 0 ? Exercise.defaultRestSeconds : fallback
    }

    /// The exercise a person actually does on a card, after substitution.
    func effectiveExerciseId(_ db: Database, _ se: SessionExercise, personId: String) throws -> String {
        let row = try SessionExercisePerson.fetchOne(
            db, key: SessionExercisePerson.id(sessionExerciseId: se.id, personId: personId)
        )
        return row?.substituteExerciseId ?? se.exerciseId
    }

    func requireSession(_ db: Database, _ id: String) throws -> WorkoutSession {
        guard let session = try WorkoutSession.fetchOne(db, key: id) else { throw EngineError.notFound("WORKOUT") }
        return session
    }

    func requireSessionExercise(_ db: Database, _ id: String) throws -> SessionExercise {
        guard let se = try SessionExercise.fetchOne(db, key: id) else { throw EngineError.notFound("EXERCISE") }
        return se
    }

    func requireSet(_ db: Database, _ id: String) throws -> SetEntry {
        guard let set = try SetEntry.fetchOne(db, key: id) else { throw EngineError.notFound("SET") }
        return set
    }

    func people(_ db: Database, onCard sessionExerciseId: String) throws -> [SessionExercisePerson] {
        try SessionExercisePerson
            .filter(Column("sessionExerciseId") == sessionExerciseId)
            .order(Column("orderIndex"))
            .fetchAll(db)
    }

    func participantIds(_ db: Database, sessionId: String) throws -> [String] {
        try SessionParticipant
            .filter(Column("sessionId") == sessionId)
            .order(Column("orderIndex"))
            .fetchAll(db)
            .map(\.personId)
    }

    func activeSession(_ db: Database) throws -> WorkoutSession? {
        try WorkoutSession.filter(Column("status") == SessionStatus.active.rawValue).fetchOne(db)
    }

    /// Blank strings are stored as nil.
    func nonBlank(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}
