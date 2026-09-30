import Foundation
import Testing
@testable import TrainTogetherCore
@testable import TrainTogetherKit

@Suite struct ExerciseIcons {
    @Test func namesSuggestTheirPictogram() {
        let cases: [(String, ExerciseIcon)] = [
            // The library on the phone today, typed by hand.
            ("Deadlift", .deadlift), ("Squat", .squat), ("Glute bridge", .hipThrust),
            ("Leg press", .legPress), ("Trap bar deadlift", .deadlift), ("Bench press", .benchPress),
            // Specific phrases beat the words inside them.
            ("Leg curl", .legCurl), ("Barbell curl", .curl), ("Reverse fly", .lateralRaise), ("Cable fly", .fly),
            ("Upright row", .lateralRaise), ("Rowing machine", .rower), ("Bulgarian split squat", .lunge),
            ("Farmer's walk", .carry), ("Walking lunges", .lunge), ("Hanging leg raise", .legRaise),
            // Plurals and punctuation.
            ("Pull-ups", .pullUp), ("PUSHUPS", .pushUp), ("Incline DB Press", .benchPress), ("Weighted Dip", .dip),
            ("Zercher carry-over", .carry), ("Turkish get-up", .generic), ("", .generic),
        ]
        for (name, icon) in cases {
            #expect(ExerciseIcon.suggested(for: name) == icon, "\(name)")
        }
    }

    @Test func aPickedIconWinsAndAnUnknownOneFollowsTheName() {
        var exercise = Exercise(id: "x", name: "Squat")
        #expect(exercise.resolvedIcon == .squat)
        exercise.icon = ExerciseIcon.lunge.rawValue
        #expect(exercise.resolvedIcon == .lunge)
        exercise.icon = "fromANewerVersion"
        #expect(exercise.resolvedIcon == .squat)
    }

    @Test func categoriesNameMuscleGroups() {
        #expect(MuscleGroup(category: "Triceps") == .arms)
        #expect(MuscleGroup(category: "Glutes") == .legs)
        #expect(MuscleGroup(category: "Lower back") == .back)
        #expect(MuscleGroup(category: "") == nil)
        #expect(Exercise(id: "x", name: "Squat").muscleGroup == .legs)
        #expect(Exercise(id: "x", name: "Mystery move", category: "Abs").muscleGroup == .core)
        #expect(Exercise(id: "x", name: "Mystery move").muscleGroup == nil)
    }
}

@Suite struct PopularExerciseList {
    @Test func idsAndNamesAreUnique() {
        let all = PopularExercises.all
        #expect(Set(all.map(\.id)).count == all.count)
        let names = all.flatMap { [$0.name] + $0.aliases }.map(PopularExercise.key)
        #expect(Set(names).count == names.count)
    }

    @Test func everyNameSuggestsItsOwnPictogram() {
        // So an entry and the same exercise typed by hand look alike.
        for entry in PopularExercises.all {
            #expect(ExerciseIcon.suggested(for: entry.name) == entry.icon, "\(entry.name)")
            #expect(entry.tracksWeight || entry.tracksReps || entry.tracksDuration, "\(entry.name)")
        }
    }

    @Test func sharedDemoIdsAreTheSameExercise() {
        for demo in WorkoutEngine.demoExercises {
            if let entry = PopularExercises.entry(id: demo.id) {
                #expect(entry.matches(name: demo.name), "\(demo.name)")
            }
        }
    }

    @Test func whatTheLibraryHasIsNotOffered() {
        let library = [Exercise(id: "ex_mine_1", name: "back squat"), Exercise(id: "ex_bench", name: "Bench (paused)")]
        let missing = Set(PopularExercises.missing(from: library).map(\.id))
        #expect(!missing.contains("ex_squat"))
        #expect(!missing.contains("ex_bench"))
        #expect(missing.contains("ex_deadlift"))
    }

    @Test func addingIsIdempotentAndReusesSameNamedExercises() throws {
        let world = try World()
        #expect(try world.engine.addPopularExercise(id: "ex_bench") == "ex_bench")
        let squat = try world.engine.saveExercise(ExerciseDraft(name: "back squat"))
        #expect(try world.engine.addPopularExercise(id: "ex_squat") == squat)
        #expect(try world.engine.addPopularExercise(id: "ex_lat_pulldown") == "ex_lat_pulldown")
        #expect(try world.engine.addPopularExercise(id: "ex_lat_pulldown") == "ex_lat_pulldown")

        let catalog = try world.snapshot().catalog
        let pulldown = try #require(catalog.exercise("ex_lat_pulldown"))
        #expect(pulldown.icon == "pulldown")
        #expect(pulldown.category == "Back")
        #expect(pulldown.equipment == "Cable Machine")
        #expect(catalog.exercises.filter { $0.name == "Lat Pulldown" }.count == 1)
        #expect(catalog.exercises.filter { $0.name == "Bench Press" }.count == 1)
        #expect(throws: EngineError.self) { try world.engine.addPopularExercise(id: "ex_nope") }
    }

    @Test func aPickedIconSavesSyncsAndClears() throws {
        let world = try World()
        var draft = ExerciseDraft(try #require(try world.snapshot().catalog.exercise("ex_bench")))
        #expect(draft.icon == nil)
        draft.icon = .fly
        try world.engine.saveExercise(draft)
        #expect(try world.snapshot().catalog.exercise("ex_bench")?.icon == "fly")
        let payload = try world.database.writer.read { db in
            try SyncState.payload(db, entity: Exercise.entityName, id: "ex_bench")
        }
        guard case .object(let fields) = payload else { Issue.record("no payload"); return }
        #expect(fields["icon"] == .string("fly"))

        draft.icon = nil
        try world.engine.saveExercise(draft)
        #expect(try world.snapshot().catalog.exercise("ex_bench")?.icon == nil)
    }
}
