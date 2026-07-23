package com.couples.recording.controller.dto

import jakarta.validation.constraints.NotBlank

// ---- people / settings ----
data class SavePartnerRequest(
    @field:NotBlank val name: String,
    @field:NotBlank val color: String,
    @field:NotBlank val unit: String,
    val initials: String? = null,
)

data class UpdatePersonRequest(
    val name: String? = null,
    val color: String? = null,
    val unit: String? = null,
    val initials: String? = null,
    val active: Boolean? = null,
)

data class UpdateSettingsRequest(
    val coupleModeEnabled: Boolean? = null,
    val defaultParticipants: String? = null,
    val defaultLoggingStyle: String? = null,
    val allowCopyPartnerValues: Boolean? = null,
    val showPartnerHistory: Boolean? = null,
)

// ---- exercises ----
data class ExerciseTracks(val weight: Boolean = true, val reps: Boolean = true, val duration: Boolean = false)

data class ProfileInput(val restSeconds: Int? = null, val machineSetup: String? = null, val cues: String? = null)

data class SaveExerciseRequest(
    val id: String? = null,
    @field:NotBlank val name: String,
    val category: String = "",
    val equipment: String = "",
    val tracks: ExerciseTracks = ExerciseTracks(),
    val defaultRestSeconds: Int = 90,
    val profiles: Map<String, ProfileInput> = emptyMap(),
)

// ---- templates ----
data class TemplateExerciseInput(
    @field:NotBlank val exerciseId: String,
    val assignment: String = "both",
    val order: Int = 0,
    val defaultLoggingMode: String? = null,
)

data class SaveTemplateRequest(
    val id: String? = null,
    @field:NotBlank val name: String,
    val defaultMode: String = "alternate",
    val exercises: List<TemplateExerciseInput> = emptyList(),
)

data class SetAssignmentRequest(@field:NotBlank val assignment: String)

// ---- session lifecycle ----
data class StartSessionRequest(
    @field:NotBlank val templateId: String,
    val participantIds: List<String>,
    val loggingStyle: String? = null,
)

data class LogValues(
    val weight: Double? = null,
    val reps: Int? = null,
    val duration: Int? = null,
    val note: String? = null,
)

data class LogSetRequest(
    @field:NotBlank val sessionExerciseId: String,
    @field:NotBlank val personId: String,
    val values: LogValues = LogValues(),
    val setType: String? = null,
    val source: String? = null,
)

// Map preserves "key present vs absent" so we can patch only supplied fields,
// matching the reducer's `values.x !== undefined` checks.
data class EditSetRequest(val values: Map<String, Any?> = emptyMap())

data class ReassignSetRequest(@field:NotBlank val toPersonId: String)

data class PersonStatusRequest(@field:NotBlank val personId: String, @field:NotBlank val status: String)

data class SkipTurnRequest(@field:NotBlank val personId: String)

data class SkipExerciseRequest(@field:NotBlank val personId: String, val reason: String? = null)

data class SubstituteRequest(@field:NotBlank val personId: String, val substituteExerciseId: String? = null)

data class AddSessionExerciseRequest(@field:NotBlank val exerciseId: String, val assignment: String = "both")

data class LoggingModeRequest(@field:NotBlank val mode: String)

data class ActiveRowRequest(@field:NotBlank val personId: String)
