import TrainTogetherCore

/// People, settings, the exercise library and routines.
public struct CatalogSnapshot: Equatable, Sendable {
    public var people: [Person]
    public var settings: AppSettings
    /// Sorted by name.
    public var exercises: [Exercise]
    /// Keyed by profile id (`ExerciseProfile.id(personId:exerciseId:)`).
    public var profiles: [String: ExerciseProfile]
    /// Sorted by name.
    public var templates: [RoutineSummary]

    public static let empty = CatalogSnapshot(people: [], settings: AppSettings(), exercises: [], profiles: [:], templates: [])

    public var owner: Person? { people.first(where: \.isOwner) }
    /// The first active non-owner.
    public var partner: Person? { people.first { !$0.isOwner && $0.active } }
    /// Owner first, then partner — the two people on the phone.
    public var pair: [Person] { [owner, partner].compactMap { $0 } }

    public func person(_ id: String?) -> Person? {
        guard let id else { return nil }
        return people.first { $0.id == id }
    }

    public func exercise(_ id: String?) -> Exercise? {
        guard let id else { return nil }
        return exercises.first { $0.id == id }
    }

    public func profile(personId: String, exerciseId: String) -> ExerciseProfile? {
        profiles[ExerciseProfile.id(personId: personId, exerciseId: exerciseId)]
    }

    public func routine(_ id: String?) -> RoutineSummary? {
        guard let id else { return nil }
        return templates.first { $0.id == id }
    }

    /// Participant ids for a "who is training" choice, owner first.
    public func participantIds(for choice: Participants) -> [String] {
        switch choice {
        case .owner: [owner?.id].compactMap { $0 }
        case .partner: [partner?.id].compactMap { $0 }
        case .both: pair.map(\.id)
        }
    }
}

public struct RoutineSummary: Equatable, Sendable, Identifiable {
    public var template: WorkoutTemplate
    /// In routine order.
    public var exercises: [TemplateExercise]
    public var id: String { template.id }
}

/// The workout in progress, with everything the live screens show.
public struct ActiveSessionSnapshot: Equatable, Sendable {
    public var session: WorkoutSession
    public var participantIds: [String]
    /// In workout order.
    public var cards: [Card]
    /// Ordered by (timestamp, setIndex).
    public var sets: [SetEntry]
    /// Rest timers keyed by person id.
    public var timers: [String: RestTimer]
    /// "Last time" per card and person, for the card's current variant and the
    /// person's effective exercise. Keyed by `lastTimeKey`.
    public var lastTimes: [String: LastTime]

    public struct Card: Equatable, Sendable, Identifiable {
        public var exercise: SessionExercise
        /// The people on the card, in order.
        public var people: [SessionExercisePerson]
        public var id: String { exercise.id }

        public func row(for personId: String) -> SessionExercisePerson? {
            people.first { $0.personId == personId }
        }

        /// The exercise a person actually does here (after substitution).
        public func exerciseId(for personId: String) -> String {
            row(for: personId)?.substituteExerciseId ?? exercise.exerciseId
        }

        /// People still doing the exercise (skipped people are hidden).
        public var visiblePeople: [SessionExercisePerson] {
            people.filter { $0.status != .skipped }
        }

        /// Someone on the card hasn't logged or skipped yet.
        public var isOpen: Bool {
            people.contains { $0.status != .skipped && $0.status != .logged }
        }
    }

    public static func lastTimeKey(cardId: String, personId: String) -> String { "\(cardId)|\(personId)" }

    public func card(_ id: String?) -> Card? {
        guard let id else { return nil }
        return cards.first { $0.id == id }
    }

    /// The card the workout is "on": the first one someone still has to do.
    public var currentCardID: String? { cards.first(where: \.isOpen)?.id }

    /// Cards someone neither logged nor skipped, and has no sets on — the
    /// finish sheet lists these.
    public var unfinishedCards: [Card] {
        cards.filter { card in
            card.people.contains { row in
                row.status != .skipped && row.status != .logged
                    && !sets.contains { $0.sessionExerciseId == card.id && $0.personId == row.personId }
            }
        }
    }

    /// A person's sets on a card, optionally for one variant, in logged order.
    public func sets(cardId: String, personId: String, variant: Variant? = nil) -> [SetEntry] {
        sets
            .filter { $0.sessionExerciseId == cardId && $0.personId == personId && (variant == nil || $0.variant == variant) }
            .sorted { $0.setIndex < $1.setIndex }
    }

    /// All of a person's sets in this workout.
    public func sets(personId: String) -> [SetEntry] {
        sets.filter { $0.personId == personId }
    }

    public func lastTime(cardId: String, personId: String) -> LastTime? {
        lastTimes[Self.lastTimeKey(cardId: cardId, personId: personId)]
    }

    /// Values to pre-fill: this workout's last set for the variant, otherwise
    /// the last set from the most recent finished workout.
    public func defaultValues(cardId: String, personId: String) -> SetValues? {
        guard let card = card(cardId) else { return nil }
        if let last = sets(cardId: cardId, personId: personId, variant: card.exercise.variant).last {
            return last.values
        }
        return lastTime(cardId: cardId, personId: personId)?.sets.last?.values
    }
}

/// The most recent finished workout's sets for a person, exercise and variant.
public struct LastTime: Equatable, Sendable {
    /// "Mon" — the stored label, else the workout's weekday.
    public var label: String
    public var sessionId: String
    /// In order.
    public var sets: [SetEntry]
}

/// What the app observes while running: the catalog and the live workout.
public struct AppSnapshot: Equatable, Sendable {
    public var catalog: CatalogSnapshot
    public var active: ActiveSessionSnapshot?

    public static let empty = AppSnapshot(catalog: .empty, active: nil)

    /// Onboarding shows until the phone has an owner.
    public var needsOnboarding: Bool { catalog.owner == nil }
}

/// One row in the history ledger.
public struct HistoryItem: Equatable, Sendable, Identifiable {
    public var session: WorkoutSession
    /// Participants, or the people found in the sets for legacy sessions.
    public var personIds: [String]
    public var setCount: Int
    public var exerciseCount: Int
    /// Volume (weight × reps) per person, each in that person's own unit.
    public var volumeByPerson: [String: Double]
    public var id: String { session.id }

    public var durationMs: Int64? { session.endTime.map { $0 - session.startTime } }
}

/// A finished (or active) workout's full detail.
public struct WorkoutDetail: Equatable, Sendable {
    public var session: WorkoutSession
    public var personIds: [String]
    /// Ordered by (timestamp, setIndex).
    public var sets: [SetEntry]
    /// Exercise ids in display order: card order where known, otherwise first
    /// appearance.
    public var exerciseOrder: [String]

    public var durationMs: Int64? { session.endTime.map { $0 - session.startTime } }

    public func sets(exerciseId: String, personId: String) -> [SetEntry] {
        sets.filter { $0.exerciseId == exerciseId && $0.personId == personId }
    }

    public func sets(personId: String) -> [SetEntry] {
        sets.filter { $0.personId == personId }
    }
}

/// Totals for one person in one workout (summary and detail screens).
public struct PersonTotals: Equatable, Sendable {
    public var exercises: Int
    public var sets: Int
    public var reps: Int
    public var volume: Double

    public init(sets: [SetEntry]) {
        exercises = Set(sets.map(\.exerciseId)).count
        self.sets = sets.count
        reps = sets.reduce(0) { $0 + ($1.reps ?? 0) }
        volume = sets.reduce(0) { $0 + $1.volume }
    }
}
