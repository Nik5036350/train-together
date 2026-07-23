package com.couples.recording.service

import com.couples.recording.controller.dto.ExerciseDto
import com.couples.recording.controller.dto.PerPersonDto
import com.couples.recording.controller.dto.PersonDto
import com.couples.recording.controller.dto.ProfileDto
import com.couples.recording.controller.dto.SessionDto
import com.couples.recording.controller.dto.SessionExerciseDto
import com.couples.recording.controller.dto.SetDto
import com.couples.recording.controller.dto.SettingsDto
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.controller.dto.TemplateDto
import com.couples.recording.controller.dto.TemplateExerciseDto
import com.couples.recording.controller.dto.TimerDto
import com.couples.recording.controller.dto.TracksDto
import com.couples.recording.domain.AppSettings
import com.couples.recording.domain.Exercise
import com.couples.recording.domain.Person
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

// Reassembles the normalized tables back into the single aggregate JSON tree the
// frontend expects. Read-only.
@Service
class StateService(
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
    @Transactional(readOnly = true)
    fun getState(): StateResponse {
        val settingsRow = settings.findById(AppSettings.SINGLETON_ID).orElseGet { AppSettings() }

        val exerciseDtos = exercises.findAll().associate { it.id to it.toDto() }

        val profileDtos = profiles.findAll().associate {
            "${it.personId}__${it.exerciseId}" to ProfileDto(it.restSeconds, it.machineSetup, it.cues)
        }

        val templateDtos = templates.findAll().associate { tpl ->
            val exs = templateExercises.findByTemplateIdOrderByOrderIndexAsc(tpl.id).map {
                TemplateExerciseDto(it.exerciseId, it.assignment, it.orderIndex, it.defaultLoggingMode)
            }
            tpl.id to TemplateDto(tpl.id, tpl.name, tpl.defaultMode, exs)
        }

        val history = sessions.findByStatusOrderByStartTimeDesc("finished").map { buildSessionDto(it) }
        val active = sessions.findFirstByStatus("active")?.let { buildSessionDto(it) }

        return StateResponse(
            version = settingsRow.version,
            onboarded = settingsRow.onboarded,
            people = people.findAll().map { it.toDto() },
            settings = settingsRow.toDto(),
            exercises = exerciseDtos,
            personExerciseProfiles = profileDtos,
            templates = templateDtos,
            history = history,
            session = active,
        )
    }

    private fun buildSessionDto(s: WorkoutSession): SessionDto {
        val seDtos = sessionExercises.findBySessionIdOrderByOrderIndexAsc(s.id).map { se ->
            val persons = sessionExercisePeople.findBySessionExerciseIdOrderByOrderIndexAsc(se.id)
            val appliesTo = persons.map { it.personId }
            val perPerson = persons.associate {
                it.personId to PerPersonDto(it.status, it.skipReason, it.substituteExerciseId)
            }
            SessionExerciseDto(
                id = se.id,
                exerciseId = se.exerciseId,
                appliesTo = appliesTo,
                loggingMode = se.loggingMode,
                activePersonId = se.activePersonId,
                addedDuringSession = if (se.addedDuringSession) true else null,
                perPerson = perPerson,
            )
        }

        val setDtos = sets.findBySessionId(s.id)
            .sortedWith(compareBy({ it.timestamp ?: 0L }, { it.setIndex }))
            .map {
                SetDto(
                    id = it.id,
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
            }

        val timerMap = timers.findBySessionId(s.id).associate {
            it.personId to TimerDto(it.sessionExerciseId, it.startedAt, it.durationSeconds)
        }

        return SessionDto(
            id = s.id,
            templateId = s.templateId,
            name = s.name,
            startTime = s.startTime,
            endTime = s.endTime,
            label = s.label,
            participantIds = s.participantIds.toList(),
            loggingStyle = s.loggingStyle,
            status = s.status,
            exercises = seDtos,
            sets = setDtos,
            timers = timerMap,
        )
    }
}

private fun Person.toDto() = PersonDto(id, name, initials, color, unit, isOwner, active)

private fun Exercise.toDto() =
    ExerciseDto(id, name, category, equipment, TracksDto(tracksWeight, tracksReps, tracksDuration), defaultRestSeconds)

private fun AppSettings.toDto() =
    SettingsDto(coupleModeEnabled, defaultParticipants, defaultLoggingStyle, allowCopyPartnerValues, showPartnerHistory)
