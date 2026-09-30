import Foundation
import GRDB
import TrainTogetherCore

/// The on-device SQLite database: schema, migrations and the sync outbox.
public final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// A throwaway database for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    /// The app's database file. WAL mode (DatabasePool) lets observations read
    /// while the engine writes.
    public static func onDisk(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        return try AppDatabase(DatabasePool(path: url.path))
    }

    var reader: any DatabaseReader { writer }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

        migrator.registerMigration("v1") { db in
            try db.create(table: Person.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("initials", .text).notNull()
                t.column("color", .text).notNull()
                t.column("unit", .text).notNull()
                t.column("isOwner", .boolean).notNull()
                t.column("active", .boolean).notNull()
            }
            try db.create(table: AppSettings.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("defaultParticipants", .text).notNull()
                t.column("defaultLoggingStyle", .text).notNull()
                t.column("coupleModeEnabled", .boolean).notNull()
                t.column("allowCopyPartnerValues", .boolean).notNull()
                t.column("showPartnerHistory", .boolean).notNull()
            }
            try db.create(table: Exercise.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("category", .text).notNull()
                t.column("equipment", .text).notNull()
                t.column("tracksWeight", .boolean).notNull()
                t.column("tracksReps", .boolean).notNull()
                t.column("tracksDuration", .boolean).notNull()
                t.column("defaultRestSeconds", .integer).notNull()
            }
            try db.create(table: ExerciseProfile.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("personId", .text).notNull()
                t.column("exerciseId", .text).notNull()
                t.column("restSeconds", .integer)
                t.column("machineSetup", .text).notNull()
                t.column("cues", .text).notNull()
                t.uniqueKey(["personId", "exerciseId"])
            }
            try db.create(table: WorkoutTemplate.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("defaultMode", .text).notNull()
            }
            try db.create(table: TemplateExercise.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("templateId", .text).notNull().indexed()
                    .references(WorkoutTemplate.databaseTableName)
                t.column("exerciseId", .text).notNull()
                t.column("assignment", .text).notNull()
                t.column("orderIndex", .integer).notNull()
                t.column("defaultLoggingMode", .text)
            }
            try db.create(table: WorkoutSession.databaseTableName) { t in
                t.primaryKey("id", .text)
                // No FK: deleting a routine leaves its past workouts intact.
                t.column("templateId", .text)
                t.column("name", .text).notNull()
                t.column("startTime", .integer).notNull()
                t.column("endTime", .integer)
                t.column("label", .text)
                t.column("loggingStyle", .text).notNull()
                t.column("status", .text).notNull()
            }
            try db.create(index: "workout_session_status_start", on: WorkoutSession.databaseTableName,
                          columns: ["status", "startTime"])
            try db.create(table: SessionParticipant.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull().indexed()
                    .references(WorkoutSession.databaseTableName)
                t.column("personId", .text).notNull()
                t.column("orderIndex", .integer).notNull()
            }
            try db.create(table: SessionExercise.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull().indexed()
                    .references(WorkoutSession.databaseTableName)
                t.column("exerciseId", .text).notNull()
                t.column("loggingMode", .text).notNull()
                t.column("variant", .text).notNull()
                t.column("activePersonId", .text)
                t.column("addedDuringSession", .boolean).notNull()
                t.column("orderIndex", .integer).notNull()
            }
            try db.create(table: SessionExercisePerson.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("sessionExerciseId", .text).notNull().indexed()
                    .references(SessionExercise.databaseTableName)
                t.column("personId", .text).notNull()
                t.column("status", .text).notNull()
                t.column("skipReason", .text)
                t.column("substituteExerciseId", .text)
                t.column("orderIndex", .integer).notNull()
            }
            try db.create(table: SetEntry.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull().indexed()
                    .references(WorkoutSession.databaseTableName)
                t.column("sessionExerciseId", .text).indexed()
                    .references(SessionExercise.databaseTableName)
                // No FK: history keeps sets of exercises deleted from the library.
                t.column("exerciseId", .text).notNull()
                t.column("personId", .text).notNull()
                t.column("setIndex", .integer).notNull()
                t.column("weight", .double)
                t.column("reps", .integer)
                t.column("duration", .integer)
                t.column("setType", .text).notNull()
                t.column("variant", .text).notNull()
                t.column("timestamp", .integer)
                t.column("note", .text)
            }
            try db.create(index: "set_entry_history", on: SetEntry.databaseTableName,
                          columns: ["personId", "exerciseId", "variant"])
            try db.create(table: RestTimer.databaseTableName) { t in
                t.column("sessionId", .text).notNull()
                t.column("personId", .text).notNull()
                t.column("sessionExerciseId", .text).notNull()
                t.column("startedAt", .integer).notNull()
                t.column("durationSeconds", .integer).notNull()
                t.primaryKey(["sessionId", "personId"])
            }

            try db.create(table: OutboxEntry.databaseTableName) { t in
                t.column("entity", .text).notNull()
                t.column("recordId", .text).notNull()
                t.column("rev", .integer).notNull()
                t.primaryKey(["entity", "recordId"])
            }
            try db.create(table: "sync_state") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }

            try SyncTriggers.install(db)
        }

        // Every later migration that creates, alters or rebuilds a synced table
        // must end with `try SyncTriggers.install(db)`: rebuilding a table drops
        // its triggers, and the UPDATE trigger's column list must match.
        return migrator
    }
}
