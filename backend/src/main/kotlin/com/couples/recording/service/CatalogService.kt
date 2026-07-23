package com.couples.recording.service

import com.couples.recording.controller.dto.ExerciseTracks
import com.couples.recording.controller.dto.ProfileInput
import com.couples.recording.controller.dto.TemplateExerciseInput
import com.couples.recording.domain.AppSettings
import com.couples.recording.domain.Exercise
import com.couples.recording.domain.Person
import com.couples.recording.domain.PersonExerciseProfile
import com.couples.recording.domain.Template
import com.couples.recording.domain.TemplateExercise
import com.couples.recording.repository.AppSettingsRepository
import com.couples.recording.repository.ExerciseRepository
import com.couples.recording.repository.PersonExerciseProfileRepository
import com.couples.recording.repository.PersonRepository
import com.couples.recording.repository.TemplateExerciseRepository
import com.couples.recording.repository.TemplateRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

// People, settings, exercise library and templates — ports the onboarding /
// settings / exercise / template branches of the client reducer.
@Service
class CatalogService(
    private val people: PersonRepository,
    private val settings: AppSettingsRepository,
    private val exercises: ExerciseRepository,
    private val profiles: PersonExerciseProfileRepository,
    private val templates: TemplateRepository,
    private val templateExercises: TemplateExerciseRepository,
) {
    private fun settingsRow(): AppSettings =
        settings.findById(AppSettings.SINGLETON_ID).orElseGet { settings.save(AppSettings()) }

    // ---- onboarding / settings ----

    @Transactional
    fun savePartner(name: String, color: String, unit: String, initials: String?) {
        val partner = people.findByIsOwnerFalseAndActiveTrue()
        val computedInitials = initials?.ifBlank { null } ?: name.take(1)
        if (partner != null) {
            partner.name = name
            partner.color = color
            partner.unit = unit
            partner.initials = computedInitials
            people.save(partner)
        } else {
            people.save(
                Person(Ids.uid("p"), name, computedInitials, color, unit, isOwner = false, active = true),
            )
        }
        val s = settingsRow()
        s.onboarded = true
        s.coupleModeEnabled = true
        settings.save(s)
    }

    @Transactional
    fun updatePerson(
        personId: String,
        name: String?,
        color: String?,
        unit: String?,
        initials: String?,
        active: Boolean?,
    ) {
        val p = people.findById(personId).orElseThrow { NotFoundException("Person $personId not found") }
        name?.let { p.name = it }
        color?.let { p.color = it }
        unit?.let { p.unit = it }
        initials?.let { p.initials = it }
        active?.let { p.active = it }
        people.save(p)
    }

    @Transactional
    fun updateSettings(
        coupleModeEnabled: Boolean?,
        defaultParticipants: String?,
        defaultLoggingStyle: String?,
        allowCopyPartnerValues: Boolean?,
        showPartnerHistory: Boolean?,
    ) {
        val s = settingsRow()
        coupleModeEnabled?.let { s.coupleModeEnabled = it }
        defaultParticipants?.let { s.defaultParticipants = it }
        defaultLoggingStyle?.let { s.defaultLoggingStyle = it }
        allowCopyPartnerValues?.let { s.allowCopyPartnerValues = it }
        showPartnerHistory?.let { s.showPartnerHistory = it }
        settings.save(s)
    }

    @Transactional
    fun toggleCoupleMode() {
        val s = settingsRow()
        s.coupleModeEnabled = !s.coupleModeEnabled
        settings.save(s)
    }

    // ---- exercise library ----

    @Transactional
    fun saveExercise(
        id: String?,
        name: String,
        category: String,
        equipment: String,
        tracks: ExerciseTracks,
        defaultRestSeconds: Int,
        profileInputs: Map<String, ProfileInput>,
    ): String {
        val eid = id ?: Ids.uid("ex")
        exercises.save(
            Exercise(eid, name, category, equipment, tracks.weight, tracks.reps, tracks.duration, defaultRestSeconds),
        )
        profileInputs.forEach { (personId, input) ->
            val row = profiles.findByPersonIdAndExerciseId(personId, eid)
                ?: PersonExerciseProfile(Ids.uid("prof"), personId, eid)
            row.restSeconds = input.restSeconds
            row.machineSetup = input.machineSetup ?: ""
            row.cues = input.cues ?: ""
            profiles.save(row)
        }
        return eid
    }

    @Transactional
    fun deleteExercise(exerciseId: String) {
        exercises.deleteById(exerciseId)
        // Strip it from every routine that referenced it.
        templateExercises.deleteAllInBatch(templateExercises.findByExerciseId(exerciseId))
        // Drop its per-person profiles. History set rows keep their raw exerciseId.
        profiles.deleteAllInBatch(profiles.findByExerciseId(exerciseId))
    }

    // ---- templates ----

    @Transactional
    fun saveTemplate(id: String?, name: String, defaultMode: String, exercises: List<TemplateExerciseInput>): String {
        val tid = id ?: Ids.uid("t")
        templates.save(Template(tid, name, defaultMode))
        templateExercises.deleteByTemplateId(tid)
        templateExercises.saveAll(
            exercises.map {
                TemplateExercise(Ids.uid("tex"), tid, it.exerciseId, it.assignment, it.order, it.defaultLoggingMode)
            },
        )
        return tid
    }

    @Transactional
    fun deleteTemplate(templateId: String) {
        templateExercises.deleteByTemplateId(templateId)
        templates.deleteById(templateId)
    }

    @Transactional
    fun setAssignment(templateId: String, exerciseId: String, assignment: String) {
        val row = templateExercises.findByTemplateIdOrderByOrderIndexAsc(templateId)
            .firstOrNull { it.exerciseId == exerciseId }
            ?: throw NotFoundException("Exercise $exerciseId not in template $templateId")
        row.assignment = assignment
        templateExercises.save(row)
    }
}
