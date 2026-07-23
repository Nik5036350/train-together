package com.couples.recording.service

import com.couples.recording.controller.dto.SessionDto
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.domain.AppSettings
import com.couples.recording.domain.Exercise
import com.couples.recording.domain.Person
import com.couples.recording.domain.PersonExerciseProfile
import com.couples.recording.domain.RestTimer
import com.couples.recording.domain.SessionExercise
import com.couples.recording.domain.SessionExercisePerson
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

// Admin / backup operations: factory reset, restore demo routine, and full
// import (replace-all) from an exported aggregate (the old RESET_DEMO /
// RESTORE_DEMO_ROUTINE / HYDRATE reducer actions).
@Service
class AdminService(
    private val seedService: SeedService,
    private val people: PersonRepository,
    private val settings: AppSettingsRepository,
    private val exercises: ExerciseRepository,
    private val profiles: PersonExerciseProfileRepository,
    private val templates: TemplateRepository,
    private val templateExercises: TemplateExerciseRepository,
    private val sessions: WorkoutSessionRepository,
    private val sessionExercises: SessionExerciseRepository,
    private val sessionExercisePeople: SessionExercisePersonRepository,
    private val sets: SetEntryRepository,
    private val timers: RestTimerRepository,
) {
    @Transactional
    fun resetDemo() = seedService.resetToSeed()

    @Transactional
    fun restoreDemoRoutine() = seedService.restoreDemoRoutine()

    @Transactional
    fun importState(state: StateResponse) {
        seedService.clearAll()

        settings.save(
            AppSettings(
                coupleModeEnabled = state.settings.coupleModeEnabled,
                defaultParticipants = state.settings.defaultParticipants,
                defaultLoggingStyle = state.settings.defaultLoggingStyle,
                allowCopyPartnerValues = state.settings.allowCopyPartnerValues,
                showPartnerHistory = state.settings.showPartnerHistory,
                onboarded = state.onboarded,
                version = state.version,
            ),
        )

        people.saveAll(
            state.people.map { Person(it.id, it.name, it.initials, it.color, it.unit, it.isOwner, it.active) },
        )

        exercises.saveAll(
            state.exercises.values.map {
                Exercise(
                    it.id, it.name, it.category, it.equipment,
                    it.tracks.weight, it.tracks.reps, it.tracks.duration, it.defaultRestSeconds,
                )
            },
        )

        profiles.saveAll(
            state.personExerciseProfiles.map { (key, p) ->
                val (personId, exerciseId) = key.split("__", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
                PersonExerciseProfile(Ids.uid("prof"), personId, exerciseId, p.restSeconds, p.machineSetup, p.cues)
            },
        )

        state.templates.values.forEach { tpl ->
            templates.save(Template(tpl.id, tpl.name, tpl.defaultMode))
            templateExercises.saveAll(
                tpl.exercises.map {
                    TemplateExercise(Ids.uid("tex"), tpl.id, it.exerciseId, it.assignment, it.order, it.defaultLoggingMode)
                },
            )
        }

        state.history.forEach { persistSession(it) }
        state.session?.let { persistSession(it) }
    }

    private fun persistSession(s: SessionDto) {
        sessions.save(
            WorkoutSession(
                id = s.id,
                templateId = s.templateId,
                name = s.name,
                startTime = s.startTime,
                endTime = s.endTime,
                label = s.label,
                loggingStyle = s.loggingStyle,
                status = s.status,
                participantIds = s.participantIds.toMutableList(),
            ),
        )
        s.exercises.forEachIndexed { order, se ->
            sessionExercises.save(
                SessionExercise(
                    id = se.id,
                    sessionId = s.id,
                    exerciseId = se.exerciseId,
                    loggingMode = se.loggingMode,
                    activePersonId = se.activePersonId,
                    addedDuringSession = se.addedDuringSession ?: false,
                    orderIndex = order,
                ),
            )
            se.appliesTo.forEachIndexed { i, personId ->
                val pp = se.perPerson[personId]
                sessionExercisePeople.save(
                    SessionExercisePerson(
                        Ids.uid("sep"), se.id, personId,
                        pp?.status ?: "pending", pp?.skipReason, pp?.substituteExerciseId, i,
                    ),
                )
            }
        }
        sets.saveAll(
            s.sets.map {
                SetEntry(
                    id = it.id,
                    sessionId = s.id,
                    sessionExerciseId = it.sessionExerciseId,
                    exerciseId = it.exerciseId,
                    personId = it.personId,
                    setIndex = it.setIndex,
                    weight = it.weight,
                    reps = it.reps,
                    duration = it.duration,
                    setType = it.setType,
                    timestamp = it.timestamp,
                    note = it.note,
                )
            },
        )
        s.timers.forEach { (personId, t) ->
            timers.save(RestTimer(Ids.uid("tmr"), s.id, personId, t.sessionExerciseId, t.startedAt, t.durationSeconds))
        }
    }
}
