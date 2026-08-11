use crate::entities::*;
use sea_orm::{ColumnTrait, DatabaseConnection, DbErr, EntityTrait, QueryFilter, QueryOrder};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

// Response structs mirror the client's JSON state tree exactly (camelCase keys,
// nullable fields serialized as null). They double as the import (PUT /state)
// body, so they derive Deserialize too.

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StateResponse {
    pub version: i32,
    pub onboarded: bool,
    pub people: Vec<PersonResp>,
    pub settings: SettingsResp,
    pub exercises: BTreeMap<String, ExerciseResp>,
    pub person_exercise_profiles: BTreeMap<String, ProfileResp>,
    pub templates: BTreeMap<String, TemplateResp>,
    pub history: Vec<SessionResp>,
    pub session: Option<SessionResp>,
    #[serde(default)]
    pub last_summary: Option<SessionResp>,
    #[serde(default)]
    pub snackbar: Option<serde_json::Value>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PersonResp {
    pub id: String,
    pub name: String,
    pub initials: String,
    pub color: String,
    pub unit: String,
    pub is_owner: bool,
    pub active: bool,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettingsResp {
    pub couple_mode_enabled: bool,
    pub default_participants: String,
    pub default_logging_style: String,
    pub allow_copy_partner_values: bool,
    pub show_partner_history: bool,
}

#[derive(Serialize, Deserialize)]
pub struct TracksResp {
    pub weight: bool,
    pub reps: bool,
    pub duration: bool,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExerciseResp {
    pub id: String,
    pub name: String,
    pub category: String,
    #[serde(default)] // older backups (user-created exercises) omitted this
    pub equipment: String,
    pub tracks: TracksResp,
    pub default_rest_seconds: i32,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProfileResp {
    pub rest_seconds: Option<i32>,
    pub machine_setup: String,
    pub cues: String,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TemplateExerciseResp {
    pub exercise_id: String,
    pub assignment: String,
    pub order: i32,
    pub default_logging_mode: Option<String>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TemplateResp {
    pub id: String,
    pub name: String,
    pub default_mode: String,
    pub exercises: Vec<TemplateExerciseResp>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PerPersonResp {
    pub status: String,
    pub skip_reason: Option<String>,
    pub substitute_exercise_id: Option<String>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionExerciseResp {
    pub id: String,
    pub exercise_id: String,
    pub applies_to: Vec<String>,
    pub logging_mode: String,
    #[serde(default = "default_variant")] // older backups omitted this
    pub variant: String,
    pub active_person_id: Option<String>,
    #[serde(default)] // older backups omitted this
    pub added_during_session: Option<bool>,
    pub per_person: BTreeMap<String, PerPersonResp>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SetResp {
    pub id: String,
    pub session_exercise_id: Option<String>,
    pub exercise_id: String,
    pub person_id: String,
    pub set_index: i32,
    pub weight: Option<f64>,
    pub reps: Option<i32>,
    pub duration: Option<i32>,
    pub set_type: String,
    #[serde(default = "default_variant")] // older backups omitted this
    pub variant: String,
    pub timestamp: Option<i64>,
    pub note: Option<String>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TimerResp {
    pub session_exercise_id: String,
    pub started_at: i64,
    pub duration_seconds: i32,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionResp {
    pub id: String,
    #[serde(default)]
    pub template_id: Option<String>,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub start_time: i64,
    #[serde(default)]
    pub end_time: Option<i64>,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub participant_ids: Vec<String>,
    // Older/minimal backup sessions may omit these; default sensibly so import
    // stays tolerant. A history entry with no status is treated as finished.
    #[serde(default = "default_logging_style")]
    pub logging_style: String,
    #[serde(default = "default_finished")]
    pub status: String,
    #[serde(default)]
    pub exercises: Vec<SessionExerciseResp>,
    #[serde(default)]
    pub sets: Vec<SetResp>,
    #[serde(default)]
    pub timers: BTreeMap<String, TimerResp>,
}

fn default_logging_style() -> String {
    "alternate".to_string()
}

fn default_finished() -> String {
    "finished".to_string()
}

fn default_variant() -> String {
    "normal".to_string()
}

// Reassemble the normalized tables into the single aggregate tree.
pub async fn build_state(db: &DatabaseConnection) -> Result<StateResponse, DbErr> {
    let settings = app_settings::Entity::find_by_id(app_settings::SINGLETON_ID)
        .one(db)
        .await?;

    let exercises = exercise::Entity::find()
        .all(db)
        .await?
        .into_iter()
        .map(|e| {
            (
                e.id.clone(),
                ExerciseResp {
                    id: e.id,
                    name: e.name,
                    category: e.category,
                    equipment: e.equipment,
                    tracks: TracksResp {
                        weight: e.tracks_weight,
                        reps: e.tracks_reps,
                        duration: e.tracks_duration,
                    },
                    default_rest_seconds: e.default_rest_seconds,
                },
            )
        })
        .collect::<BTreeMap<_, _>>();

    let person_exercise_profiles = person_exercise_profile::Entity::find()
        .all(db)
        .await?
        .into_iter()
        .map(|p| {
            (
                format!("{}__{}", p.person_id, p.exercise_id),
                ProfileResp {
                    rest_seconds: p.rest_seconds,
                    machine_setup: p.machine_setup,
                    cues: p.cues,
                },
            )
        })
        .collect::<BTreeMap<_, _>>();

    let mut templates = BTreeMap::new();
    for tpl in template::Entity::find().all(db).await? {
        let exs = template_exercise::Entity::find()
            .filter(template_exercise::Column::TemplateId.eq(&tpl.id))
            .order_by_asc(template_exercise::Column::OrderIndex)
            .all(db)
            .await?
            .into_iter()
            .map(|te| TemplateExerciseResp {
                exercise_id: te.exercise_id,
                assignment: te.assignment,
                order: te.order_index,
                default_logging_mode: te.default_logging_mode,
            })
            .collect();
        templates.insert(
            tpl.id.clone(),
            TemplateResp {
                id: tpl.id,
                name: tpl.name,
                default_mode: tpl.default_mode,
                exercises: exs,
            },
        );
    }

    let people = person::Entity::find()
        .all(db)
        .await?
        .into_iter()
        .map(|p| PersonResp {
            id: p.id,
            name: p.name,
            initials: p.initials,
            color: p.color,
            unit: p.unit,
            is_owner: p.is_owner,
            active: p.active,
        })
        .collect();

    let mut history = Vec::new();
    for s in workout_session::Entity::find()
        .filter(workout_session::Column::Status.eq("finished"))
        .order_by_desc(workout_session::Column::StartTime)
        .all(db)
        .await?
    {
        history.push(build_session(db, s).await?);
    }

    let session = match workout_session::Entity::find()
        .filter(workout_session::Column::Status.eq("active"))
        .one(db)
        .await?
    {
        Some(s) => Some(build_session(db, s).await?),
        None => None,
    };

    Ok(StateResponse {
        version: settings.as_ref().map(|s| s.version).unwrap_or(3),
        onboarded: settings.as_ref().map(|s| s.onboarded).unwrap_or(true),
        people,
        settings: settings
            .map(|s| SettingsResp {
                couple_mode_enabled: s.couple_mode_enabled,
                default_participants: s.default_participants,
                default_logging_style: s.default_logging_style,
                allow_copy_partner_values: s.allow_copy_partner_values,
                show_partner_history: s.show_partner_history,
            })
            .unwrap_or(SettingsResp {
                couple_mode_enabled: true,
                default_participants: "both".into(),
                default_logging_style: "alternate".into(),
                allow_copy_partner_values: true,
                show_partner_history: true,
            }),
        exercises,
        person_exercise_profiles,
        templates,
        history,
        session,
        last_summary: None,
        snackbar: None,
    })
}

async fn build_session(
    db: &DatabaseConnection,
    s: workout_session::Model,
) -> Result<SessionResp, DbErr> {
    let mut exercises = Vec::new();
    for se in session_exercise::Entity::find()
        .filter(session_exercise::Column::SessionId.eq(&s.id))
        .order_by_asc(session_exercise::Column::OrderIndex)
        .all(db)
        .await?
    {
        let persons = session_exercise_person::Entity::find()
            .filter(session_exercise_person::Column::SessionExerciseId.eq(&se.id))
            .order_by_asc(session_exercise_person::Column::OrderIndex)
            .all(db)
            .await?;
        let applies_to = persons.iter().map(|p| p.person_id.clone()).collect();
        let per_person = persons
            .into_iter()
            .map(|p| {
                (
                    p.person_id,
                    PerPersonResp {
                        status: p.status,
                        skip_reason: p.skip_reason,
                        substitute_exercise_id: p.substitute_exercise_id,
                    },
                )
            })
            .collect();
        exercises.push(SessionExerciseResp {
            id: se.id,
            exercise_id: se.exercise_id,
            applies_to,
            logging_mode: se.logging_mode,
            variant: se.variant,
            active_person_id: se.active_person_id,
            added_during_session: if se.added_during_session {
                Some(true)
            } else {
                None
            },
            per_person,
        });
    }

    let mut sets: Vec<set_entry::Model> = set_entry::Entity::find()
        .filter(set_entry::Column::SessionId.eq(&s.id))
        .all(db)
        .await?;
    sets.sort_by(|a, b| {
        a.timestamp
            .unwrap_or(0)
            .cmp(&b.timestamp.unwrap_or(0))
            .then(a.set_index.cmp(&b.set_index))
    });
    let sets = sets
        .into_iter()
        .map(|st| SetResp {
            id: st.id,
            session_exercise_id: st.session_exercise_id,
            exercise_id: st.exercise_id,
            person_id: st.person_id,
            set_index: st.set_index,
            weight: st.weight,
            reps: st.reps,
            duration: st.duration,
            set_type: st.set_type,
            variant: st.variant,
            timestamp: st.timestamp,
            note: st.note,
        })
        .collect();

    let timers = rest_timer::Entity::find()
        .filter(rest_timer::Column::SessionId.eq(&s.id))
        .all(db)
        .await?
        .into_iter()
        .map(|t| {
            (
                t.person_id,
                TimerResp {
                    session_exercise_id: t.session_exercise_id,
                    started_at: t.started_at,
                    duration_seconds: t.duration_seconds,
                },
            )
        })
        .collect();

    let participant_ids = session_participant::Entity::find()
        .filter(session_participant::Column::SessionId.eq(&s.id))
        .order_by_asc(session_participant::Column::OrderIndex)
        .all(db)
        .await?
        .into_iter()
        .map(|p| p.person_id)
        .collect();

    Ok(SessionResp {
        id: s.id,
        template_id: s.template_id,
        name: s.name,
        start_time: s.start_time,
        end_time: s.end_time,
        label: s.label,
        participant_ids,
        logging_style: s.logging_style,
        status: s.status,
        exercises,
        sets,
        timers,
    })
}
