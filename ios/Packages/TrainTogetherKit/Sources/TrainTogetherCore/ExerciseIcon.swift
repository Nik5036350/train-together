/// An exercise's pictogram (the app draws them). Stored by raw value on
/// `Exercise.icon`; an exercise without one, or with a value this version
/// doesn't know, shows the pictogram its name suggests.
public enum ExerciseIcon: String, CaseIterable, Sendable, Hashable {
    case benchPress, fly, pushUp, dip
    case deadlift, row, pulldown, pullUp
    case overheadPress, lateralRaise
    case curl, pushdown, tricepsExtension
    case squat, legPress, lunge, legExtension, legCurl, calfRaise, hipThrust, hipAbduction
    case plank, crunch, legRaise
    case carry, swing, rower, bike, run
    case generic

    public var label: String {
        switch self {
        case .benchPress: "Bench press"
        case .fly: "Fly"
        case .pushUp: "Push-up"
        case .dip: "Dip"
        case .deadlift: "Deadlift"
        case .row: "Row"
        case .pulldown: "Pulldown"
        case .pullUp: "Pull-up"
        case .overheadPress: "Overhead press"
        case .lateralRaise: "Lateral raise"
        case .curl: "Curl"
        case .pushdown: "Pushdown"
        case .tricepsExtension: "Triceps extension"
        case .squat: "Squat"
        case .legPress: "Leg press"
        case .lunge: "Lunge"
        case .legExtension: "Leg extension"
        case .legCurl: "Leg curl"
        case .calfRaise: "Calf raise"
        case .hipThrust: "Hip thrust"
        case .hipAbduction: "Hip abduction"
        case .plank: "Plank"
        case .crunch: "Crunch"
        case .legRaise: "Leg raise"
        case .carry: "Carry"
        case .swing: "Swing"
        case .rower: "Rowing"
        case .bike: "Bike"
        case .run: "Run"
        case .generic: "Other"
        }
    }

    /// The muscle group the movement mostly trains; nil for the generic one.
    public var muscleGroup: MuscleGroup? {
        switch self {
        case .benchPress, .fly, .pushUp, .dip: .chest
        case .deadlift, .row, .pulldown, .pullUp: .back
        case .overheadPress, .lateralRaise: .shoulders
        case .curl, .pushdown, .tricepsExtension: .arms
        case .squat, .legPress, .lunge, .legExtension, .legCurl, .calfRaise, .hipThrust, .hipAbduction: .legs
        case .plank, .crunch, .legRaise: .core
        case .carry, .swing, .rower, .bike, .run: .conditioning
        case .generic: nil
        }
    }

    /// The pictogram an exercise name points to: "Trap bar deadlift" →
    /// deadlift, "Glute bridge" → hip thrust. Unrecognised names get the
    /// generic one.
    public static func suggested(for name: String) -> ExerciseIcon {
        let words = NameWords(name)
        return rules.first { _, phrases in phrases.contains(where: words.contains) }?.icon ?? .generic
    }

    // First match wins, so the specific phrases come before the words they
    // contain ("leg curl" before "curl", "reverse fly" before "fly"). A
    // trailing * matches any ending ("squat*" matches "squats").
    private static let rules: [(icon: ExerciseIcon, phrases: [String])] = [
        (.rower, ["rowing", "rower", "row erg", "erg"]),
        (.bike, ["bike", "cycling", "cycle", "spin"]),
        (.carry, ["carry", "carries", "farmer*", "shrug*"]),
        (.run, ["treadmill", "run", "running", "sprint*", "jog*", "walk"]),
        (.legCurl, ["leg curl*", "hamstring curl*", "nordic*"]),
        (.legExtension, ["leg extension*"]),
        (.legPress, ["leg press*"]),
        (.calfRaise, ["calf*", "calves"]),
        (.hipThrust, ["hip thrust*", "bridge*"]),
        (.hipAbduction, ["abduct*", "adduct*"]),
        (.lunge, ["lunge*", "split squat*", "step up*", "stepup*"]),
        (.squat, ["squat*"]),
        (.swing, ["swing*"]),
        (.deadlift, ["deadlift*", "rdl*", "romanian", "good morning*", "back extension*", "hyperextension*"]),
        (.pullUp, ["pull up*", "pullup*", "chin up*", "chinup*"]),
        (.pulldown, ["pulldown*", "pull down*"]),
        (.lateralRaise, ["lateral raise*", "side raise*", "front raise*", "rear delt*", "reverse fly*",
                         "reverse flye*", "reverse pec*", "upright row*"]),
        (.row, ["row*", "face pull*"]),
        (.pushdown, ["pushdown*", "push down*"]),
        (.tricepsExtension, ["skull*", "triceps extension*", "tricep extension*", "overhead extension*",
                             "french press", "kickback*"]),
        (.curl, ["curl*"]),
        (.fly, ["fly", "flye*", "flies", "crossover*", "pec deck", "pec dec"]),
        (.overheadPress, ["overhead press*", "shoulder press*", "military*", "ohp", "arnold*", "push press*"]),
        (.dip, ["dip*"]),
        (.pushUp, ["push up*", "pushup*"]),
        (.plank, ["plank*", "ab wheel*", "rollout*", "roll out*"]),
        (.legRaise, ["leg raise*", "knee raise*", "toes to bar"]),
        (.crunch, ["crunch*", "sit up*", "situp*", "russian twist*"]),
        (.benchPress, ["bench*", "chest press*", "press*"]),
    ]
}

/// Where an exercise sits in the library.
public enum MuscleGroup: String, CaseIterable, Sendable, Hashable {
    case chest, back, shoulders, arms, legs, core, conditioning

    public var label: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        case .legs: "Legs"
        case .core: "Core"
        case .conditioning: "Conditioning"
        }
    }

    /// Reads a free-text category ("Triceps", "Glutes", "Abs"); nil when it
    /// names no muscle group.
    public init?(category: String) {
        let words = NameWords(category)
        guard let group = Self.categoryWords.first(where: { _, phrases in phrases.contains(where: words.contains) })?.group
        else { return nil }
        self = group
    }

    private static let categoryWords: [(group: MuscleGroup, phrases: [String])] = [
        (.chest, ["chest", "pec*"]),
        (.back, ["back", "lat", "lats", "trap*", "rhomboid*"]),
        (.shoulders, ["shoulder*", "delt*"]),
        (.arms, ["arm", "arms", "bicep*", "tricep*", "forearm*"]),
        (.legs, ["leg", "legs", "quad*", "hamstring*", "glute*", "calf", "calves", "adductor*", "abductor*"]),
        (.core, ["core", "ab", "abs", "abdominal*", "oblique*"]),
        (.conditioning, ["cardio", "conditioning", "full body"]),
    ]
}

extension Exercise {
    /// The chosen pictogram, or the one the name suggests.
    public var resolvedIcon: ExerciseIcon {
        icon.flatMap(ExerciseIcon.init(rawValue:)) ?? .suggested(for: name)
    }

    /// The category when it names a muscle group, else the pictogram's.
    public var muscleGroup: MuscleGroup? {
        MuscleGroup(category: category) ?? resolvedIcon.muscleGroup
    }
}

/// A name as lowercase words ("Pull-Ups" → pull, ups), matched against
/// phrases like "pull up*".
struct NameWords {
    let words: [Substring]

    init(_ text: String) {
        words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
    }

    func contains(_ phrase: String) -> Bool {
        let parts = phrase.split(separator: " ")
        guard parts.count <= words.count else { return false }
        return (0...(words.count - parts.count)).contains { start in
            parts.indices.allSatisfy { i in
                let word = words[start + i], part = parts[i]
                return part.hasSuffix("*") ? word.hasPrefix(part.dropLast()) : word == part
            }
        }
    }
}
