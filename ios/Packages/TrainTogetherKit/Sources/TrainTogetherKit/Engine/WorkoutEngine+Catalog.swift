import Foundation
import GRDB
import TrainTogetherCore

/// An exercise as edited in the exercise editor, with each person's settings.
public struct ExerciseDraft: Sendable {
    public var id: String?
    public var name: String
    public var category: String
    public var equipment: String
    public var tracksWeight: Bool
    public var tracksReps: Bool
    public var tracksDuration: Bool
    public var defaultRestSeconds: Int
    public var profiles: [ProfileDraft]

    public init(
        id: String? = nil, name: String, category: String = "", equipment: String = "",
        tracksWeight: Bool = true, tracksReps: Bool = true, tracksDuration: Bool = false,
        defaultRestSeconds: Int = Exercise.defaultRestSeconds, profiles: [ProfileDraft] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.equipment = equipment
        self.tracksWeight = tracksWeight
        self.tracksReps = tracksReps
        self.tracksDuration = tracksDuration
        self.defaultRestSeconds = defaultRestSeconds
        self.profiles = profiles
    }

    public init(_ exercise: Exercise, profiles: [ProfileDraft] = []) {
        self.init(
            id: exercise.id, name: exercise.name, category: exercise.category,
            equipment: exercise.equipment, tracksWeight: exercise.tracksWeight,
            tracksReps: exercise.tracksReps, tracksDuration: exercise.tracksDuration,
            defaultRestSeconds: exercise.defaultRestSeconds, profiles: profiles
        )
    }
}

/// A person's sex and bodyweight, saved together. Passing nil for the
/// whole profile leaves both unchanged; nil fields clear them.
public struct BodyProfile: Sendable, Hashable {
    public var sex: Sex?
    public var bodyweight: Double?

    public init(sex: Sex?, bodyweight: Double?) {
        self.sex = sex
        self.bodyweight = bodyweight.flatMap { $0 > 0 ? $0 : nil }
    }
}

public struct ProfileDraft: Sendable, Hashable {
    public var personId: String
    public var restSeconds: Int?
    public var machineSetup: String
    public var cues: String

    public init(personId: String, restSeconds: Int? = nil, machineSetup: String = "", cues: String = "") {
        self.personId = personId
        self.restSeconds = restSeconds
        self.machineSetup = machineSetup
        self.cues = cues
    }
}

// MARK: - People and settings

extension WorkoutEngine {
    /// Onboarding: create the phone's owner ("you").
    @discardableResult
    public func createOwner(name: String, color: PersonColor, unit: WeightUnit, initials: String? = nil) throws -> String {
        try write { db in
            if try owner(db) != nil { throw EngineError.invalid("OWNER ALREADY EXISTS") }
            let person = Person(
                id: newID(), name: try requireName(name), initials: initialsFor(name, initials),
                color: color.rawValue, unit: unit, isOwner: true
            )
            try person.insert(db)
            _ = try settings(db)
            return person.id
        }
    }

    /// Creates the partner, or updates the existing one.
    @discardableResult
    public func savePartner(
        name: String, color: PersonColor, unit: WeightUnit, initials: String? = nil, body: BodyProfile? = nil
    ) throws -> String {
        try write { db in
            let name = try requireName(name)
            var settings = try settings(db)
            settings.coupleModeEnabled = true
            try settings.update(db)
            if var partner = try partner(db) {
                partner.name = name
                partner.color = color.rawValue
                partner.unit = unit
                partner.initials = initialsFor(name, initials)
                if let body {
                    partner.sex = body.sex
                    partner.bodyweight = body.bodyweight
                }
                try partner.update(db)
                return partner.id
            }
            let partner = Person(
                id: newID(), name: name, initials: initialsFor(name, initials),
                color: color.rawValue, unit: unit, isOwner: false,
                sex: body?.sex, bodyweight: body?.bodyweight
            )
            try partner.insert(db)
            return partner.id
        }
    }

    public func updatePerson(
        id: String, name: String? = nil, color: PersonColor? = nil, unit: WeightUnit? = nil,
        initials: String? = nil, body: BodyProfile? = nil
    ) throws {
        try write { db in
            guard var person = try Person.fetchOne(db, key: id) else { throw EngineError.notFound("PERSON") }
            if let name { person.name = try requireName(name) }
            if let color { person.color = color.rawValue }
            if let unit { person.unit = unit }
            if let initials { person.initials = initialsFor(person.name, initials) }
            if let body {
                person.sex = body.sex
                person.bodyweight = body.bodyweight
            }
            try person.update(db)
        }
    }

    public func updateSettings(defaultParticipants: Participants? = nil, defaultLoggingStyle: LoggingMode? = nil) throws {
        try write { db in
            var settings = try settings(db)
            if let defaultParticipants { settings.defaultParticipants = defaultParticipants }
            if let defaultLoggingStyle { settings.defaultLoggingStyle = defaultLoggingStyle }
            try settings.update(db)
        }
    }

    private func requireName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw EngineError.invalid("NAME IS REQUIRED") }
        return trimmed
    }

    private func initialsFor(_ name: String, _ initials: String?) -> String {
        if let initials = nonBlank(initials) { return initials.uppercased() }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? ""
    }
}

// MARK: - Exercise library

extension WorkoutEngine {
    /// Creates or updates an exercise and upserts the given per-person
    /// profiles (profiles not mentioned are left alone). Returns the id.
    @discardableResult
    public func saveExercise(_ draft: ExerciseDraft) throws -> String {
        try write { db in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { throw EngineError.invalid("NAME IS REQUIRED") }
            if !(draft.tracksWeight || draft.tracksReps || draft.tracksDuration) {
                throw EngineError.invalid("TRACK AT LEAST ONE VALUE")
            }
            let exercise = Exercise(
                id: draft.id ?? newID(), name: name, category: draft.category,
                equipment: draft.equipment, tracksWeight: draft.tracksWeight,
                tracksReps: draft.tracksReps, tracksDuration: draft.tracksDuration,
                defaultRestSeconds: max(0, draft.defaultRestSeconds)
            )
            try exercise.save(db)
            for p in draft.profiles {
                try ExerciseProfile(
                    personId: p.personId, exerciseId: exercise.id,
                    restSeconds: p.restSeconds.map { max(0, $0) },
                    machineSetup: p.machineSetup, cues: p.cues
                ).save(db)
            }
            return exercise.id
        }
    }

    /// "Set default rest…" from the logging card: the person's rest for this
    /// exercise. Nil clears the override.
    public func setProfileRest(personId: String, exerciseId: String, restSeconds: Int?) throws {
        try write { db in
            let id = ExerciseProfile.id(personId: personId, exerciseId: exerciseId)
            var profile = try ExerciseProfile.fetchOne(db, key: id)
                ?? ExerciseProfile(personId: personId, exerciseId: exerciseId)
            profile.restSeconds = restSeconds.map { max(0, $0) }
            try profile.save(db)
        }
    }

    /// Removes an exercise from the library and every routine. Past sets keep
    /// their exercise id and stay in history. Refused while the current workout
    /// uses the exercise.
    public func deleteExercise(id: String) throws {
        try write { db in
            if let active = try activeSession(db) {
                let cards = try SessionExercise.filter(Column("sessionId") == active.id).fetchAll(db)
                let substitutes = try SessionExercisePerson
                    .filter(cards.map(\.id).contains(Column("sessionExerciseId")))
                    .fetchAll(db)
                    .compactMap(\.substituteExerciseId)
                if cards.contains(where: { $0.exerciseId == id }) || substitutes.contains(id) {
                    throw EngineError.invalid("EXERCISE IS IN THE CURRENT WORKOUT")
                }
            }
            let touched = Set(try TemplateExercise.filter(Column("exerciseId") == id).fetchAll(db).map(\.templateId))
            try TemplateExercise.filter(Column("exerciseId") == id).deleteAll(db)
            for templateId in touched { try renumberTemplate(db, templateId) }
            try ExerciseProfile.filter(Column("exerciseId") == id).deleteAll(db)
            _ = try Exercise.deleteOne(db, key: id)
        }
    }
}

// MARK: - Routines

extension WorkoutEngine {
    @discardableResult
    public func createTemplate(name: String = "New routine", defaultMode: LoggingMode = .alternate) throws -> String {
        try write { db in
            let template = WorkoutTemplate(id: newID(), name: name, defaultMode: defaultMode)
            try template.insert(db)
            return template.id
        }
    }

    public func updateTemplate(id: String, name: String? = nil, defaultMode: LoggingMode? = nil) throws {
        try write { db in
            guard var template = try WorkoutTemplate.fetchOne(db, key: id) else { throw EngineError.notFound("ROUTINE") }
            if let name {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                template.name = trimmed.isEmpty ? "New routine" : trimmed
            }
            if let defaultMode { template.defaultMode = defaultMode }
            try template.update(db)
        }
    }

    public func deleteTemplate(id: String) throws {
        try write { db in
            try TemplateExercise.filter(Column("templateId") == id).deleteAll(db)
            _ = try WorkoutTemplate.deleteOne(db, key: id)
        }
    }

    @discardableResult
    public func addTemplateExercise(templateId: String, exerciseId: String, assignment: Assignment = .both) throws -> String {
        try write { db in
            guard try WorkoutTemplate.exists(db, key: templateId) else { throw EngineError.notFound("ROUTINE") }
            let count = try TemplateExercise.filter(Column("templateId") == templateId).fetchCount(db)
            let row = TemplateExercise(
                id: newID(), templateId: templateId, exerciseId: exerciseId,
                assignment: assignment, orderIndex: count
            )
            try row.insert(db)
            return row.id
        }
    }

    public func removeTemplateExercise(id: String) throws {
        try write { db in
            guard let row = try TemplateExercise.fetchOne(db, key: id) else { return }
            try row.delete(db)
            try renumberTemplate(db, row.templateId)
        }
    }

    /// Drag-to-reorder, with SwiftUI `onMove` semantics.
    public func moveTemplateExercises(templateId: String, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        try write { db in
            var rows = try templateRows(db, templateId)
            let moving = source.sorted().map { rows[$0] }
            let insertAt = destination - source.filter { $0 < destination }.count
            for index in source.sorted(by: >) { rows.remove(at: index) }
            rows.insert(contentsOf: moving, at: insertAt)
            try writeOrder(db, rows)
        }
    }

    public func setAssignment(templateExerciseId: String, assignment: Assignment) throws {
        try write { db in
            guard var row = try TemplateExercise.fetchOne(db, key: templateExerciseId) else {
                throw EngineError.notFound("EXERCISE")
            }
            row.assignment = assignment
            try row.update(db)
        }
    }

    private func templateRows(_ db: Database, _ templateId: String) throws -> [TemplateExercise] {
        try TemplateExercise
            .filter(Column("templateId") == templateId)
            .order(Column("orderIndex"), Col.rowID)
            .fetchAll(db)
    }

    func renumberTemplate(_ db: Database, _ templateId: String) throws {
        try writeOrder(db, try templateRows(db, templateId))
    }

    private func writeOrder(_ db: Database, _ rows: [TemplateExercise]) throws {
        for (index, var row) in rows.enumerated() where row.orderIndex != index {
            row.orderIndex = index
            try row.update(db)
        }
    }
}
