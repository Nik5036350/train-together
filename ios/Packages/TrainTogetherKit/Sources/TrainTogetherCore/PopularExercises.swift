/// A well-known exercise offered before it's in the library. Picking one adds
/// it under its fixed id, so it can't be added twice. Ids shared with the
/// demo routine (`ex_bench`, …) are the same exercise.
public struct PopularExercise: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    /// Other names people give it; an exercise called any of them counts as
    /// this one ("Back Squat" for "Squat").
    public let aliases: [String]
    public let group: MuscleGroup
    public let equipment: String
    public let icon: ExerciseIcon
    public let tracksWeight: Bool
    public let tracksReps: Bool
    public let tracksDuration: Bool
    public let defaultRestSeconds: Int

    init(
        _ id: String, _ name: String, aliases: [String] = [], _ group: MuscleGroup, _ equipment: String,
        _ icon: ExerciseIcon, tracks: Tracks = .weightReps, rest: Int = Exercise.defaultRestSeconds
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.group = group
        self.equipment = equipment
        self.icon = icon
        self.tracksWeight = tracks.contains(.weight)
        self.tracksReps = tracks.contains(.reps)
        self.tracksDuration = tracks.contains(.duration)
        self.defaultRestSeconds = rest
    }

    struct Tracks: OptionSet {
        let rawValue: Int
        static let weight = Tracks(rawValue: 1)
        static let reps = Tracks(rawValue: 2)
        static let duration = Tracks(rawValue: 4)
        static let weightReps: Tracks = [.weight, .reps]
    }

    /// The library record this adds.
    public var exercise: Exercise {
        Exercise(
            id: id, name: name, category: group.label, equipment: equipment,
            tracksWeight: tracksWeight, tracksReps: tracksReps, tracksDuration: tracksDuration,
            defaultRestSeconds: defaultRestSeconds, icon: icon.rawValue
        )
    }

    /// Whether `name` is this exercise's name or one of its aliases, ignoring
    /// case, spaces and punctuation.
    public func matches(name: String) -> Bool {
        let key = Self.key(name)
        return Self.key(self.name) == key || aliases.contains { Self.key($0) == key }
    }

    static func key(_ name: String) -> String {
        String(name.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}

public enum PopularExercises {
    /// The ones the library doesn't have yet, by id or by name.
    public static func missing(from library: [Exercise]) -> [PopularExercise] {
        let ids = Set(library.map(\.id))
        let names = Set(library.map { PopularExercise.key($0.name) })
        return all.filter { entry in
            !ids.contains(entry.id) && !names.contains(PopularExercise.key(entry.name))
                && !entry.aliases.contains { names.contains(PopularExercise.key($0)) }
        }
    }

    public static func entry(id: String) -> PopularExercise? {
        all.first { $0.id == id }
    }

    public static let all: [PopularExercise] = [
        // Chest
        .init("ex_bench", "Bench Press", aliases: ["Barbell Bench Press", "Flat Bench Press"], .chest, "Barbell", .benchPress, rest: 120),
        .init("ex_incline_bench", "Incline Bench Press", aliases: ["Incline Barbell Press"], .chest, "Barbell", .benchPress, rest: 120),
        .init("ex_db_bench", "Dumbbell Bench Press", aliases: ["DB Bench Press"], .chest, "Dumbbell", .benchPress, rest: 120),
        .init("ex_incline", "Incline Dumbbell Press", aliases: ["Incline DB Press"], .chest, "Dumbbell", .benchPress, rest: 120),
        .init("ex_machinechest", "Machine Chest Press", aliases: ["Chest Press", "Chest Press Machine"], .chest, "Machine", .benchPress),
        .init("ex_cablefly", "Cable Fly", aliases: ["Cable Crossover"], .chest, "Cable Machine", .fly),
        .init("ex_pec_deck", "Pec Deck", aliases: ["Machine Fly", "Pec Deck Fly"], .chest, "Machine", .fly, rest: 60),
        .init("ex_pushup", "Push-Up", aliases: ["Push-Ups"], .chest, "Bodyweight", .pushUp, tracks: .reps, rest: 60),
        .init("ex_dip", "Dip", aliases: ["Dips", "Weighted Dip"], .chest, "Bodyweight", .dip, tracks: .reps, rest: 120),

        // Back
        .init("ex_deadlift", "Deadlift", aliases: ["Barbell Deadlift", "Conventional Deadlift"], .back, "Barbell", .deadlift, rest: 180),
        .init("ex_trapbar_deadlift", "Trap Bar Deadlift", aliases: ["Hex Bar Deadlift"], .back, "Trap Bar", .deadlift, rest: 180),
        .init("ex_back_extension", "Back Extension", aliases: ["Hyperextension"], .back, "Bodyweight", .deadlift, rest: 60),
        .init("ex_barbell_row", "Barbell Row", aliases: ["Bent-Over Row", "Bent Over Barbell Row"], .back, "Barbell", .row, rest: 120),
        .init("ex_db_row", "Dumbbell Row", aliases: ["One-Arm Dumbbell Row", "DB Row"], .back, "Dumbbell", .row),
        .init("ex_cable_row", "Seated Cable Row", aliases: ["Cable Row"], .back, "Cable Machine", .row),
        .init("ex_tbar_row", "T-Bar Row", .back, "Barbell", .row, rest: 120),
        .init("ex_lat_pulldown", "Lat Pulldown", aliases: ["Pulldown"], .back, "Cable Machine", .pulldown),
        .init("ex_pullup", "Pull-Up", aliases: ["Pull-Ups"], .back, "Bodyweight", .pullUp, tracks: .reps, rest: 120),
        .init("ex_chinup", "Chin-Up", aliases: ["Chin-Ups"], .back, "Bodyweight", .pullUp, tracks: .reps, rest: 120),
        .init("ex_shrug", "Shrug", aliases: ["Dumbbell Shrug", "Barbell Shrug"], .back, "Dumbbell", .carry, rest: 60),

        // Shoulders
        .init("ex_ohp", "Overhead Press", aliases: ["OHP", "Military Press", "Barbell Overhead Press"], .shoulders, "Barbell", .overheadPress, rest: 120),
        .init("ex_db_shoulder_press", "Dumbbell Shoulder Press", aliases: ["DB Shoulder Press", "Seated Dumbbell Press"], .shoulders, "Dumbbell", .overheadPress),
        .init("ex_machine_shoulder_press", "Machine Shoulder Press", aliases: ["Shoulder Press Machine", "Shoulder Press"], .shoulders, "Machine", .overheadPress),
        .init("ex_lateral_raise", "Lateral Raise", aliases: ["Side Raise", "Dumbbell Lateral Raise"], .shoulders, "Dumbbell", .lateralRaise, rest: 60),
        .init("ex_rear_delt_fly", "Rear Delt Fly", aliases: ["Reverse Fly", "Reverse Pec Deck"], .shoulders, "Dumbbell", .lateralRaise, rest: 60),
        .init("ex_front_raise", "Front Raise", .shoulders, "Dumbbell", .lateralRaise, rest: 60),
        .init("ex_facepull", "Face Pull", .shoulders, "Cable Machine", .row, rest: 60),

        // Arms
        .init("ex_barbell_curl", "Barbell Curl", aliases: ["EZ Bar Curl"], .arms, "Barbell", .curl, rest: 60),
        .init("ex_db_curl", "Dumbbell Curl", aliases: ["DB Curl", "Biceps Curl", "Bicep Curl"], .arms, "Dumbbell", .curl, rest: 60),
        .init("ex_hammer_curl", "Hammer Curl", .arms, "Dumbbell", .curl, rest: 60),
        .init("ex_preacher_curl", "Preacher Curl", .arms, "EZ Bar", .curl, rest: 60),
        .init("ex_pushdown", "Triceps Pushdown", aliases: ["Tricep Pushdown", "Cable Pushdown", "Rope Pushdown"], .arms, "Cable Machine", .pushdown),
        .init("ex_overhead_extension", "Overhead Triceps Extension", aliases: ["Overhead Tricep Extension"], .arms, "Dumbbell", .tricepsExtension, rest: 60),
        .init("ex_skullcrusher", "Skull Crusher", aliases: ["Lying Triceps Extension"], .arms, "EZ Bar", .tricepsExtension, rest: 60),
        .init("ex_closegrip_bench", "Close-Grip Bench Press", .arms, "Barbell", .benchPress, rest: 120),

        // Legs
        .init("ex_squat", "Squat", aliases: ["Back Squat", "Barbell Squat"], .legs, "Barbell", .squat, rest: 180),
        .init("ex_front_squat", "Front Squat", .legs, "Barbell", .squat, rest: 180),
        .init("ex_goblet_squat", "Goblet Squat", .legs, "Dumbbell", .squat),
        .init("ex_hack_squat", "Hack Squat", .legs, "Machine", .squat, rest: 120),
        .init("ex_leg_press", "Leg Press", .legs, "Machine", .legPress, rest: 120),
        .init("ex_rdl", "Romanian Deadlift", aliases: ["RDL"], .legs, "Barbell", .deadlift, rest: 120),
        .init("ex_lunge", "Walking Lunge", aliases: ["Lunge", "Lunges", "Dumbbell Lunge"], .legs, "Dumbbell", .lunge),
        .init("ex_split_squat", "Bulgarian Split Squat", aliases: ["Split Squat"], .legs, "Dumbbell", .lunge),
        .init("ex_step_up", "Step-Up", aliases: ["Step-Ups"], .legs, "Dumbbell", .lunge),
        .init("ex_leg_extension", "Leg Extension", .legs, "Machine", .legExtension, rest: 60),
        .init("ex_leg_curl", "Leg Curl", aliases: ["Lying Leg Curl", "Seated Leg Curl", "Hamstring Curl"], .legs, "Machine", .legCurl, rest: 60),
        .init("ex_calf_raise", "Standing Calf Raise", aliases: ["Calf Raise"], .legs, "Machine", .calfRaise, rest: 60),
        .init("ex_seated_calf_raise", "Seated Calf Raise", .legs, "Machine", .calfRaise, rest: 60),
        .init("ex_hip_thrust", "Hip Thrust", aliases: ["Barbell Hip Thrust"], .legs, "Barbell", .hipThrust),
        .init("ex_glute_bridge", "Glute Bridge", .legs, "Barbell", .hipThrust),
        .init("ex_hip_abduction", "Hip Abduction", aliases: ["Hip Abductor", "Abductor Machine"], .legs, "Machine", .hipAbduction, rest: 60),
        .init("ex_hip_adduction", "Hip Adduction", aliases: ["Hip Adductor", "Adductor Machine"], .legs, "Machine", .hipAbduction, rest: 60),

        // Core
        .init("ex_plank", "Plank", .core, "Bodyweight", .plank, tracks: .duration, rest: 60),
        .init("ex_side_plank", "Side Plank", .core, "Bodyweight", .plank, tracks: .duration, rest: 60),
        .init("ex_ab_wheel", "Ab Wheel Rollout", aliases: ["Ab Rollout", "Ab Wheel"], .core, "Bodyweight", .plank, tracks: .reps, rest: 60),
        .init("ex_crunch", "Crunch", aliases: ["Crunches"], .core, "Bodyweight", .crunch, tracks: .reps, rest: 60),
        .init("ex_cable_crunch", "Cable Crunch", .core, "Cable Machine", .crunch, rest: 60),
        .init("ex_hanging_leg_raise", "Hanging Leg Raise", aliases: ["Leg Raise", "Hanging Knee Raise"], .core, "Bodyweight", .legRaise, tracks: .reps, rest: 60),

        // Conditioning
        .init("ex_farmers_carry", "Farmer's Carry", aliases: ["Farmer's Walk", "Farmer Carry"], .conditioning, "Dumbbell", .carry, tracks: [.weight, .duration]),
        .init("ex_kb_swing", "Kettlebell Swing", aliases: ["KB Swing"], .conditioning, "Kettlebell", .swing, rest: 60),
        .init("ex_rowing_machine", "Rowing Machine", aliases: ["Rower", "Row Erg", "Rowing"], .conditioning, "Machine", .rower, tracks: .duration, rest: 60),
        .init("ex_bike", "Exercise Bike", aliases: ["Stationary Bike", "Spin Bike", "Bike"], .conditioning, "Machine", .bike, tracks: .duration, rest: 60),
        .init("ex_treadmill", "Treadmill", aliases: ["Running", "Run"], .conditioning, "Machine", .run, tracks: .duration, rest: 60),
    ]
}
