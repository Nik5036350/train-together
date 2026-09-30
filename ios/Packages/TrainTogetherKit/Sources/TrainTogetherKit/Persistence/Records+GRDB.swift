import GRDB
import TrainTogetherCore

// GRDB conformances for the Core records. Tables are named after the sync
// entity, columns after the properties, so a record's row and its sync payload
// are the same JSON object.

extension Person: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension AppSettings: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension Exercise: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension ExerciseProfile: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension WorkoutTemplate: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension TemplateExercise: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension WorkoutSession: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension SessionParticipant: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension SessionExercise: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension SessionExercisePerson: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension SetEntry: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { entityName }
}

extension RestTimer: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "rest_timer"
}

/// Every synced record type, parents before children. Restore inserts in this
/// order, and sync code maps entity names back to types through it.
enum SyncedTypes {
    static let all: [any (SyncEntity & FetchableRecord & PersistableRecord).Type] = [
        AppSettings.self,
        Person.self,
        Exercise.self,
        ExerciseProfile.self,
        WorkoutTemplate.self,
        TemplateExercise.self,
        WorkoutSession.self,
        SessionParticipant.self,
        SessionExercise.self,
        SessionExercisePerson.self,
        SetEntry.self,
    ]

    static let tableNames: [String] = all.map { $0.entityName }

    static func type(named entity: String) -> (any (SyncEntity & FetchableRecord & PersistableRecord).Type)? {
        all.first { $0.entityName == entity }
    }
}

enum Col {
    static let id = Column("id")
    static let rowID = Column.rowID
}
