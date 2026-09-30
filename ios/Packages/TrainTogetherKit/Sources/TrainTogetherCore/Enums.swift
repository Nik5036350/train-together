// String-backed domain enums. They are stored and synced as their raw values
// (the same strings the legacy backend used), and decode unknown values to a
// fallback instead of failing, so a record written by a newer app version — or
// a legacy row holding an odd value — still loads.

public protocol TolerantStringEnum: RawRepresentable, Codable, Hashable, Sendable, CaseIterable
where RawValue == String {
    static var fallback: Self { get }
}

extension TolerantStringEnum {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .fallback
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// How the active person moves between people after a set is logged.
public enum LoggingMode: String, TolerantStringEnum {
    /// Both rows stay editable; the turn passes after each set.
    case alternate
    /// Only the active row shows inputs; the turn passes after each set.
    case turns
    /// Both rows stay editable; the turn never moves on its own.
    case independent

    public static let fallback = LoggingMode.alternate

    public var label: String {
        switch self {
        case .alternate: "Alternate"
        case .turns: "Turns"
        case .independent: "Independent"
        }
    }

    /// Whether logging a set hands the turn to the other person.
    public var passesTurn: Bool { self != .independent }
}

/// Who a routine exercise is for. Legacy semantics: any unknown value means
/// the partner.
public enum Assignment: String, TolerantStringEnum {
    case both, owner, partner
    public static let fallback = Assignment.partner
}

/// Which people a new workout includes by default (settings).
public enum Participants: String, TolerantStringEnum {
    case both, owner, partner
    public static let fallback = Participants.both
}

public enum PersonStatus: String, TolerantStringEnum {
    case pending, logged, skipped
    public static let fallback = PersonStatus.pending
}

public enum SessionStatus: String, TolerantStringEnum {
    case active, finished
    /// Legacy backups treated a session without a status as finished.
    public static let fallback = SessionStatus.finished
}

/// Training variants. Each keeps its own "last time", default values and
/// displayed set numbering.
public enum Variant: String, TolerantStringEnum {
    case normal, highReps, maxWeight
    public static let fallback = Variant.normal

    public var label: String {
        switch self {
        case .normal: "Normal"
        case .highReps: "High Reps"
        case .maxWeight: "Max Weight"
        }
    }
}

/// Weight unit per person. Weights are labelled, never converted.
public enum WeightUnit: String, TolerantStringEnum {
    case kg, lb
    public static let fallback = WeightUnit.kg
}

/// Sex, used only for strength scores (the 1RM formula and DOTS). A plain
/// enum rather than a TolerantStringEnum: an unknown value must stay unset,
/// never fall back to a guess.
public enum Sex: String, Codable, Hashable, Sendable, CaseIterable {
    case male, female

    public var label: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}
