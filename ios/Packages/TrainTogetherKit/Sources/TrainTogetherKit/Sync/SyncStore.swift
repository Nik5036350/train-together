import GRDB
import TrainTogetherCore

/// Sync bookkeeping kept in the database, so it commits atomically with the
/// data it describes.
enum SyncState {
    /// The server store this phone syncs with; a different id means the
    /// server lost our records.
    static let storeID = "storeId"
    /// The server's change counter as of our last exchange.
    static let lastServerSeq = "lastServerSeq"
    /// Highest `updatedAt` stamp used or seen; stamps only move forward.
    static let lastStamp = "lastStamp"

    static func get(_ db: Database, _ key: String) throws -> String? {
        try String.fetchOne(db, sql: "SELECT value FROM sync_state WHERE key = ?", arguments: [key])
    }

    static func set(_ db: Database, _ key: String, _ value: String?) throws {
        if let value {
            try db.execute(sql: "INSERT OR REPLACE INTO sync_state(key, value) VALUES (?, ?)", arguments: [key, value])
        } else {
            try db.execute(sql: "DELETE FROM sync_state WHERE key = ?", arguments: [key])
        }
    }

    static func int(_ db: Database, _ key: String) throws -> Int64? {
        try get(db, key).flatMap { Int64($0) }
    }

    /// Reserves `count` strictly increasing stamps, never below the wall clock
    /// and always above anything used before — so a phone whose clock jumped
    /// back still wins last-writer-wins against its own earlier writes.
    static func reserveStamps(_ db: Database, count: Int, now: Int64) throws -> [Int64] {
        let first = max(now, (try int(db, lastStamp) ?? 0) + 1)
        let stamps = (0..<Int64(count)).map { first + $0 }
        try set(db, lastStamp, String(stamps.last ?? first - 1))
        return stamps
    }

    static func raiseStamp(_ db: Database, atLeast value: Int64) throws {
        if value > (try int(db, lastStamp) ?? 0) {
            try set(db, lastStamp, String(value))
        }
    }

    /// Queues every synced row, e.g. after the server lost its data.
    static func requeueAll(_ db: Database) throws {
        for table in SyncedTypes.tableNames {
            try db.execute(sql: """
                INSERT OR REPLACE INTO sync_outbox(entity, recordId, rev)
                SELECT '\(table)', id, (SELECT COALESCE(MAX(rev), 0) + 1 FROM sync_outbox) FROM "\(table)"
                """)
        }
    }

    /// The payload for a queued change: the row's JSON, or nil if the row was
    /// deleted (a tombstone). Unknown entities read as deleted.
    static func payload(_ db: Database, entity: String, id: String) throws -> JSONValue? {
        guard let type = SyncedTypes.type(named: entity) else { return nil }
        return try payload(db, type, id: id)
    }

    private static func payload<R: SyncEntity & FetchableRecord & PersistableRecord>(
        _ db: Database, _ type: R.Type, id: String
    ) throws -> JSONValue? {
        try R.fetchOne(db, key: id).map(JSONValue.encoding)
    }
}
