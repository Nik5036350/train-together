package com.couples.recording.controller.dto

// Response shapes that mirror the client's JSON state tree exactly (see the old
// makeInitialState() in the frontend). Every mutation endpoint returns a
// StateResponse so the client can replace its cache wholesale.

data class StateResponse(
    val version: Int,
    val onboarded: Boolean,
    val people: List<PersonDto>,
    val settings: SettingsDto,
    val exercises: Map<String, ExerciseDto>,
    val personExerciseProfiles: Map<String, ProfileDto>,
    val templates: Map<String, TemplateDto>,
    val history: List<SessionDto>,
    val session: SessionDto?,
    val lastSummary: SessionDto? = null,
    val snackbar: Any? = null,
)

data class PersonDto(
    val id: String,
    val name: String,
    val initials: String,
    val color: String,
    val unit: String,
    val isOwner: Boolean,
    val active: Boolean,
)

data class SettingsDto(
    val coupleModeEnabled: Boolean,
    val defaultParticipants: String,
    val defaultLoggingStyle: String,
    val allowCopyPartnerValues: Boolean,
    val showPartnerHistory: Boolean,
)

data class TracksDto(
    val weight: Boolean,
    val reps: Boolean,
    val duration: Boolean,
)

data class ExerciseDto(
    val id: String,
    val name: String,
    val category: String,
    val equipment: String,
    val tracks: TracksDto,
    val defaultRestSeconds: Int,
)

data class ProfileDto(
    val restSeconds: Int?,
    val machineSetup: String,
    val cues: String,
)

data class TemplateExerciseDto(
    val exerciseId: String,
    val assignment: String,
    val order: Int,
    val defaultLoggingMode: String? = null,
)

data class TemplateDto(
    val id: String,
    val name: String,
    val defaultMode: String,
    val exercises: List<TemplateExerciseDto>,
)

data class PerPersonDto(
    val status: String,
    val skipReason: String?,
    val substituteExerciseId: String?,
)

data class SessionExerciseDto(
    val id: String,
    val exerciseId: String,
    val appliesTo: List<String>,
    val loggingMode: String,
    val activePersonId: String?,
    val addedDuringSession: Boolean?,
    val perPerson: Map<String, PerPersonDto>,
)

data class SetDto(
    val id: String,
    val sessionExerciseId: String?,
    val exerciseId: String,
    val personId: String,
    val setIndex: Int,
    val weight: Double?,
    val reps: Int?,
    val duration: Int?,
    val setType: String,
    val timestamp: Long?,
    val note: String?,
)

data class TimerDto(
    val sessionExerciseId: String,
    val startedAt: Long,
    val durationSeconds: Int,
)

data class SessionDto(
    val id: String,
    val templateId: String?,
    val name: String,
    val startTime: Long,
    val endTime: Long?,
    val label: String?,
    val participantIds: List<String>,
    val loggingStyle: String,
    val status: String,
    val exercises: List<SessionExerciseDto>,
    val sets: List<SetDto>,
    val timers: Map<String, TimerDto>,
)
