import GRDB

/// A pending change to push: the record's current row, or a tombstone when the
/// row no longer exists. `rev` changes on every write, so a push only clears an
/// entry that wasn't modified while the request was in flight.
struct OutboxEntry: Codable, FetchableRecord, PersistableRecord, Hashable, Sendable {
    static let databaseTableName = "sync_outbox"
    var entity: String
    var recordId: String
    var rev: Int64
}

/// SQLite triggers that queue every write to a synced table into the outbox.
/// Living in the database means no code path can forget to enqueue a change.
enum SyncTriggers {
    static func install(_ db: Database) throws {
        for table in SyncedTypes.tableNames {
            let columns = try db.columns(in: table).map(\.name).filter { $0 != "id" }
            // Updates that change nothing (e.g. saving an unedited form) don't
            // produce a push.
            let changed = columns
                .map { "OLD.\"\($0)\" IS NOT NEW.\"\($0)\"" }
                .joined(separator: " OR ")
            func enqueue(_ row: String) -> String {
                """
                INSERT OR REPLACE INTO sync_outbox(entity, recordId, rev)
                VALUES ('\(table)', \(row).id, (SELECT COALESCE(MAX(rev), 0) + 1 FROM sync_outbox));
                """
            }
            try db.execute(sql: """
                DROP TRIGGER IF EXISTS "sync_\(table)_insert";
                DROP TRIGGER IF EXISTS "sync_\(table)_update";
                DROP TRIGGER IF EXISTS "sync_\(table)_delete";
                CREATE TRIGGER "sync_\(table)_insert" AFTER INSERT ON "\(table)"
                BEGIN \(enqueue("NEW")) END;
                CREATE TRIGGER "sync_\(table)_update" AFTER UPDATE ON "\(table)"
                WHEN \(changed)
                BEGIN \(enqueue("NEW")) END;
                CREATE TRIGGER "sync_\(table)_delete" AFTER DELETE ON "\(table)"
                BEGIN \(enqueue("OLD")) END;
                """)
        }
    }
}
