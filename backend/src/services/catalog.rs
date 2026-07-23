use crate::entities::*;
use crate::error::{AppError, AppResult};
use crate::ids::uid;
use sea_orm::ActiveValue::Set;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, DatabaseConnection, DbErr, EntityTrait, IntoActiveModel,
    QueryFilter, QueryOrder,
};

// People, settings, exercise library and templates — ports the onboarding /
// settings / exercise / template branches of the client reducer.

async fn settings_row(db: &DatabaseConnection) -> Result<app_settings::Model, DbErr> {
    if let Some(s) = app_settings::Entity::find_by_id(app_settings::SINGLETON_ID)
        .one(db)
        .await?
    {
        return Ok(s);
    }
    app_settings::ActiveModel {
        id: Set(app_settings::SINGLETON_ID.into()),
        couple_mode_enabled: Set(true),
        default_participants: Set("both".into()),
        default_logging_style: Set("alternate".into()),
        allow_copy_partner_values: Set(true),
        show_partner_history: Set(true),
        onboarded: Set(true),
        version: Set(3),
    }
    .insert(db)
    .await
}

// ---- onboarding / settings ----

pub async fn save_partner(
    db: &DatabaseConnection,
    name: String,
    color: String,
    unit: String,
    initials: Option<String>,
) -> AppResult<()> {
    let computed = initials
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| {
            name.chars()
                .next()
                .map(|c| c.to_string())
                .unwrap_or_default()
        });

    let partner = person::Entity::find()
        .filter(person::Column::IsOwner.eq(false))
        .filter(person::Column::Active.eq(true))
        .one(db)
        .await?;
    match partner {
        Some(p) => {
            let mut am = p.into_active_model();
            am.name = Set(name);
            am.color = Set(color);
            am.unit = Set(unit);
            am.initials = Set(computed);
            am.update(db).await?;
        }
        None => {
            person::ActiveModel {
                id: Set(uid("p")),
                name: Set(name),
                initials: Set(computed),
                color: Set(color),
                unit: Set(unit),
                is_owner: Set(false),
                active: Set(true),
            }
            .insert(db)
            .await?;
        }
    }
    let mut s = settings_row(db).await?.into_active_model();
    s.onboarded = Set(true);
    s.couple_mode_enabled = Set(true);
    s.update(db).await?;
    Ok(())
}

#[allow(clippy::too_many_arguments)]
pub async fn update_person(
    db: &DatabaseConnection,
    id: &str,
    name: Option<String>,
    color: Option<String>,
    unit: Option<String>,
    initials: Option<String>,
    active: Option<bool>,
) -> AppResult<()> {
    let p = person::Entity::find_by_id(id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Person {id} not found")))?;
    let mut am = p.into_active_model();
    if let Some(v) = name {
        am.name = Set(v);
    }
    if let Some(v) = color {
        am.color = Set(v);
    }
    if let Some(v) = unit {
        am.unit = Set(v);
    }
    if let Some(v) = initials {
        am.initials = Set(v);
    }
    if let Some(v) = active {
        am.active = Set(v);
    }
    am.update(db).await?;
    Ok(())
}

pub async fn update_settings(
    db: &DatabaseConnection,
    couple_mode_enabled: Option<bool>,
    default_participants: Option<String>,
    default_logging_style: Option<String>,
    allow_copy_partner_values: Option<bool>,
    show_partner_history: Option<bool>,
) -> AppResult<()> {
    let mut am = settings_row(db).await?.into_active_model();
    if let Some(v) = couple_mode_enabled {
        am.couple_mode_enabled = Set(v);
    }
    if let Some(v) = default_participants {
        am.default_participants = Set(v);
    }
    if let Some(v) = default_logging_style {
        am.default_logging_style = Set(v);
    }
    if let Some(v) = allow_copy_partner_values {
        am.allow_copy_partner_values = Set(v);
    }
    if let Some(v) = show_partner_history {
        am.show_partner_history = Set(v);
    }
    am.update(db).await?;
    Ok(())
}

pub async fn toggle_couple_mode(db: &DatabaseConnection) -> AppResult<()> {
    let s = settings_row(db).await?;
    let flipped = !s.couple_mode_enabled;
    let mut am = s.into_active_model();
    am.couple_mode_enabled = Set(flipped);
    am.update(db).await?;
    Ok(())
}

// ---- exercise library ----

#[allow(clippy::too_many_arguments)]
pub async fn save_exercise(
    db: &DatabaseConnection,
    id: Option<String>,
    name: String,
    category: String,
    equipment: String,
    tracks: (bool, bool, bool),
    default_rest_seconds: i32,
    profiles: Vec<(String, Option<i32>, String, String)>,
) -> AppResult<()> {
    let eid = id.unwrap_or_else(|| uid("ex"));
    let existing = exercise::Entity::find_by_id(&eid).one(db).await?;
    match existing {
        Some(e) => {
            let mut am = e.into_active_model();
            am.name = Set(name);
            am.category = Set(category);
            am.equipment = Set(equipment);
            am.tracks_weight = Set(tracks.0);
            am.tracks_reps = Set(tracks.1);
            am.tracks_duration = Set(tracks.2);
            am.default_rest_seconds = Set(default_rest_seconds);
            am.update(db).await?;
        }
        None => {
            exercise::ActiveModel {
                id: Set(eid.clone()),
                name: Set(name),
                category: Set(category),
                equipment: Set(equipment),
                tracks_weight: Set(tracks.0),
                tracks_reps: Set(tracks.1),
                tracks_duration: Set(tracks.2),
                default_rest_seconds: Set(default_rest_seconds),
            }
            .insert(db)
            .await?;
        }
    }

    for (person_id, rest_seconds, machine_setup, cues) in profiles {
        let found = person_exercise_profile::Entity::find()
            .filter(person_exercise_profile::Column::PersonId.eq(&person_id))
            .filter(person_exercise_profile::Column::ExerciseId.eq(&eid))
            .one(db)
            .await?;
        match found {
            Some(p) => {
                let mut am = p.into_active_model();
                am.rest_seconds = Set(rest_seconds);
                am.machine_setup = Set(machine_setup);
                am.cues = Set(cues);
                am.update(db).await?;
            }
            None => {
                person_exercise_profile::ActiveModel {
                    id: Set(uid("prof")),
                    person_id: Set(person_id),
                    exercise_id: Set(eid.clone()),
                    rest_seconds: Set(rest_seconds),
                    machine_setup: Set(machine_setup),
                    cues: Set(cues),
                }
                .insert(db)
                .await?;
            }
        }
    }
    Ok(())
}

pub async fn delete_exercise(db: &DatabaseConnection, exercise_id: &str) -> AppResult<()> {
    exercise::Entity::delete_by_id(exercise_id).exec(db).await?;
    // Strip it from every routine; drop its per-person profiles. History set rows
    // keep their raw exercise_id.
    template_exercise::Entity::delete_many()
        .filter(template_exercise::Column::ExerciseId.eq(exercise_id))
        .exec(db)
        .await?;
    person_exercise_profile::Entity::delete_many()
        .filter(person_exercise_profile::Column::ExerciseId.eq(exercise_id))
        .exec(db)
        .await?;
    Ok(())
}

// ---- templates ----

pub async fn save_template(
    db: &DatabaseConnection,
    id: Option<String>,
    name: String,
    default_mode: String,
    exercises: Vec<(String, String, i32, Option<String>)>, // exerciseId, assignment, order, defaultLoggingMode
) -> AppResult<()> {
    let tid = id.unwrap_or_else(|| uid("t"));
    match template::Entity::find_by_id(&tid).one(db).await? {
        Some(t) => {
            let mut am = t.into_active_model();
            am.name = Set(name);
            am.default_mode = Set(default_mode);
            am.update(db).await?;
        }
        None => {
            template::ActiveModel {
                id: Set(tid.clone()),
                name: Set(name),
                default_mode: Set(default_mode),
            }
            .insert(db)
            .await?;
        }
    }
    template_exercise::Entity::delete_many()
        .filter(template_exercise::Column::TemplateId.eq(&tid))
        .exec(db)
        .await?;
    for (exercise_id, assignment, order, default_logging_mode) in exercises {
        template_exercise::ActiveModel {
            id: Set(uid("tex")),
            template_id: Set(tid.clone()),
            exercise_id: Set(exercise_id),
            assignment: Set(assignment),
            order_index: Set(order),
            default_logging_mode: Set(default_logging_mode),
        }
        .insert(db)
        .await?;
    }
    Ok(())
}

pub async fn delete_template(db: &DatabaseConnection, template_id: &str) -> AppResult<()> {
    template_exercise::Entity::delete_many()
        .filter(template_exercise::Column::TemplateId.eq(template_id))
        .exec(db)
        .await?;
    template::Entity::delete_by_id(template_id).exec(db).await?;
    Ok(())
}

pub async fn set_assignment(
    db: &DatabaseConnection,
    template_id: &str,
    exercise_id: &str,
    assignment: &str,
) -> AppResult<()> {
    let row = template_exercise::Entity::find()
        .filter(template_exercise::Column::TemplateId.eq(template_id))
        .filter(template_exercise::Column::ExerciseId.eq(exercise_id))
        .order_by_asc(template_exercise::Column::OrderIndex)
        .one(db)
        .await?
        .ok_or_else(|| {
            AppError::NotFound(format!(
                "Exercise {exercise_id} not in template {template_id}"
            ))
        })?;
    let mut am = row.into_active_model();
    am.assignment = Set(assignment.into());
    am.update(db).await?;
    Ok(())
}
