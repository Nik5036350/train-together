use crate::entities::*;
use crate::error::{AppError, AppResult};
use crate::ids::uid;
use crate::services::seed;
use crate::state::{SessionResp, StateResponse, BACKUP_FORMAT_VERSION};
use sea_orm::ActiveValue::Set;
use sea_orm::{ActiveModelTrait, DatabaseConnection, DbErr};

// Admin / backup operations: reset-demo and restore-demo-routine delegate to the
// seeder; import replaces the whole DB from an exported aggregate (HYDRATE).

pub async fn reset_demo(db: &DatabaseConnection) -> Result<(), DbErr> {
    seed::reset_to_seed(db).await
}

pub async fn restore_demo_routine(db: &DatabaseConnection) -> Result<(), DbErr> {
    seed::restore_demo_routine(db).await
}

pub async fn import_state(db: &DatabaseConnection, state: StateResponse) -> AppResult<()> {
    // Reject anything older than the format the serde defaults are written to
    // tolerate, rather than clearing the database and then half-importing a shape
    // that cannot be represented. This runs before clear_all for that reason.
    if state.version < BACKUP_FORMAT_VERSION {
        return Err(AppError::BadRequest(format!(
            "backup format version {} is too old to import (minimum {BACKUP_FORMAT_VERSION})",
            state.version
        )));
    }

    seed::clear_all(db).await?;

    app_settings::ActiveModel {
        id: Set(app_settings::SINGLETON_ID.into()),
        couple_mode_enabled: Set(state.settings.couple_mode_enabled),
        default_participants: Set(state.settings.default_participants),
        default_logging_style: Set(state.settings.default_logging_style),
        allow_copy_partner_values: Set(state.settings.allow_copy_partner_values),
        show_partner_history: Set(state.settings.show_partner_history),
        onboarded: Set(state.onboarded),
        version: Set(state.version),
    }
    .insert(db)
    .await?;

    for p in state.people {
        person::ActiveModel {
            id: Set(p.id),
            name: Set(p.name),
            initials: Set(p.initials),
            color: Set(p.color),
            unit: Set(p.unit),
            is_owner: Set(p.is_owner),
            active: Set(p.active),
        }
        .insert(db)
        .await?;
    }

    for (_id, e) in state.exercises {
        exercise::ActiveModel {
            id: Set(e.id),
            name: Set(e.name),
            category: Set(e.category),
            equipment: Set(e.equipment),
            tracks_weight: Set(e.tracks.weight),
            tracks_reps: Set(e.tracks.reps),
            tracks_duration: Set(e.tracks.duration),
            default_rest_seconds: Set(e.default_rest_seconds),
        }
        .insert(db)
        .await?;
    }

    for (key, p) in state.person_exercise_profiles {
        let (person_id, exercise_id) = key.split_once("__").unwrap_or((key.as_str(), ""));
        person_exercise_profile::ActiveModel {
            id: Set(uid("prof")),
            person_id: Set(person_id.into()),
            exercise_id: Set(exercise_id.into()),
            rest_seconds: Set(p.rest_seconds),
            machine_setup: Set(p.machine_setup),
            cues: Set(p.cues),
        }
        .insert(db)
        .await?;
    }

    for (_id, tpl) in state.templates {
        template::ActiveModel {
            id: Set(tpl.id.clone()),
            name: Set(tpl.name),
            default_mode: Set(tpl.default_mode),
        }
        .insert(db)
        .await?;
        for te in tpl.exercises {
            template_exercise::ActiveModel {
                id: Set(uid("tex")),
                template_id: Set(tpl.id.clone()),
                exercise_id: Set(te.exercise_id),
                assignment: Set(te.assignment),
                order_index: Set(te.order),
                default_logging_mode: Set(te.default_logging_mode),
            }
            .insert(db)
            .await?;
        }
    }

    for s in state.history {
        persist_session(db, s).await?;
    }
    if let Some(s) = state.session {
        persist_session(db, s).await?;
    }
    Ok(())
}

async fn persist_session(db: &DatabaseConnection, s: SessionResp) -> Result<(), DbErr> {
    workout_session::ActiveModel {
        id: Set(s.id.clone()),
        template_id: Set(s.template_id),
        name: Set(s.name),
        start_time: Set(s.start_time),
        end_time: Set(s.end_time),
        label: Set(s.label),
        logging_style: Set(s.logging_style),
        status: Set(s.status),
    }
    .insert(db)
    .await?;

    for (i, pid) in s.participant_ids.into_iter().enumerate() {
        session_participant::ActiveModel {
            id: Set(uid("spart")),
            session_id: Set(s.id.clone()),
            person_id: Set(pid),
            order_index: Set(i as i32),
        }
        .insert(db)
        .await?;
    }

    for (order, se) in s.exercises.into_iter().enumerate() {
        session_exercise::ActiveModel {
            id: Set(se.id.clone()),
            session_id: Set(s.id.clone()),
            exercise_id: Set(se.exercise_id),
            logging_mode: Set(se.logging_mode),
            variant: Set(se.variant),
            active_person_id: Set(se.active_person_id),
            added_during_session: Set(se.added_during_session.unwrap_or(false)),
            order_index: Set(order as i32),
        }
        .insert(db)
        .await?;
        for (i, person_id) in se.applies_to.into_iter().enumerate() {
            let pp = se.per_person.get(&person_id);
            session_exercise_person::ActiveModel {
                id: Set(uid("sep")),
                session_exercise_id: Set(se.id.clone()),
                person_id: Set(person_id),
                status: Set(pp
                    .map(|p| p.status.clone())
                    .unwrap_or_else(|| "pending".into())),
                skip_reason: Set(pp.and_then(|p| p.skip_reason.clone())),
                substitute_exercise_id: Set(pp.and_then(|p| p.substitute_exercise_id.clone())),
                order_index: Set(i as i32),
            }
            .insert(db)
            .await?;
        }
    }

    for st in s.sets {
        set_entry::ActiveModel {
            id: Set(st.id),
            session_id: Set(s.id.clone()),
            session_exercise_id: Set(st.session_exercise_id),
            exercise_id: Set(st.exercise_id),
            person_id: Set(st.person_id),
            set_index: Set(st.set_index),
            weight: Set(st.weight),
            reps: Set(st.reps),
            duration: Set(st.duration),
            set_type: Set(st.set_type),
            variant: Set(st.variant),
            timestamp: Set(st.timestamp),
            note: Set(st.note),
        }
        .insert(db)
        .await?;
    }

    for (person_id, t) in s.timers {
        rest_timer::ActiveModel {
            id: Set(uid("tmr")),
            session_id: Set(s.id.clone()),
            person_id: Set(person_id),
            session_exercise_id: Set(t.session_exercise_id),
            started_at: Set(t.started_at),
            duration_seconds: Set(t.duration_seconds),
        }
        .insert(db)
        .await?;
    }
    Ok(())
}
