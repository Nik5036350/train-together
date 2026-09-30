import GRDB
import TrainTogetherCore

public struct RestoreReport: Equatable, Sendable {
    public var inserted: Int
    /// Records whose parent wasn't in the server data (never fatal).
    public var orphansDropped: Int
    /// Records that didn't decode (e.g. written by a newer app version).
    public var undecodable: Int
}

/// Replaces the phone's data with a server snapshot.
enum Restorer {
    /// Runs inside one write transaction: wipes every synced table and the rest
    /// timers, inserts the latest version of each record parents-first, and
    /// leaves the outbox empty (the phone now matches the server).
    static func apply(_ changes: [PulledChange], _ db: Database) throws -> RestoreReport {
        try RestTimer.deleteAll(db)
        for type in SyncedTypes.all.reversed() {
            _ = try type.deleteAll(db)
        }

        // The pull is in seq order; keep each record's latest version.
        var latest: [String: [String: PulledChange]] = [:]
        for change in changes {
            latest[change.entity, default: [:]][change.id] = change
        }

        var report = RestoreReport(inserted: 0, orphansDropped: 0, undecodable: 0)
        var inserted: [String: Set<String>] = [:]
        for type in SyncedTypes.all {
            let entity = type.entityName
            let records = (latest[entity].map { Array($0.values) } ?? []).sorted { $0.seq < $1.seq }
            for change in records where !change.deleted {
                guard let data = change.data else { continue }
                do {
                    guard let id = try insert(type, data, db, inserted: inserted) else {
                        report.orphansDropped += 1
                        continue
                    }
                    inserted[entity, default: []].insert(id)
                    report.inserted += 1
                } catch is DecodingError {
                    report.undecodable += 1
                }
            }
        }

        try OutboxEntry.deleteAll(db)
        return report
    }

    /// Decodes and inserts one record; returns nil (and inserts nothing) when
    /// a required parent is missing.
    private static func insert<R: SyncEntity & FetchableRecord & PersistableRecord>(
        _ type: R.Type, _ data: JSONValue, _ db: Database, inserted: [String: Set<String>]
    ) throws -> String? {
        var record = try data.decoded(as: R.self)
        func has(_ parent: any SyncEntity.Type, _ id: String) -> Bool {
            inserted[parent.entityName]?.contains(id) ?? false
        }
        switch record {
        case let r as TemplateExercise where !has(WorkoutTemplate.self, r.templateId): return nil
        case let r as SessionParticipant where !has(WorkoutSession.self, r.sessionId): return nil
        case let r as SessionExercise where !has(WorkoutSession.self, r.sessionId): return nil
        case let r as SessionExercisePerson where !has(SessionExercise.self, r.sessionExerciseId): return nil
        case var r as SetEntry:
            if !has(WorkoutSession.self, r.sessionId) { return nil }
            // A set whose card is gone stays in history, detached like the
            // legacy sets that never had one.
            if let seID = r.sessionExerciseId, !has(SessionExercise.self, seID) {
                r.sessionExerciseId = nil
                record = r as! R
            }
        default:
            break
        }
        try record.insert(db)
        return record.id
    }
}
