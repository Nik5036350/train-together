// The domain records. Each struct is simultaneously:
// - the SQLite row (GRDB maps properties to same-named columns),
// - the sync payload (the camelCase JSON the server stores per record).
//
// This is the sync contract shared with the server's legacy importer
// (backend/src/legacy_import.rs). The golden fixture
// backend/tests/fixtures/seed-records.json pins it on both sides. Fields added
// later must be optional or have a default so older payloads still decode.
// All times are epoch milliseconds.

/// A record that syncs to the server under `entityName`.
public protocol SyncEntity: Codable, Hashable, Sendable, Identifiable where ID == String {
    static var entityName: String { get }
}

public struct Person: SyncEntity {
    public static let entityName = "person"
    public var id: String
    public var name: String
    public var initials: String
    /// A `PersonColor` key; legacy keys are resolved when displayed.
    public var color: String
    public var unit: WeightUnit
    public var isOwner: Bool
    public var active: Bool
    /// For strength scores (1RM formula, DOTS). Never inferred; nil = unset.
    public var sex: Sex?
    /// Current bodyweight in the person's `unit`, for DOTS.
    public var bodyweight: Double?

    public init(
        id: String, name: String, initials: String, color: String, unit: WeightUnit,
        isOwner: Bool, active: Bool = true, sex: Sex? = nil, bodyweight: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.initials = initials
        self.color = color
        self.unit = unit
        self.isOwner = isOwner
        self.active = active
        self.sex = sex
        self.bodyweight = bodyweight
    }

    public var personColor: PersonColor { PersonColor(key: color) }
}

extension Person {
    enum CodingKeys: String, CodingKey {
        case id, name, initials, color, unit, isOwner, active, sex, bodyweight
    }

    // The profile fields came later and are optional: a payload without them,
    // or with a value this version doesn't understand, still decodes — the
    // field is just unset (restore would otherwise drop the whole person).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            initials: try c.decode(String.self, forKey: .initials),
            color: try c.decode(String.self, forKey: .color),
            unit: try c.decode(WeightUnit.self, forKey: .unit),
            isOwner: try c.decode(Bool.self, forKey: .isOwner),
            active: try c.decodeIfPresent(Bool.self, forKey: .active) ?? true,
            sex: (try? c.decodeIfPresent(String.self, forKey: .sex)).flatMap(Sex.init(rawValue:)),
            bodyweight: (try? c.decodeIfPresent(Double.self, forKey: .bodyweight)).flatMap { $0 > 0 ? $0 : nil }
        )
    }
}

/// The single settings row (id "app").
public struct AppSettings: SyncEntity {
    public static let entityName = "settings"
    public static let singletonID = "app"
    public var id: String
    public var defaultParticipants: Participants
    public var defaultLoggingStyle: LoggingMode
    // Carried over from the legacy app; nothing reads them today.
    public var coupleModeEnabled: Bool
    public var allowCopyPartnerValues: Bool
    public var showPartnerHistory: Bool

    public init(
        id: String = AppSettings.singletonID,
        defaultParticipants: Participants = .both,
        defaultLoggingStyle: LoggingMode = .alternate,
        coupleModeEnabled: Bool = true,
        allowCopyPartnerValues: Bool = true,
        showPartnerHistory: Bool = true
    ) {
        self.id = id
        self.defaultParticipants = defaultParticipants
        self.defaultLoggingStyle = defaultLoggingStyle
        self.coupleModeEnabled = coupleModeEnabled
        self.allowCopyPartnerValues = allowCopyPartnerValues
        self.showPartnerHistory = showPartnerHistory
    }
}

public struct Exercise: SyncEntity {
    public static let entityName = "exercise"
    public static let defaultRestSeconds = 90
    public var id: String
    public var name: String
    public var category: String
    public var equipment: String
    public var tracksWeight: Bool
    public var tracksReps: Bool
    public var tracksDuration: Bool
    public var defaultRestSeconds: Int

    public init(
        id: String, name: String, category: String = "", equipment: String = "",
        tracksWeight: Bool = true, tracksReps: Bool = true, tracksDuration: Bool = false,
        defaultRestSeconds: Int = Exercise.defaultRestSeconds
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.equipment = equipment
        self.tracksWeight = tracksWeight
        self.tracksReps = tracksReps
        self.tracksDuration = tracksDuration
        self.defaultRestSeconds = defaultRestSeconds
    }

    /// "Weight · Reps" — what the exercise measures, for library rows.
    public var tracksSummary: String {
        [tracksWeight ? "Weight" : nil, tracksReps ? "Reps" : nil, tracksDuration ? "Duration" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// A person's own settings for an exercise. Keyed by (person, exercise); the id
/// is derived from that pair so every device and the importer agree on it.
public struct ExerciseProfile: SyncEntity {
    public static let entityName = "person_exercise_profile"
    public var id: String
    public var personId: String
    public var exerciseId: String
    public var restSeconds: Int?
    public var machineSetup: String
    public var cues: String

    public init(
        personId: String, exerciseId: String, restSeconds: Int? = nil,
        machineSetup: String = "", cues: String = ""
    ) {
        self.id = ExerciseProfile.id(personId: personId, exerciseId: exerciseId)
        self.personId = personId
        self.exerciseId = exerciseId
        self.restSeconds = restSeconds
        self.machineSetup = machineSetup
        self.cues = cues
    }

    public static func id(personId: String, exerciseId: String) -> String {
        "prof_\(personId)__\(exerciseId)"
    }
}

/// A routine ("template" in the data model, "routine" in the UI).
public struct WorkoutTemplate: SyncEntity {
    public static let entityName = "template"
    public var id: String
    public var name: String
    public var defaultMode: LoggingMode

    public init(id: String, name: String, defaultMode: LoggingMode = .alternate) {
        self.id = id
        self.name = name
        self.defaultMode = defaultMode
    }
}

public struct TemplateExercise: SyncEntity {
    public static let entityName = "template_exercise"
    public var id: String
    public var templateId: String
    public var exerciseId: String
    public var assignment: Assignment
    public var orderIndex: Int
    public var defaultLoggingMode: LoggingMode?

    public init(
        id: String, templateId: String, exerciseId: String, assignment: Assignment = .both,
        orderIndex: Int, defaultLoggingMode: LoggingMode? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.exerciseId = exerciseId
        self.assignment = assignment
        self.orderIndex = orderIndex
        self.defaultLoggingMode = defaultLoggingMode
    }
}

public struct WorkoutSession: SyncEntity {
    public static let entityName = "workout_session"
    public var id: String
    public var templateId: String?
    public var name: String
    public var startTime: Int64
    public var endTime: Int64?
    public var label: String?
    public var loggingStyle: LoggingMode
    public var status: SessionStatus

    public init(
        id: String, templateId: String?, name: String, startTime: Int64, endTime: Int64? = nil,
        label: String? = nil, loggingStyle: LoggingMode, status: SessionStatus
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
        self.loggingStyle = loggingStyle
        self.status = status
    }

    /// Name for display; legacy sessions may have none.
    public var displayName: String { name.isEmpty ? "Workout" : name }
}

public struct SessionParticipant: SyncEntity {
    public static let entityName = "session_participant"
    public var id: String
    public var sessionId: String
    public var personId: String
    public var orderIndex: Int

    public init(sessionId: String, personId: String, orderIndex: Int) {
        self.id = SessionParticipant.id(sessionId: sessionId, personId: personId)
        self.sessionId = sessionId
        self.personId = personId
        self.orderIndex = orderIndex
    }

    public static func id(sessionId: String, personId: String) -> String {
        "spart_\(sessionId)_\(personId)"
    }
}

/// One exercise card in a workout.
public struct SessionExercise: SyncEntity {
    public static let entityName = "session_exercise"
    public var id: String
    public var sessionId: String
    public var exerciseId: String
    public var loggingMode: LoggingMode
    public var variant: Variant
    public var activePersonId: String?
    public var addedDuringSession: Bool
    public var orderIndex: Int

    public init(
        id: String, sessionId: String, exerciseId: String, loggingMode: LoggingMode,
        variant: Variant = .normal, activePersonId: String?, addedDuringSession: Bool,
        orderIndex: Int
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.loggingMode = loggingMode
        self.variant = variant
        self.activePersonId = activePersonId
        self.addedDuringSession = addedDuringSession
        self.orderIndex = orderIndex
    }
}

/// A person's state on one exercise card.
public struct SessionExercisePerson: SyncEntity {
    public static let entityName = "session_exercise_person"
    public var id: String
    public var sessionExerciseId: String
    public var personId: String
    public var status: PersonStatus
    public var skipReason: String?
    public var substituteExerciseId: String?
    public var orderIndex: Int

    public init(
        sessionExerciseId: String, personId: String, status: PersonStatus = .pending,
        skipReason: String? = nil, substituteExerciseId: String? = nil, orderIndex: Int
    ) {
        self.id = SessionExercisePerson.id(sessionExerciseId: sessionExerciseId, personId: personId)
        self.sessionExerciseId = sessionExerciseId
        self.personId = personId
        self.status = status
        self.skipReason = skipReason
        self.substituteExerciseId = substituteExerciseId
        self.orderIndex = orderIndex
    }

    public static func id(sessionExerciseId: String, personId: String) -> String {
        "sep_\(sessionExerciseId)_\(personId)"
    }
}

public struct SetEntry: SyncEntity {
    public static let entityName = "set_entry"
    public var id: String
    public var sessionId: String
    /// Nil for legacy history sets, which were logged before session exercises
    /// existed in the data.
    public var sessionExerciseId: String?
    /// The exercise actually performed (after any substitution).
    public var exerciseId: String
    public var personId: String
    /// Storage order within the person's group; never shown to the user.
    public var setIndex: Int
    public var weight: Double?
    public var reps: Int?
    public var duration: Int?
    public var setType: String
    public var variant: Variant
    public var timestamp: Int64?
    public var note: String?

    public init(
        id: String, sessionId: String, sessionExerciseId: String?, exerciseId: String,
        personId: String, setIndex: Int, weight: Double? = nil, reps: Int? = nil,
        duration: Int? = nil, setType: String = "working", variant: Variant = .normal,
        timestamp: Int64? = nil, note: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionExerciseId = sessionExerciseId
        self.exerciseId = exerciseId
        self.personId = personId
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.setType = setType
        self.variant = variant
        self.timestamp = timestamp
        self.note = note
    }

    public var values: SetValues {
        SetValues(weight: weight, reps: reps, duration: duration, note: note)
    }

    /// Weight × reps for volume totals.
    public var volume: Double { (weight ?? 0) * Double(reps ?? 0) }
}

/// The values a person enters for a set.
public struct SetValues: Hashable, Sendable {
    public var weight: Double?
    public var reps: Int?
    public var duration: Int?
    public var note: String?

    public init(weight: Double? = nil, reps: Int? = nil, duration: Int? = nil, note: String? = nil) {
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.note = note
    }
}

/// A running rest countdown for one person. Local-only: never synced.
public struct RestTimer: Codable, Hashable, Sendable {
    public var sessionId: String
    public var personId: String
    public var sessionExerciseId: String
    public var startedAt: Int64
    public var durationSeconds: Int

    public init(
        sessionId: String, personId: String, sessionExerciseId: String, startedAt: Int64,
        durationSeconds: Int
    ) {
        self.sessionId = sessionId
        self.personId = personId
        self.sessionExerciseId = sessionExerciseId
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
    }

    public var endsAt: Int64 { startedAt + Int64(durationSeconds) * 1000 }

    public func phase(now: Int64) -> RestPhase {
        RestPhase(startedAt: startedAt, durationSeconds: durationSeconds, now: now)
    }
}

// Payloads from before the variant feature have no `variant`; they decode as
// normal instead of being rejected.

extension SessionExercise {
    enum CodingKeys: String, CodingKey {
        case id, sessionId, exerciseId, loggingMode, variant, activePersonId, addedDuringSession, orderIndex
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            sessionId: try c.decode(String.self, forKey: .sessionId),
            exerciseId: try c.decode(String.self, forKey: .exerciseId),
            loggingMode: try c.decode(LoggingMode.self, forKey: .loggingMode),
            variant: try c.decodeIfPresent(Variant.self, forKey: .variant) ?? .normal,
            activePersonId: try c.decodeIfPresent(String.self, forKey: .activePersonId),
            addedDuringSession: try c.decodeIfPresent(Bool.self, forKey: .addedDuringSession) ?? false,
            orderIndex: try c.decode(Int.self, forKey: .orderIndex)
        )
    }
}

extension SetEntry {
    enum CodingKeys: String, CodingKey {
        case id, sessionId, sessionExerciseId, exerciseId, personId, setIndex, weight, reps, duration
        case setType, variant, timestamp, note
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            sessionId: try c.decode(String.self, forKey: .sessionId),
            sessionExerciseId: try c.decodeIfPresent(String.self, forKey: .sessionExerciseId),
            exerciseId: try c.decode(String.self, forKey: .exerciseId),
            personId: try c.decode(String.self, forKey: .personId),
            setIndex: try c.decode(Int.self, forKey: .setIndex),
            weight: try c.decodeIfPresent(Double.self, forKey: .weight),
            reps: try c.decodeIfPresent(Int.self, forKey: .reps),
            duration: try c.decodeIfPresent(Int.self, forKey: .duration),
            setType: try c.decodeIfPresent(String.self, forKey: .setType) ?? "working",
            variant: try c.decodeIfPresent(Variant.self, forKey: .variant) ?? .normal,
            timestamp: try c.decodeIfPresent(Int64.self, forKey: .timestamp),
            note: try c.decodeIfPresent(String.self, forKey: .note)
        )
    }
}
