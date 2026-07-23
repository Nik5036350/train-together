package com.couples.recording.repository

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
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface PersonRepository : JpaRepository<Person, String> {
    fun findByIsOwnerTrue(): Person?
    fun findByIsOwnerFalseAndActiveTrue(): Person?
}

@Repository
interface ExerciseRepository : JpaRepository<Exercise, String>

@Repository
interface PersonExerciseProfileRepository : JpaRepository<PersonExerciseProfile, String> {
    fun findByPersonIdAndExerciseId(personId: String, exerciseId: String): PersonExerciseProfile?
    fun findByExerciseId(exerciseId: String): List<PersonExerciseProfile>
}

@Repository
interface TemplateRepository : JpaRepository<Template, String>

@Repository
interface TemplateExerciseRepository : JpaRepository<TemplateExercise, String> {
    fun findByTemplateIdOrderByOrderIndexAsc(templateId: String): List<TemplateExercise>
    fun findByExerciseId(exerciseId: String): List<TemplateExercise>
    fun deleteByTemplateId(templateId: String)
}

@Repository
interface AppSettingsRepository : JpaRepository<AppSettings, String>

@Repository
interface WorkoutSessionRepository : JpaRepository<WorkoutSession, String> {
    fun findFirstByStatus(status: String): WorkoutSession?
    fun findByStatusOrderByStartTimeDesc(status: String): List<WorkoutSession>
}

@Repository
interface SessionExerciseRepository : JpaRepository<SessionExercise, String> {
    fun findBySessionIdOrderByOrderIndexAsc(sessionId: String): List<SessionExercise>
}

@Repository
interface SessionExercisePersonRepository : JpaRepository<SessionExercisePerson, String> {
    fun findBySessionExerciseIdOrderByOrderIndexAsc(sessionExerciseId: String): List<SessionExercisePerson>
    fun findBySessionExerciseId(sessionExerciseId: String): List<SessionExercisePerson>
}

@Repository
interface SetEntryRepository : JpaRepository<SetEntry, String> {
    fun findBySessionId(sessionId: String): List<SetEntry>
}

@Repository
interface RestTimerRepository : JpaRepository<RestTimer, String> {
    fun findBySessionId(sessionId: String): List<RestTimer>
    fun findBySessionIdAndPersonId(sessionId: String, personId: String): RestTimer?
}
