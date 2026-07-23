package com.couples.recording.service

import com.couples.recording.domain.AppSettings
import com.couples.recording.domain.Exercise
import com.couples.recording.domain.Person
import com.couples.recording.domain.PersonExerciseProfile
import com.couples.recording.domain.SetEntry
import com.couples.recording.domain.Template
import com.couples.recording.domain.TemplateExercise
import com.couples.recording.domain.WorkoutSession
import com.couples.recording.repository.AppSettingsRepository
import com.couples.recording.repository.ExerciseRepository
import com.couples.recording.repository.PersonExerciseProfileRepository
import com.couples.recording.repository.PersonRepository
import com.couples.recording.repository.RestTimerRepository
import com.couples.recording.repository.SessionExercisePersonRepository
import com.couples.recording.repository.SessionExerciseRepository
import com.couples.recording.repository.SetEntryRepository
import com.couples.recording.repository.TemplateExerciseRepository
import com.couples.recording.repository.TemplateRepository
import com.couples.recording.repository.WorkoutSessionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.time.ZoneId

// Seed data ported verbatim from the frontend's src/store/seed.js (owner Alex,
// partner Maria, the exercise library, per-person profiles, the "Push Day"
// template and one prior-session history entry). Used on first boot and by the
// admin reset-demo endpoint.
@Service
class SeedService(
    private val people: PersonRepository,
    private val exercises: ExerciseRepository,
    private val profiles: PersonExerciseProfileRepository,
    private val templates: TemplateRepository,
    private val templateExercises: TemplateExerciseRepository,
    private val settings: AppSettingsRepository,
    private val sessions: WorkoutSessionRepository,
    private val sessionExercises: SessionExerciseRepository,
    private val sessionExercisePeople: SessionExercisePersonRepository,
    private val sets: SetEntryRepository,
    private val timers: RestTimerRepository,
) {
    @Transactional
    fun seedIfEmpty() {
        if (people.count() == 0L) insertSeed()
    }

    @Transactional
    fun resetToSeed() {
        clearAll()
        insertSeed()
    }

    /** Re-add the seeded "Push Day" template + any seed exercises it references
     * that were deleted, without disturbing the user's own data (RESTORE_DEMO_ROUTINE). */
    @Transactional
    fun restoreDemoRoutine() {
        seedExercises().forEach { ex -> if (!exercises.existsById(ex.id)) exercises.save(ex) }
        templates.save(Template(id = "t_push", name = "Push Day", defaultMode = "alternate"))
        templateExercises.deleteByTemplateId("t_push")
        templateExercises.saveAll(pushDayExercises())
    }

    fun clearAll() {
        timers.deleteAllInBatch()
        sets.deleteAllInBatch()
        sessionExercisePeople.deleteAllInBatch()
        sessionExercises.deleteAllInBatch()
        sessions.deleteAll() // deleteAll (not batch) so element-collection rows are removed
        templateExercises.deleteAllInBatch()
        templates.deleteAllInBatch()
        profiles.deleteAllInBatch()
        exercises.deleteAllInBatch()
        people.deleteAllInBatch()
        settings.deleteAllInBatch()
    }

    private fun insertSeed() {
        settings.save(AppSettings()) // defaults match the seed settings

        people.save(Person("p_alex", "Alex", "A", "blue", "kg", isOwner = true, active = true))
        people.save(Person("p_maria", "Maria", "M", "orange", "kg", isOwner = false, active = true))

        exercises.saveAll(seedExercises())

        profiles.saveAll(
            listOf(
                profile("p_alex", "ex_bench", 150),
                profile("p_maria", "ex_bench", 120),
                profile("p_alex", "ex_incline", 120),
                profile("p_maria", "ex_incline", 90),
                profile("p_maria", "ex_cablefly", 90),
                profile("p_alex", "ex_dip", 150),
                profile("p_alex", "ex_pushdown", 90),
                profile("p_maria", "ex_pushdown", 90, machineSetup = "Rope attachment"),
            ),
        )

        templates.save(Template("t_push", "Push Day", "alternate"))
        templateExercises.saveAll(pushDayExercises())

        insertSeedHistory()
    }

    private fun seedExercises() = listOf(
        Exercise("ex_bench", "Bench Press", "Chest", "Barbell", true, true, false, 120),
        Exercise("ex_incline", "Incline DB Press", "Chest", "Dumbbell", true, true, false, 120),
        Exercise("ex_cablefly", "Cable Fly", "Chest", "Cable Machine", true, true, false, 90),
        Exercise("ex_dip", "Weighted Dip", "Triceps", "Bodyweight", true, true, false, 120),
        Exercise("ex_pushdown", "Triceps Pushdown", "Triceps", "Cable Machine", true, true, false, 90),
        Exercise("ex_machinechest", "Machine Chest Press", "Chest", "Machine", true, true, false, 90),
        Exercise("ex_facepull", "Face Pull", "Shoulders", "Cable Machine", true, true, false, 60),
        Exercise("ex_plank", "Plank", "Core", "Bodyweight", false, false, true, 60),
    )

    private fun pushDayExercises() = listOf(
        TemplateExercise(Ids.uid("tex"), "t_push", "ex_bench", "both", 0),
        TemplateExercise(Ids.uid("tex"), "t_push", "ex_incline", "both", 1),
        TemplateExercise(Ids.uid("tex"), "t_push", "ex_cablefly", "partner", 2),
        TemplateExercise(Ids.uid("tex"), "t_push", "ex_dip", "owner", 3),
        TemplateExercise(Ids.uid("tex"), "t_push", "ex_pushdown", "both", 4),
    )

    private fun profile(personId: String, exerciseId: String, rest: Int, machineSetup: String = "") =
        PersonExerciseProfile(Ids.uid("prof"), personId, exerciseId, rest, machineSetup, "")

    private fun insertSeedHistory() {
        val zone = ZoneId.systemDefault()
        val start = LocalDateTime.parse("2026-06-23T18:00:00").atZone(zone).toInstant().toEpochMilli()
        val end = LocalDateTime.parse("2026-06-23T19:12:00").atZone(zone).toInstant().toEpochMilli()
        val sessionId = "sess_prev"
        sessions.save(
            WorkoutSession(
                id = sessionId,
                templateId = "t_push",
                name = "Push Day",
                startTime = start,
                endTime = end,
                label = "Mon",
                loggingStyle = "alternate",
                status = "finished",
                participantIds = mutableListOf("p_alex", "p_maria"),
            ),
        )
        val rows = listOf(
            // exerciseId, personId, weight, reps, setIndex
            h("ex_bench", "p_alex", 80.0, 8, 0), h("ex_bench", "p_alex", 80.0, 7, 1), h("ex_bench", "p_alex", 77.5, 8, 2),
            h("ex_bench", "p_maria", 35.0, 10, 0), h("ex_bench", "p_maria", 35.0, 9, 1), h("ex_bench", "p_maria", 35.0, 8, 2),
            h("ex_incline", "p_alex", 30.0, 9, 0), h("ex_incline", "p_alex", 30.0, 8, 1), h("ex_incline", "p_alex", 28.0, 10, 2),
            h("ex_incline", "p_maria", 14.0, 12, 0), h("ex_incline", "p_maria", 14.0, 11, 1), h("ex_incline", "p_maria", 14.0, 10, 2),
            h("ex_cablefly", "p_maria", 12.5, 15, 0), h("ex_cablefly", "p_maria", 12.5, 13, 1), h("ex_cablefly", "p_maria", 12.5, 12, 2),
            h("ex_dip", "p_alex", 15.0, 8, 0), h("ex_dip", "p_alex", 15.0, 7, 1), h("ex_dip", "p_alex", 10.0, 8, 2),
            h("ex_pushdown", "p_alex", 40.0, 12, 0), h("ex_pushdown", "p_alex", 40.0, 10, 1), h("ex_pushdown", "p_alex", 37.5, 11, 2),
            h("ex_pushdown", "p_maria", 22.5, 12, 0), h("ex_pushdown", "p_maria", 22.5, 11, 1), h("ex_pushdown", "p_maria", 22.5, 10, 2),
        ).map { it.copy2(sessionId) }
        sets.saveAll(rows)
    }

    private fun h(exerciseId: String, personId: String, weight: Double, reps: Int, idx: Int) =
        SetEntry(
            id = "h1_${exerciseId}_${personId}_$idx",
            sessionId = "",
            sessionExerciseId = null,
            exerciseId = exerciseId,
            personId = personId,
            setIndex = idx,
            weight = weight,
            reps = reps,
            duration = null,
            setType = "working",
            timestamp = null,
        )

    private fun SetEntry.copy2(sessionId: String) = apply { this.sessionId = sessionId }
}
