package com.couples.recording.domain

import jakarta.persistence.CollectionTable
import jakarta.persistence.Column
import jakarta.persistence.ElementCollection
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.Table

// The relational schema mirrors the client's single JSON state tree. Rows use
// the same string ids the client used (prefixes p_/ex_/t_/sess_/se_/set_), so
// the reassembled aggregate JSON is byte-for-byte compatible with the old
// localStorage shape. Relationships are kept as plain id strings (no JPA
// associations) to keep the document-style model simple and SQLite-friendly.

@Entity
@Table(name = "person")
class Person(
    @Id var id: String = "",
    var name: String = "",
    var initials: String = "",
    var color: String = "",
    var unit: String = "kg",
    var isOwner: Boolean = false,
    var active: Boolean = true,
)

@Entity
@Table(name = "exercise")
class Exercise(
    @Id var id: String = "",
    var name: String = "",
    var category: String = "",
    var equipment: String = "",
    var tracksWeight: Boolean = true,
    var tracksReps: Boolean = true,
    var tracksDuration: Boolean = false,
    var defaultRestSeconds: Int = 90,
)

@Entity
@Table(name = "person_exercise_profile")
class PersonExerciseProfile(
    @Id var id: String = "",
    var personId: String = "",
    var exerciseId: String = "",
    var restSeconds: Int? = null,
    var machineSetup: String = "",
    var cues: String = "",
)

@Entity
@Table(name = "template")
class Template(
    @Id var id: String = "",
    var name: String = "",
    var defaultMode: String = "alternate",
)

@Entity
@Table(name = "template_exercise")
class TemplateExercise(
    @Id var id: String = "",
    var templateId: String = "",
    var exerciseId: String = "",
    var assignment: String = "both",
    var orderIndex: Int = 0,
    var defaultLoggingMode: String? = null,
)

@Entity
@Table(name = "app_settings")
class AppSettings(
    @Id var id: String = SINGLETON_ID,
    var coupleModeEnabled: Boolean = true,
    var defaultParticipants: String = "both",
    var defaultLoggingStyle: String = "alternate",
    var allowCopyPartnerValues: Boolean = true,
    var showPartnerHistory: Boolean = true,
    var onboarded: Boolean = true,
    var version: Int = 3,
) {
    companion object {
        const val SINGLETON_ID = "app"
    }
}

@Entity
@Table(name = "workout_session")
class WorkoutSession(
    @Id var id: String = "",
    var templateId: String? = null,
    var name: String = "",
    var startTime: Long = 0,
    var endTime: Long? = null,
    var label: String? = null,
    var loggingStyle: String = "alternate",
    var status: String = "active",
    @ElementCollection
    @CollectionTable(name = "session_participant", joinColumns = [JoinColumn(name = "session_id")])
    @Column(name = "person_id")
    var participantIds: MutableList<String> = mutableListOf(),
)

@Entity
@Table(name = "session_exercise")
class SessionExercise(
    @Id var id: String = "",
    var sessionId: String = "",
    var exerciseId: String = "",
    var loggingMode: String = "alternate",
    var activePersonId: String? = null,
    var addedDuringSession: Boolean = false,
    var orderIndex: Int = 0,
)

@Entity
@Table(name = "session_exercise_person")
class SessionExercisePerson(
    @Id var id: String = "",
    var sessionExerciseId: String = "",
    var personId: String = "",
    var status: String = "pending",
    var skipReason: String? = null,
    var substituteExerciseId: String? = null,
    var orderIndex: Int = 0,
)

@Entity
@Table(name = "set_entry")
class SetEntry(
    @Id var id: String = "",
    var sessionId: String = "",
    var sessionExerciseId: String? = null,
    var exerciseId: String = "",
    var personId: String = "",
    var setIndex: Int = 0,
    var weight: Double? = null,
    var reps: Int? = null,
    var duration: Int? = null,
    var setType: String = "working",
    var timestamp: Long? = null,
    var note: String? = null,
)

@Entity
@Table(name = "rest_timer")
class RestTimer(
    @Id var id: String = "",
    var sessionId: String = "",
    var personId: String = "",
    var sessionExerciseId: String = "",
    var startedAt: Long = 0,
    var durationSeconds: Int = 0,
)
