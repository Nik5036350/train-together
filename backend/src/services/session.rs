use crate::dto::LogValues;
use crate::entities::*;
use crate::error::{AppError, AppResult};
use crate::ids::uid;
use sea_orm::ActiveValue::Set;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, DatabaseConnection, DbErr, EntityTrait, IntoActiveModel,
    QueryFilter, QueryOrder,
};
use std::time::{SystemTime, UNIX_EPOCH};

fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

// ---- shared helpers (ports of the reducer selectors) ----

async fn owner_of(db: &DatabaseConnection) -> Result<Option<person::Model>, DbErr> {
    person::Entity::find()
        .filter(person::Column::IsOwner.eq(true))
        .one(db)
        .await
}

async fn partner_of(db: &DatabaseConnection) -> Result<Option<person::Model>, DbErr> {
    person::Entity::find()
        .filter(person::Column::IsOwner.eq(false))
        .filter(person::Column::Active.eq(true))
        .one(db)
        .await
}

async fn applies_to(
    db: &DatabaseConnection,
    assignment: &str,
    participant_ids: &[String],
) -> Result<Vec<String>, DbErr> {
    let owner = owner_of(db).await?.map(|p| p.id);
    let partner = partner_of(db).await?.map(|p| p.id);
    let wanted: Vec<Option<String>> = match assignment {
        "both" => vec![owner, partner],
        "owner" => vec![owner],
        _ => vec![partner],
    };
    Ok(wanted
        .into_iter()
        .flatten()
        .filter(|id| participant_ids.contains(id))
        .collect())
}

// Personal profile rest overrides the exercise default (0 falls through).
async fn rest_seconds_for(
    db: &DatabaseConnection,
    person_id: &str,
    exercise_id: &str,
) -> Result<i32, DbErr> {
    let prof = person_exercise_profile::Entity::find()
        .filter(person_exercise_profile::Column::PersonId.eq(person_id))
        .filter(person_exercise_profile::Column::ExerciseId.eq(exercise_id))
        .one(db)
        .await?;
    if let Some(r) = prof.and_then(|p| p.rest_seconds) {
        if r != 0 {
            return Ok(r);
        }
    }
    let def = exercise::Entity::find_by_id(exercise_id)
        .one(db)
        .await?
        .map(|e| e.default_rest_seconds)
        .unwrap_or(90);
    Ok(if def == 0 { 90 } else { def })
}

async fn effective_exercise_id(
    db: &DatabaseConnection,
    se: &session_exercise::Model,
    person_id: &str,
) -> Result<String, DbErr> {
    let sub = session_exercise_person::Entity::find()
        .filter(session_exercise_person::Column::SessionExerciseId.eq(&se.id))
        .filter(session_exercise_person::Column::PersonId.eq(person_id))
        .one(db)
        .await?
        .and_then(|p| p.substitute_exercise_id);
    Ok(sub.unwrap_or_else(|| se.exercise_id.clone()))
}

async fn require_session(db: &DatabaseConnection, id: &str) -> AppResult<workout_session::Model> {
    workout_session::Entity::find_by_id(id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Session {id} not found")))
}

async fn require_se(db: &DatabaseConnection, id: &str) -> AppResult<session_exercise::Model> {
    session_exercise::Entity::find_by_id(id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Session exercise {id} not found")))
}

async fn se_persons(
    db: &DatabaseConnection,
    se_id: &str,
) -> Result<Vec<session_exercise_person::Model>, DbErr> {
    session_exercise_person::Entity::find()
        .filter(session_exercise_person::Column::SessionExerciseId.eq(se_id))
        .order_by_asc(session_exercise_person::Column::OrderIndex)
        .all(db)
        .await
}

async fn insert_sep(
    db: &DatabaseConnection,
    se_id: &str,
    person_id: &str,
    order: usize,
) -> Result<(), DbErr> {
    session_exercise_person::ActiveModel {
        id: Set(uid("sep")),
        session_exercise_id: Set(se_id.into()),
        person_id: Set(person_id.into()),
        status: Set("pending".into()),
        skip_reason: Set(None),
        substitute_exercise_id: Set(None),
        order_index: Set(order as i32),
    }
    .insert(db)
    .await?;
    Ok(())
}

async fn participant_ids(db: &DatabaseConnection, session_id: &str) -> Result<Vec<String>, DbErr> {
    Ok(session_participant::Entity::find()
        .filter(session_participant::Column::SessionId.eq(session_id))
        .order_by_asc(session_participant::Column::OrderIndex)
        .all(db)
        .await?
        .into_iter()
        .map(|p| p.person_id)
        .collect())
}

// ---- lifecycle ----

pub async fn start_session(
    db: &DatabaseConnection,
    template_id: String,
    participants: Vec<String>,
    logging_style: Option<String>,
) -> AppResult<()> {
    let tpl = template::Entity::find_by_id(&template_id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Template {template_id} not found")))?;

    // Only one active session at a time — discard any existing one.
    if let Some(active) = workout_session::Entity::find()
        .filter(workout_session::Column::Status.eq("active"))
        .one(db)
        .await?
    {
        delete_session_graph(db, &active.id).await?;
    }

    let style = logging_style.unwrap_or_else(|| tpl.default_mode.clone());
    let session_id = uid("sess");
    workout_session::ActiveModel {
        id: Set(session_id.clone()),
        template_id: Set(Some(template_id.clone())),
        name: Set(tpl.name.clone()),
        start_time: Set(now()),
        end_time: Set(None),
        label: Set(None),
        logging_style: Set(style.clone()),
        status: Set("active".into()),
    }
    .insert(db)
    .await?;

    for (i, pid) in participants.iter().enumerate() {
        session_participant::ActiveModel {
            id: Set(uid("spart")),
            session_id: Set(session_id.clone()),
            person_id: Set(pid.clone()),
            order_index: Set(i as i32),
        }
        .insert(db)
        .await?;
    }

    let tes = template_exercise::Entity::find()
        .filter(template_exercise::Column::TemplateId.eq(&template_id))
        .order_by_asc(template_exercise::Column::OrderIndex)
        .all(db)
        .await?;
    let mut order = 0;
    for te in tes {
        let ppl = applies_to(db, &te.assignment, &participants).await?;
        if ppl.is_empty() {
            continue;
        }
        let se_id = uid("se");
        session_exercise::ActiveModel {
            id: Set(se_id.clone()),
            session_id: Set(session_id.clone()),
            exercise_id: Set(te.exercise_id.clone()),
            logging_mode: Set(te
                .default_logging_mode
                .clone()
                .unwrap_or_else(|| style.clone())),
            active_person_id: Set(Some(ppl[0].clone())),
            added_during_session: Set(false),
            order_index: Set(order),
        }
        .insert(db)
        .await?;
        order += 1;
        for (i, pid) in ppl.iter().enumerate() {
            insert_sep(db, &se_id, pid, i).await?;
        }
    }
    Ok(())
}

pub async fn finish_session(db: &DatabaseConnection, session_id: &str) -> AppResult<()> {
    let s = require_session(db, session_id).await?;
    let mut am = s.into_active_model();
    am.status = Set("finished".into());
    am.end_time = Set(Some(now()));
    am.update(db).await?;
    // Rest timers are transient countdowns — meaningless in history.
    rest_timer::Entity::delete_many()
        .filter(rest_timer::Column::SessionId.eq(session_id))
        .exec(db)
        .await?;
    Ok(())
}

async fn delete_session_graph(db: &DatabaseConnection, session_id: &str) -> Result<(), DbErr> {
    rest_timer::Entity::delete_many()
        .filter(rest_timer::Column::SessionId.eq(session_id))
        .exec(db)
        .await?;
    set_entry::Entity::delete_many()
        .filter(set_entry::Column::SessionId.eq(session_id))
        .exec(db)
        .await?;
    for se in session_exercise::Entity::find()
        .filter(session_exercise::Column::SessionId.eq(session_id))
        .all(db)
        .await?
    {
        session_exercise_person::Entity::delete_many()
            .filter(session_exercise_person::Column::SessionExerciseId.eq(&se.id))
            .exec(db)
            .await?;
    }
    session_exercise::Entity::delete_many()
        .filter(session_exercise::Column::SessionId.eq(session_id))
        .exec(db)
        .await?;
    session_participant::Entity::delete_many()
        .filter(session_participant::Column::SessionId.eq(session_id))
        .exec(db)
        .await?;
    workout_session::Entity::delete_by_id(session_id)
        .exec(db)
        .await?;
    Ok(())
}

// Removes a finished workout and everything hanging off it. Active sessions are
// off limits — they're discarded via start_session, not deleted by hand.
pub async fn delete_session(db: &DatabaseConnection, session_id: &str) -> AppResult<()> {
    let session = require_session(db, session_id).await?;
    if session.status == "active" {
        return Err(AppError::BadRequest(
            "Cannot delete a workout that's still in progress. Finish it first.".into(),
        ));
    }
    delete_session_graph(db, session_id).await?;
    Ok(())
}

// ---- logging ----

pub async fn log_set(
    db: &DatabaseConnection,
    session_id: &str,
    session_exercise_id: &str,
    person_id: &str,
    values: LogValues,
    set_type: Option<String>,
) -> AppResult<()> {
    require_session(db, session_id).await?;
    let se = require_se(db, session_exercise_id).await?;
    let ex_id = effective_exercise_id(db, &se, person_id).await?;

    let prior_count = set_entry::Entity::find()
        .filter(set_entry::Column::SessionId.eq(session_id))
        .filter(set_entry::Column::SessionExerciseId.eq(session_exercise_id))
        .filter(set_entry::Column::PersonId.eq(person_id))
        .all(db)
        .await?
        .len() as i32;

    let note = values.note.filter(|n| !n.trim().is_empty());
    set_entry::ActiveModel {
        id: Set(uid("set")),
        session_id: Set(session_id.into()),
        session_exercise_id: Set(Some(session_exercise_id.into())),
        exercise_id: Set(ex_id.clone()),
        person_id: Set(person_id.into()),
        set_index: Set(prior_count),
        weight: Set(values.weight),
        reps: Set(values.reps),
        duration: Set(values.duration),
        set_type: Set(set_type.unwrap_or_else(|| "working".into())),
        timestamp: Set(Some(now())),
        note: Set(note),
    }
    .insert(db)
    .await?;

    // Switch active row for alternate / turns modes.
    let persons = se_persons(db, session_exercise_id).await?;
    let others: Vec<&String> = persons
        .iter()
        .map(|p| &p.person_id)
        .filter(|id| *id != person_id)
        .collect();
    let switch = se.logging_mode == "alternate" || se.logging_mode == "turns";
    let next_active = if switch && !others.is_empty() {
        others[0].clone()
    } else {
        person_id.to_string()
    };
    let mut se_am = se.into_active_model();
    se_am.active_person_id = Set(Some(next_active));
    se_am.update(db).await?;

    if let Some(sep) = persons.into_iter().find(|p| p.person_id == person_id) {
        let mut am = sep.into_active_model();
        am.status = Set("logged".into());
        am.update(db).await?;
    }

    upsert_timer(
        db,
        session_id,
        person_id,
        session_exercise_id,
        rest_seconds_for(db, person_id, &ex_id).await?,
    )
    .await?;
    Ok(())
}

async fn upsert_timer(
    db: &DatabaseConnection,
    session_id: &str,
    person_id: &str,
    session_exercise_id: &str,
    duration_seconds: i32,
) -> Result<(), DbErr> {
    let existing = rest_timer::Entity::find()
        .filter(rest_timer::Column::SessionId.eq(session_id))
        .filter(rest_timer::Column::PersonId.eq(person_id))
        .one(db)
        .await?;
    match existing {
        Some(t) => {
            let mut am = t.into_active_model();
            am.session_exercise_id = Set(session_exercise_id.into());
            am.started_at = Set(now());
            am.duration_seconds = Set(duration_seconds);
            am.update(db).await?;
        }
        None => {
            rest_timer::ActiveModel {
                id: Set(uid("tmr")),
                session_id: Set(session_id.into()),
                person_id: Set(person_id.into()),
                session_exercise_id: Set(session_exercise_id.into()),
                started_at: Set(now()),
                duration_seconds: Set(duration_seconds),
            }
            .insert(db)
            .await?;
        }
    }
    Ok(())
}

pub async fn undo_set(db: &DatabaseConnection, session_id: &str, set_id: &str) -> AppResult<()> {
    let removed = set_entry::Entity::find_by_id(set_id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Set {set_id} not found")))?;
    set_entry::Entity::delete_by_id(set_id).exec(db).await?;

    if let Some(se_id) = &removed.session_exercise_id {
        if let Some(se) = session_exercise::Entity::find_by_id(se_id).one(db).await? {
            let mut am = se.into_active_model();
            am.active_person_id = Set(Some(removed.person_id.clone()));
            am.update(db).await?;
        }
    }
    if let Some(t) = rest_timer::Entity::find()
        .filter(rest_timer::Column::SessionId.eq(session_id))
        .filter(rest_timer::Column::PersonId.eq(&removed.person_id))
        .one(db)
        .await?
    {
        if t.session_exercise_id == removed.session_exercise_id.clone().unwrap_or_default() {
            rest_timer::Entity::delete_by_id(t.id).exec(db).await?;
        }
    }
    Ok(())
}

// ---- set editing (works for both active and finished sessions) ----

pub async fn edit_set(
    db: &DatabaseConnection,
    set_id: &str,
    values: &serde_json::Map<String, serde_json::Value>,
) -> AppResult<()> {
    let s = set_entry::Entity::find_by_id(set_id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Set {set_id} not found")))?;
    let mut am = s.into_active_model();
    if let Some(v) = values.get("weight") {
        am.weight = Set(v.as_f64());
    }
    if let Some(v) = values.get("reps") {
        am.reps = Set(v.as_i64().map(|n| n as i32));
    }
    if let Some(v) = values.get("duration") {
        am.duration = Set(v.as_i64().map(|n| n as i32));
    }
    if let Some(v) = values.get("note") {
        am.note = Set(v.as_str().map(|s| s.to_string()));
    }
    am.update(db).await?;
    Ok(())
}

pub async fn delete_set(db: &DatabaseConnection, session_id: &str, set_id: &str) -> AppResult<()> {
    let session = require_session(db, session_id).await?;
    let removed = set_entry::Entity::find_by_id(set_id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Set {set_id} not found")))?;
    set_entry::Entity::delete_by_id(set_id).exec(db).await?;

    // Renumber the affected group so setIndex stays contiguous. Active groups by
    // sessionExerciseId; finished groups by exerciseId.
    let remaining = set_entry::Entity::find()
        .filter(set_entry::Column::SessionId.eq(session_id))
        .all(db)
        .await?;
    let mut group: Vec<set_entry::Model> = remaining
        .into_iter()
        .filter(|s| {
            s.person_id == removed.person_id
                && if session.status == "finished" {
                    s.exercise_id == removed.exercise_id
                } else {
                    s.session_exercise_id == removed.session_exercise_id
                }
        })
        .collect();
    group.sort_by(|a, b| {
        a.timestamp
            .unwrap_or(0)
            .cmp(&b.timestamp.unwrap_or(0))
            .then(a.set_index.cmp(&b.set_index))
    });
    for (i, s) in group.into_iter().enumerate() {
        if s.set_index != i as i32 {
            let mut am = s.into_active_model();
            am.set_index = Set(i as i32);
            am.update(db).await?;
        }
    }
    Ok(())
}

pub async fn reassign_set(
    db: &DatabaseConnection,
    set_id: &str,
    to_person_id: &str,
) -> AppResult<()> {
    let s = set_entry::Entity::find_by_id(set_id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Set {set_id} not found")))?;
    let mut am = s.into_active_model();
    am.person_id = Set(to_person_id.into());
    am.update(db).await?;
    Ok(())
}

// ---- per-person status / skips / substitution ----

async fn person_row(
    db: &DatabaseConnection,
    se_id: &str,
    person_id: &str,
) -> AppResult<session_exercise_person::Model> {
    se_persons(db, se_id)
        .await?
        .into_iter()
        .find(|p| p.person_id == person_id)
        .ok_or_else(|| {
            AppError::NotFound(format!(
                "Person {person_id} not in session exercise {se_id}"
            ))
        })
}

pub async fn set_person_status(
    db: &DatabaseConnection,
    se_id: &str,
    person_id: &str,
    status: &str,
) -> AppResult<()> {
    let sep = person_row(db, se_id, person_id).await?;
    let mut am = sep.into_active_model();
    am.status = Set(status.into());
    am.update(db).await?;
    Ok(())
}

pub async fn skip_turn(db: &DatabaseConnection, se_id: &str, person_id: &str) -> AppResult<()> {
    let se = require_se(db, se_id).await?;
    let persons = se_persons(db, se_id).await?;
    let next = persons
        .iter()
        .find(|p| p.person_id != person_id && p.status != "skipped")
        .map(|p| p.person_id.clone())
        .or_else(|| se.active_person_id.clone());
    let mut am = se.into_active_model();
    am.active_person_id = Set(next);
    am.update(db).await?;
    Ok(())
}

pub async fn skip_exercise(
    db: &DatabaseConnection,
    se_id: &str,
    person_id: &str,
    reason: Option<String>,
) -> AppResult<()> {
    let se = require_se(db, se_id).await?;
    let persons = se_persons(db, se_id).await?;
    let next = persons
        .iter()
        .find(|p| p.person_id != person_id)
        .map(|p| p.person_id.clone())
        .or_else(|| se.active_person_id.clone());
    let mut se_am = se.into_active_model();
    se_am.active_person_id = Set(next);
    se_am.update(db).await?;

    let sep = persons
        .into_iter()
        .find(|p| p.person_id == person_id)
        .ok_or_else(|| AppError::NotFound(format!("Person {person_id} not in {se_id}")))?;
    let mut am = sep.into_active_model();
    am.status = Set("skipped".into());
    am.skip_reason = Set(reason);
    am.update(db).await?;
    Ok(())
}

pub async fn substitute_exercise(
    db: &DatabaseConnection,
    se_id: &str,
    person_id: &str,
    substitute_exercise_id: Option<String>,
) -> AppResult<()> {
    let sep = person_row(db, se_id, person_id).await?;
    let mut am = sep.into_active_model();
    am.substitute_exercise_id = Set(substitute_exercise_id);
    am.update(db).await?;
    Ok(())
}

pub async fn add_session_exercise(
    db: &DatabaseConnection,
    session_id: &str,
    exercise_id: &str,
    assignment: &str,
) -> AppResult<()> {
    let session = require_session(db, session_id).await?;
    let ppl = applies_to(db, assignment, &participant_ids(db, session_id).await?).await?;
    if ppl.is_empty() {
        return Ok(());
    }
    let next_order = session_exercise::Entity::find()
        .filter(session_exercise::Column::SessionId.eq(session_id))
        .all(db)
        .await?
        .iter()
        .map(|s| s.order_index)
        .max()
        .map(|m| m + 1)
        .unwrap_or(0);
    let se_id = uid("se");
    session_exercise::ActiveModel {
        id: Set(se_id.clone()),
        session_id: Set(session_id.into()),
        exercise_id: Set(exercise_id.into()),
        logging_mode: Set(session.logging_style.clone()),
        active_person_id: Set(Some(ppl[0].clone())),
        added_during_session: Set(true),
        order_index: Set(next_order),
    }
    .insert(db)
    .await?;
    for (i, pid) in ppl.iter().enumerate() {
        insert_sep(db, &se_id, pid, i).await?;
    }
    Ok(())
}

pub async fn set_logging_mode(db: &DatabaseConnection, se_id: &str, mode: &str) -> AppResult<()> {
    let se = require_se(db, se_id).await?;
    let mut am = se.into_active_model();
    am.logging_mode = Set(mode.into());
    am.update(db).await?;
    Ok(())
}

pub async fn set_active_row(
    db: &DatabaseConnection,
    se_id: &str,
    person_id: &str,
) -> AppResult<()> {
    let se = require_se(db, se_id).await?;
    let mut am = se.into_active_model();
    am.active_person_id = Set(Some(person_id.into()));
    am.update(db).await?;
    Ok(())
}
