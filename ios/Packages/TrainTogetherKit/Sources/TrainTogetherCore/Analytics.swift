import Foundation

// Training analytics: strength estimates and per-session progress points.
// Pure functions over sets, so they're testable without a database.

/// Estimated one-rep max from a set of 1–10 reps. Formulas lose accuracy
/// beyond ~10 reps, so heavier-rep sets don't count. Which formula fits best
/// differs by sex in the (limited) validation studies: Epley for men,
/// Brzycki for women; Epley when sex isn't set.
public enum OneRepMax {
    public static let maxReps = 10

    public static func estimate(weight: Double?, reps: Int?, sex: Sex?) -> Double? {
        guard let weight, weight > 0, let reps, (1...maxReps).contains(reps) else { return nil }
        if reps == 1 { return weight }
        switch sex {
        case .female: return weight * 36 / (37 - Double(reps)) // Brzycki
        case .male, nil: return weight * (1 + Double(reps) / 30) // Epley
        }
    }

    public static func formulaName(for sex: Sex?) -> String {
        sex == .female ? "Brzycki" : "Epley"
    }
}

/// DOTS relative strength: a lift scaled by a sex-specific bodyweight
/// polynomial, so people of different size and sex compare on one scale.
/// Official coefficients, bodyweight clamped as OpenPowerlifting does.
public enum DOTS {
    public static let poundsToKilograms = 0.45359237

    public static func score(liftKg: Double, bodyweightKg: Double, sex: Sex) -> Double {
        let (c, lower, upper): ([Double], Double, Double) = switch sex {
        case .male: ([-307.75076, 24.0900756, -0.1918759221, 0.0007391293, -0.000001093], 40, 210)
        case .female: ([-57.96288, 13.6175032, -0.1126655495, 0.0005158568, -0.0000010706], 40, 150)
        }
        let bw = min(max(bodyweightKg, lower), upper)
        let denominator = c[0] + c[1] * bw + c[2] * bw * bw + c[3] * bw * bw * bw + c[4] * bw * bw * bw * bw
        return liftKg * 500 / denominator
    }

    /// A person's DOTS for a lift in their own unit; nil until their sex and
    /// bodyweight are set.
    public static func score(lift: Double, person: Person) -> Double? {
        guard let sex = person.sex, let bodyweight = person.bodyweight else { return nil }
        let toKg = person.unit == .lb ? poundsToKilograms : 1
        return score(liftKg: lift * toKg, bodyweightKg: bodyweight * toKg, sex: sex)
    }
}

/// What a progress chart can plot.
public enum ProgressMetric: String, CaseIterable, Hashable, Sendable {
    /// Heaviest weight lifted in the session.
    case topSet
    /// Best estimated one-rep max in the session.
    case e1rm
    /// Σ weight × reps.
    case volume
    /// Most reps in one set, or the longest hold for timed exercises.
    case bestReps
    /// DOTS of the session's best e1RM at current bodyweight.
    case dots

    /// Metrics measured in the person's weight unit.
    public var isWeight: Bool { self == .topSet || self == .e1rm || self == .volume }
}

/// One set, as analytics reads it.
public struct AnalyticsSet: Hashable, Sendable {
    public var exerciseId: String
    public var personId: String
    public var sessionId: String
    public var variant: Variant
    /// The session's start (sets from the legacy app have no timestamp).
    public var date: Int64
    public var weight: Double?
    public var reps: Int?
    public var duration: Int?

    public init(exerciseId: String, personId: String, sessionId: String, variant: Variant, date: Int64,
                weight: Double?, reps: Int?, duration: Int?) {
        self.exerciseId = exerciseId
        self.personId = personId
        self.sessionId = sessionId
        self.variant = variant
        self.date = date
        self.weight = weight
        self.reps = reps
        self.duration = duration
    }
}

/// One person's performance on one exercise (and variant) in one session.
/// Every metric keys off the session's best sets, so warm-up ramps don't
/// drag the numbers down. A nil metric means "not measured this session" —
/// it's left out of charts and PRs, never plotted as zero.
public struct SessionPoint: Hashable, Sendable, Identifiable {
    public var sessionId: String
    public var personId: String
    public var exerciseId: String
    public var variant: Variant
    public var date: Int64
    /// Heaviest weight (with ≥ 1 rep); ties go to more reps.
    public var topWeight: Double?
    public var topWeightReps: Int?
    public var bestE1RM: Double?
    /// The set behind `bestE1RM`.
    public var e1rmWeight: Double?
    public var e1rmReps: Int?
    /// Nil when no set carried a weight.
    public var volume: Double?
    public var totalReps: Int
    public var setCount: Int
    public var bestReps: Int?
    public var bestDuration: Int?
    public var dots: Double?

    public var id: String { "\(sessionId)|\(personId)|\(variant.rawValue)" }

    /// The value to plot; `tracksReps` decides whether "best reps" means reps
    /// or duration.
    public func value(_ metric: ProgressMetric, tracksReps: Bool = true) -> Double? {
        switch metric {
        case .topSet: topWeight
        case .e1rm: bestE1RM
        case .volume: volume
        case .bestReps: tracksReps ? bestReps.map(Double.init) : bestDuration.map(Double.init)
        case .dots: dots
        }
    }
}

/// A personal record set in a session.
public struct RecordEvent: Hashable, Sendable, Identifiable {
    public enum Kind: String, Hashable, Sendable { case topSet, e1rm, reps, duration }
    public var kind: Kind
    public var point: SessionPoint
    public var id: String { point.id }
}

/// A person's bests on one exercise.
public struct PersonRecords: Hashable, Sendable {
    public var heaviest: SessionPoint?
    public var bestE1RM: SessionPoint?
    public var bestVolume: SessionPoint?
    public var bestReps: SessionPoint?
    public var bestDuration: SessionPoint?
    public var bestDOTS: SessionPoint?
}

public enum Analytics {
    /// A new best must beat the old one by more than this; equal-looking
    /// estimates (90×10 vs 120×1) can differ by floating-point noise.
    public static let recordEpsilon = 0.01

    /// Groups one person's sets on one exercise and variant into per-session
    /// points, oldest first.
    public static func sessionPoints(_ sets: [AnalyticsSet], person: Person) -> [SessionPoint] {
        let bySession = Dictionary(grouping: sets.filter { $0.personId == person.id }) { $0.sessionId }
        return bySession.values.compactMap { group -> SessionPoint? in
            guard let first = group.first else { return nil }
            let lifted = group.filter { ($0.weight ?? 0) > 0 && ($0.reps ?? 0) >= 1 }
            let top = lifted.max { a, b in
                (a.weight!, a.reps!) < (b.weight!, b.reps!)
            }
            let e1rms = group.compactMap { set in
                OneRepMax.estimate(weight: set.weight, reps: set.reps, sex: person.sex).map { (set, $0) }
            }
            let bestE1RM = e1rms.max { $0.1 < $1.1 }
            let weighted = group.filter { ($0.weight ?? 0) > 0 }
            return SessionPoint(
                sessionId: first.sessionId, personId: person.id, exerciseId: first.exerciseId,
                variant: first.variant, date: first.date,
                topWeight: top?.weight, topWeightReps: top?.reps,
                bestE1RM: bestE1RM?.1, e1rmWeight: bestE1RM?.0.weight, e1rmReps: bestE1RM?.0.reps,
                volume: weighted.isEmpty ? nil : weighted.reduce(0) { $0 + $1.weight! * Double($1.reps ?? 0) },
                totalReps: group.reduce(0) { $0 + ($1.reps ?? 0) },
                setCount: group.count,
                bestReps: group.compactMap(\.reps).max(),
                bestDuration: group.compactMap(\.duration).max(),
                dots: bestE1RM.flatMap { DOTS.score(lift: $0.1, person: person) }
            )
        }
        .sorted { ($0.date, $0.sessionId) < ($1.date, $1.sessionId) }
    }

    /// Sessions whose value beat every earlier session. The first session is
    /// the baseline, not a record; ties aren't records.
    public static func recordSessions(_ points: [SessionPoint], metric: ProgressMetric, tracksReps: Bool = true) -> Set<String> {
        var best: Double?
        var records: Set<String> = []
        for point in points {
            guard let value = point.value(metric, tracksReps: tracksReps) else { continue }
            if let previous = best {
                if value > previous + recordEpsilon {
                    records.insert(point.sessionId)
                    best = value
                }
            } else {
                best = value
            }
        }
        return records
    }

    /// Record events for a series, one per session. Weighted exercises count
    /// top set and e1RM (warm-up reps would otherwise win "most reps");
    /// unweighted ones count reps or duration.
    public static func recordEvents(_ points: [SessionPoint], exercise: Exercise) -> [RecordEvent] {
        let bySession = Dictionary(uniqueKeysWithValues: points.map { ($0.sessionId, $0) })
        var events: [String: RecordEvent] = [:]
        func add(_ kind: RecordEvent.Kind, _ ids: Set<String>) {
            for id in ids where events[id] == nil {
                if let point = bySession[id] { events[id] = RecordEvent(kind: kind, point: point) }
            }
        }
        if exercise.tracksWeight {
            add(.topSet, recordSessions(points, metric: .topSet))
            add(.e1rm, recordSessions(points, metric: .e1rm))
        } else if exercise.tracksReps {
            add(.reps, recordSessions(points, metric: .bestReps, tracksReps: true))
        } else {
            add(.duration, recordSessions(points, metric: .bestReps, tracksReps: false))
        }
        return events.values.sorted { $0.point.date < $1.point.date }
    }

    public static func records(_ points: [SessionPoint]) -> PersonRecords {
        func best(_ metric: ProgressMetric, tracksReps: Bool = true) -> SessionPoint? {
            points.filter { $0.value(metric, tracksReps: tracksReps) != nil }
                .max { $0.value(metric, tracksReps: tracksReps)! < $1.value(metric, tracksReps: tracksReps)! }
        }
        return PersonRecords(
            heaviest: best(.topSet), bestE1RM: best(.e1rm), bestVolume: best(.volume),
            bestReps: best(.bestReps, tracksReps: true), bestDuration: best(.bestReps, tracksReps: false),
            bestDOTS: best(.dots)
        )
    }

    /// Start of the week containing `ms`, in the given calendar.
    public static func weekStart(_ ms: Int64, calendar: Calendar) -> Int64 {
        let date = Date(epochMilliseconds: ms)
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return start.epochMilliseconds
    }
}
