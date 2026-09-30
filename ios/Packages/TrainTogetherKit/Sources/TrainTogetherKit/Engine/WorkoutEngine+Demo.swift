import GRDB
import TrainTogetherCore

// The example "Push Day" routine and its exercises, ported from
// backend/src/services/seed.rs. Stable ids match the legacy seed, so restoring
// it on a phone that has the imported seed updates rather than duplicates.

extension WorkoutEngine {
    static let demoExercises: [Exercise] = [
        Exercise(id: "ex_bench", name: "Bench Press", category: "Chest", equipment: "Barbell", defaultRestSeconds: 120),
        Exercise(id: "ex_incline", name: "Incline DB Press", category: "Chest", equipment: "Dumbbell", defaultRestSeconds: 120),
        Exercise(id: "ex_cablefly", name: "Cable Fly", category: "Chest", equipment: "Cable Machine", defaultRestSeconds: 90),
        Exercise(id: "ex_dip", name: "Weighted Dip", category: "Triceps", equipment: "Bodyweight", defaultRestSeconds: 120),
        Exercise(id: "ex_pushdown", name: "Triceps Pushdown", category: "Triceps", equipment: "Cable Machine", defaultRestSeconds: 90),
        Exercise(id: "ex_machinechest", name: "Machine Chest Press", category: "Chest", equipment: "Machine", defaultRestSeconds: 90),
        Exercise(id: "ex_facepull", name: "Face Pull", category: "Shoulders", equipment: "Cable Machine", defaultRestSeconds: 60),
        Exercise(id: "ex_plank", name: "Plank", category: "Core", equipment: "Bodyweight",
                 tracksWeight: false, tracksReps: false, tracksDuration: true, defaultRestSeconds: 60),
    ]

    static let demoTemplateID = "t_push"

    static let demoRoutine: [(exerciseId: String, assignment: Assignment)] = [
        ("ex_bench", .both),
        ("ex_incline", .both),
        ("ex_cablefly", .partner),
        ("ex_dip", .owner),
        ("ex_pushdown", .both),
    ]

    /// Re-adds any missing example exercises and (re)creates "Push Day",
    /// leaving everything else alone.
    public func restoreDemoRoutine() throws {
        try write { db in
            for exercise in Self.demoExercises {
                if try !Exercise.exists(db, key: exercise.id) { try exercise.insert(db) }
            }
            try WorkoutTemplate(id: Self.demoTemplateID, name: "Push Day", defaultMode: .alternate).save(db)
            try TemplateExercise.filter(Column("templateId") == Self.demoTemplateID).deleteAll(db)
            for (index, row) in Self.demoRoutine.enumerated() {
                try TemplateExercise(
                    id: "tex_\(Self.demoTemplateID)_\(index)", templateId: Self.demoTemplateID,
                    exerciseId: row.exerciseId, assignment: row.assignment, orderIndex: index
                ).insert(db)
            }
        }
    }
}
