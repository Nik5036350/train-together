package com.couples.recording.service

import com.couples.recording.controller.dto.LogValues
import com.couples.recording.domain.Person
import com.couples.recording.domain.RestTimer
import com.couples.recording.domain.SessionExercise
import com.couples.recording.domain.SessionExercisePerson
import com.couples.recording.domain.SetEntry
import com.couples.recording.domain.WorkoutSession
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

// Session lifecycle + in-session mutations. Ports the session branches of the
// client reducer verbatim (turn switching, rest timers, set renumbering, skips,
// substitutions). History-set edits reuse the same code, branching on status.
@Service
class SessionService(
    private val sessions: WorkoutSessionRepository,
    private val sessionExercises: SessionExerciseRepository,
    private val sessionExercisePeople: SessionExercisePersonRepository,
    private val sets: SetEntryRepository,
    private val timers: RestTimerRepository,
    private val people: PersonRepository,
    private val exercises: ExerciseRepository,
    private val profiles: PersonExerciseProfileRepository,
    private val templates: TemplateRepository,
    private val templateExercises: TemplateExerciseRepository,
) {
    // ---- shared helpers (ports of reducer selectors) ----

    private fun ownerOf(): Person? = people.findByIsOwnerTrue()
    private fun partnerOf(): Person? = people.findByIsOwnerFalseAndActiveTrue()

    private fun appliesTo(assignment: String, participantIds: List<String>): List<String> {
        val owner = ownerOf()
        val partner = partnerOf()
        val wanted = when (assignment) {
            "both" -> listOf(owner?.id, partner?.id)
            "owner" -> listOf(owner?.id)
            else -> listOf(partner?.id)
        }
        return wanted.filterNotNull().filter { participantIds.contains(it) }
    }

    // Personal profile rest overrides the exercise default (truthy check: 0 falls through).
    private fun restSecondsFor(personId: String, exerciseId: String): Int {
        val prof = profiles.findByPersonIdAndExerciseId(personId, exerciseId)
        val override = prof?.restSeconds
        if (override != null && override != 0) return override
        return exercises.findById(exerciseId).map { it.defaultRestSeconds }.orElse(90).let { if (it == 0) 90 else it }
    }

    private fun effectiveExerciseId(se: SessionExercise, personId: String): String {
        val sub = sessionExercisePeople.findBySessionExerciseId(se.id)
            .firstOrNull { it.personId == personId }?.substituteExerciseId
        return sub ?: se.exerciseId
    }

    private fun activeSession(sessionId: String): WorkoutSession =
        sessions.findById(sessionId).orElseThrow { NotFoundException("Session $sessionId not found") }

    private fun sessionExercise(id: String): SessionExercise =
        sessionExercises.findById(id).orElseThrow { NotFoundException("Session exercise $id not found") }

    // ---- lifecycle ----

    @Transactional
    fun startSession(templateId: String, participantIds: List<String>, loggingStyle: String?): String {
        val tpl = templates.findById(templateId).orElseThrow { NotFoundException("Template $templateId not found") }
        // Only one active session at a time — discard any existing one (matches the
        // reducer overwriting state.session).
        sessions.findFirstByStatus("active")?.let { deleteSessionGraph(it.id) }

        val style = loggingStyle ?: tpl.defaultMode
        val sessionId = Ids.uid("sess")
        sessions.save(
            WorkoutSession(
                id = sessionId,
                templateId = templateId,
                name = tpl.name,
                startTime = System.currentTimeMillis(),
                loggingStyle = style,
                status = "active",
                participantIds = participantIds.toMutableList(),
            ),
        )

        var order = 0
        templateExercises.findByTemplateIdOrderByOrderIndexAsc(templateId).forEach { te ->
            val ppl = appliesTo(te.assignment, participantIds)
            if (ppl.isEmpty()) return@forEach
            val se = sessionExercises.save(
                SessionExercise(
                    id = Ids.uid("se"),
                    sessionId = sessionId,
                    exerciseId = te.exerciseId,
                    loggingMode = te.defaultLoggingMode ?: style,
                    activePersonId = ppl.first(),
                    addedDuringSession = false,
                    orderIndex = order++,
                ),
            )
            ppl.forEachIndexed { i, pid ->
                sessionExercisePeople.save(SessionExercisePerson(Ids.uid("sep"), se.id, pid, "pending", null, null, i))
            }
        }
        return sessionId
    }

    @Transactional
    fun finishSession(sessionId: String) {
        val s = activeSession(sessionId)
        s.status = "finished"
        s.endTime = System.currentTimeMillis()
        sessions.save(s)
        // Rest timers are transient countdowns — meaningless in history.
        timers.deleteAllInBatch(timers.findBySessionId(sessionId))
    }

    private fun deleteSessionGraph(sessionId: String) {
        timers.deleteAllInBatch(timers.findBySessionId(sessionId))
        sets.deleteAllInBatch(sets.findBySessionId(sessionId))
        sessionExercises.findBySessionIdOrderByOrderIndexAsc(sessionId).forEach { se ->
            sessionExercisePeople.deleteAllInBatch(sessionExercisePeople.findBySessionExerciseId(se.id))
        }
        sessionExercises.deleteAllInBatch(sessionExercises.findBySessionIdOrderByOrderIndexAsc(sessionId))
        sessions.deleteById(sessionId)
    }

    // ---- logging ----

    @Transactional
    fun logSet(sessionId: String, sessionExerciseId: String, personId: String, values: LogValues, setType: String?) {
        activeSession(sessionId)
        val se = sessionExercise(sessionExerciseId)
        val exId = effectiveExerciseId(se, personId)
        val priorCount = sets.findBySessionId(sessionId)
            .count { it.sessionExerciseId == sessionExerciseId && it.personId == personId }

        sets.save(
            SetEntry(
                id = Ids.uid("set"),
                sessionId = sessionId,
                sessionExerciseId = sessionExerciseId,
                exerciseId = exId,
                personId = personId,
                setIndex = priorCount,
                weight = values.weight,
                reps = values.reps,
                duration = values.duration,
                setType = setType ?: "working",
                timestamp = System.currentTimeMillis(),
                note = values.note?.ifBlank { null },
            ),
        )

        // Switch active row for alternate / turns modes.
        val persons = sessionExercisePeople.findBySessionExerciseIdOrderByOrderIndexAsc(sessionExerciseId)
        val others = persons.map { it.personId }.filter { it != personId }
        val switchActive = se.loggingMode == "alternate" || se.loggingMode == "turns"
        se.activePersonId = if (switchActive && others.isNotEmpty()) others.first() else personId
        sessionExercises.save(se)

        persons.firstOrNull { it.personId == personId }?.let {
            it.status = "logged"
            sessionExercisePeople.save(it)
        }

        upsertTimer(sessionId, personId, sessionExerciseId, restSecondsFor(personId, exId))
    }

    private fun upsertTimer(sessionId: String, personId: String, sessionExerciseId: String, durationSeconds: Int) {
        val t = timers.findBySessionIdAndPersonId(sessionId, personId)
            ?: RestTimer(Ids.uid("tmr"), sessionId, personId, sessionExerciseId, 0, 0)
        t.sessionExerciseId = sessionExerciseId
        t.startedAt = System.currentTimeMillis()
        t.durationSeconds = durationSeconds
        timers.save(t)
    }

    @Transactional
    fun undoSet(sessionId: String, setId: String) {
        val removed = sets.findById(setId).orElseThrow { NotFoundException("Set $setId not found") }
        sets.deleteById(setId)
        // Restore the active row to whoever logged the undone set.
        removed.sessionExerciseId?.let { seId ->
            sessionExercises.findById(seId).ifPresent {
                it.activePersonId = removed.personId
                sessionExercises.save(it)
            }
        }
        // Drop the rest timer that the undone set started.
        timers.findBySessionIdAndPersonId(sessionId, removed.personId)?.let {
            if (it.sessionExerciseId == removed.sessionExerciseId) timers.deleteById(it.id)
        }
    }

    // ---- set editing (works for both active and finished sessions) ----

    @Transactional
    fun editSet(setId: String, values: Map<String, Any?>) {
        val s = sets.findById(setId).orElseThrow { NotFoundException("Set $setId not found") }
        if (values.containsKey("weight")) s.weight = (values["weight"] as? Number)?.toDouble()
        if (values.containsKey("reps")) s.reps = (values["reps"] as? Number)?.toInt()
        if (values.containsKey("duration")) s.duration = (values["duration"] as? Number)?.toInt()
        if (values.containsKey("note")) s.note = values["note"] as? String
        sets.save(s)
    }

    @Transactional
    fun deleteSet(sessionId: String, setId: String) {
        val session = activeSession(sessionId)
        val removed = sets.findById(setId).orElseThrow { NotFoundException("Set $setId not found") }
        sets.deleteById(setId)
        // Renumber remaining sets for the affected group so setIndex stays
        // contiguous. Active groups by sessionExerciseId; finished groups by
        // exerciseId (matches DELETE_SET vs DELETE_HISTORY_SET).
        val remaining = sets.findBySessionId(sessionId)
        val group = if (session.status == "finished") {
            remaining.filter { it.exerciseId == removed.exerciseId && it.personId == removed.personId }
        } else {
            remaining.filter { it.sessionExerciseId == removed.sessionExerciseId && it.personId == removed.personId }
        }
        group.sortedWith(compareBy({ it.timestamp ?: 0L }, { it.setIndex }))
            .forEachIndexed { i, s -> if (s.setIndex != i) { s.setIndex = i; sets.save(s) } }
    }

    @Transactional
    fun reassignSet(setId: String, toPersonId: String) {
        val s = sets.findById(setId).orElseThrow { NotFoundException("Set $setId not found") }
        s.personId = toPersonId
        sets.save(s)
    }

    // ---- per-person status / skips / substitution ----

    @Transactional
    fun setPersonStatus(sessionExerciseId: String, personId: String, status: String) {
        val sep = personRow(sessionExerciseId, personId)
        sep.status = status
        sessionExercisePeople.save(sep)
    }

    @Transactional
    fun skipTurn(sessionExerciseId: String, personId: String) {
        val se = sessionExercise(sessionExerciseId)
        val persons = sessionExercisePeople.findBySessionExerciseIdOrderByOrderIndexAsc(sessionExerciseId)
        val others = persons.filter { it.personId != personId && it.status != "skipped" }.map { it.personId }
        se.activePersonId = others.firstOrNull() ?: se.activePersonId
        sessionExercises.save(se)
    }

    @Transactional
    fun skipExercise(sessionExerciseId: String, personId: String, reason: String?) {
        val se = sessionExercise(sessionExerciseId)
        val persons = sessionExercisePeople.findBySessionExerciseIdOrderByOrderIndexAsc(sessionExerciseId)
        val others = persons.filter { it.personId != personId }.map { it.personId }
        se.activePersonId = others.firstOrNull() ?: se.activePersonId
        sessionExercises.save(se)
        val sep = persons.first { it.personId == personId }
        sep.status = "skipped"
        sep.skipReason = reason
        sessionExercisePeople.save(sep)
    }

    @Transactional
    fun substituteExercise(sessionExerciseId: String, personId: String, substituteExerciseId: String?) {
        val sep = personRow(sessionExerciseId, personId)
        sep.substituteExerciseId = substituteExerciseId
        sessionExercisePeople.save(sep)
    }

    @Transactional
    fun addSessionExercise(sessionId: String, exerciseId: String, assignment: String) {
        val session = activeSession(sessionId)
        val ppl = appliesTo(assignment, session.participantIds)
        if (ppl.isEmpty()) return
        val nextOrder = (sessionExercises.findBySessionIdOrderByOrderIndexAsc(sessionId)
            .maxOfOrNull { it.orderIndex } ?: -1) + 1
        val se = sessionExercises.save(
            SessionExercise(
                id = Ids.uid("se"),
                sessionId = sessionId,
                exerciseId = exerciseId,
                loggingMode = session.loggingStyle,
                activePersonId = ppl.first(),
                addedDuringSession = true,
                orderIndex = nextOrder,
            ),
        )
        ppl.forEachIndexed { i, pid ->
            sessionExercisePeople.save(SessionExercisePerson(Ids.uid("sep"), se.id, pid, "pending", null, null, i))
        }
    }

    @Transactional
    fun setLoggingMode(sessionExerciseId: String, mode: String) {
        val se = sessionExercise(sessionExerciseId)
        se.loggingMode = mode
        sessionExercises.save(se)
    }

    @Transactional
    fun setActiveRow(sessionExerciseId: String, personId: String) {
        val se = sessionExercise(sessionExerciseId)
        se.activePersonId = personId
        sessionExercises.save(se)
    }

    private fun personRow(sessionExerciseId: String, personId: String): SessionExercisePerson =
        sessionExercisePeople.findBySessionExerciseId(sessionExerciseId).firstOrNull { it.personId == personId }
            ?: throw NotFoundException("Person $personId not in session exercise $sessionExerciseId")
}
