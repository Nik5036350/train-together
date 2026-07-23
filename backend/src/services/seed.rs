use crate::entities::*;
use crate::ids::uid;
use sea_orm::ActiveValue::Set;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, DatabaseConnection, DbErr, EntityTrait, PaginatorTrait,
    QueryFilter,
};

// Seed data ported from the frontend's seed.js (owner Alex, partner Maria, the
// exercise library, per-person profiles, the "Push Day" template and one prior
// history session). Used on first boot and by the admin reset-demo endpoint.

// Fixed epoch-millis for the seeded prior session (2026-06-23 18:00 / 19:12 UTC).
// Only used for ordering/label, so the exact zone is irrelevant.
const PREV_START: i64 = 1_782_237_600_000;
const PREV_END: i64 = 1_782_241_920_000;

pub async fn seed_if_empty(db: &DatabaseConnection) -> Result<(), DbErr> {
    if person::Entity::find().count(db).await? == 0 {
        insert_seed(db).await?;
    }
    Ok(())
}

pub async fn reset_to_seed(db: &DatabaseConnection) -> Result<(), DbErr> {
    clear_all(db).await?;
    insert_seed(db).await?;
    Ok(())
}

// Re-add the seeded "Push Day" template + any seed exercises it references that
// were deleted, without disturbing the user's own data (RESTORE_DEMO_ROUTINE).
pub async fn restore_demo_routine(db: &DatabaseConnection) -> Result<(), DbErr> {
    for (id, name, cat, equip, w, r, d, rest) in seed_exercises() {
        if exercise::Entity::find_by_id(id).one(db).await?.is_none() {
            exercise_am(id, name, cat, equip, w, r, d, rest)
                .insert(db)
                .await?;
        }
    }
    // Upsert the template row.
    if template::Entity::find_by_id("t_push")
        .one(db)
        .await?
        .is_some()
    {
        template::Entity::delete_by_id("t_push").exec(db).await?;
    }
    template::ActiveModel {
        id: Set("t_push".into()),
        name: Set("Push Day".into()),
        default_mode: Set("alternate".into()),
    }
    .insert(db)
    .await?;
    template_exercise::Entity::delete_many()
        .filter(template_exercise::Column::TemplateId.eq("t_push"))
        .exec(db)
        .await?;
    insert_push_day(db).await?;
    Ok(())
}

pub async fn clear_all(db: &DatabaseConnection) -> Result<(), DbErr> {
    rest_timer::Entity::delete_many().exec(db).await?;
    set_entry::Entity::delete_many().exec(db).await?;
    session_exercise_person::Entity::delete_many()
        .exec(db)
        .await?;
    session_exercise::Entity::delete_many().exec(db).await?;
    session_participant::Entity::delete_many().exec(db).await?;
    workout_session::Entity::delete_many().exec(db).await?;
    template_exercise::Entity::delete_many().exec(db).await?;
    template::Entity::delete_many().exec(db).await?;
    person_exercise_profile::Entity::delete_many()
        .exec(db)
        .await?;
    exercise::Entity::delete_many().exec(db).await?;
    person::Entity::delete_many().exec(db).await?;
    app_settings::Entity::delete_many().exec(db).await?;
    Ok(())
}

async fn insert_seed(db: &DatabaseConnection) -> Result<(), DbErr> {
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
    .await?;

    person_am("p_alex", "Alex", "A", "blue", true)
        .insert(db)
        .await?;
    person_am("p_maria", "Maria", "M", "orange", false)
        .insert(db)
        .await?;

    for (id, name, cat, equip, w, r, d, rest) in seed_exercises() {
        exercise_am(id, name, cat, equip, w, r, d, rest)
            .insert(db)
            .await?;
    }

    let profiles = [
        ("p_alex", "ex_bench", 150, ""),
        ("p_maria", "ex_bench", 120, ""),
        ("p_alex", "ex_incline", 120, ""),
        ("p_maria", "ex_incline", 90, ""),
        ("p_maria", "ex_cablefly", 90, ""),
        ("p_alex", "ex_dip", 150, ""),
        ("p_alex", "ex_pushdown", 90, ""),
        ("p_maria", "ex_pushdown", 90, "Rope attachment"),
    ];
    for (pid, eid, rest, setup) in profiles {
        person_exercise_profile::ActiveModel {
            id: Set(uid("prof")),
            person_id: Set(pid.into()),
            exercise_id: Set(eid.into()),
            rest_seconds: Set(Some(rest)),
            machine_setup: Set(setup.into()),
            cues: Set("".into()),
        }
        .insert(db)
        .await?;
    }

    template::ActiveModel {
        id: Set("t_push".into()),
        name: Set("Push Day".into()),
        default_mode: Set("alternate".into()),
    }
    .insert(db)
    .await?;
    insert_push_day(db).await?;

    insert_seed_history(db).await?;
    Ok(())
}

async fn insert_push_day(db: &DatabaseConnection) -> Result<(), DbErr> {
    let rows = [
        ("ex_bench", "both", 0),
        ("ex_incline", "both", 1),
        ("ex_cablefly", "partner", 2),
        ("ex_dip", "owner", 3),
        ("ex_pushdown", "both", 4),
    ];
    for (eid, assign, order) in rows {
        template_exercise::ActiveModel {
            id: Set(uid("tex")),
            template_id: Set("t_push".into()),
            exercise_id: Set(eid.into()),
            assignment: Set(assign.into()),
            order_index: Set(order),
            default_logging_mode: Set(None),
        }
        .insert(db)
        .await?;
    }
    Ok(())
}

async fn insert_seed_history(db: &DatabaseConnection) -> Result<(), DbErr> {
    workout_session::ActiveModel {
        id: Set("sess_prev".into()),
        template_id: Set(Some("t_push".into())),
        name: Set("Push Day".into()),
        start_time: Set(PREV_START),
        end_time: Set(Some(PREV_END)),
        label: Set(Some("Mon".into())),
        logging_style: Set("alternate".into()),
        status: Set("finished".into()),
    }
    .insert(db)
    .await?;
    for (i, pid) in ["p_alex", "p_maria"].iter().enumerate() {
        session_participant::ActiveModel {
            id: Set(uid("spart")),
            session_id: Set("sess_prev".into()),
            person_id: Set((*pid).into()),
            order_index: Set(i as i32),
        }
        .insert(db)
        .await?;
    }
    // (exerciseId, personId, weight, reps, setIndex)
    let sets = [
        ("ex_bench", "p_alex", 80.0, 8, 0),
        ("ex_bench", "p_alex", 80.0, 7, 1),
        ("ex_bench", "p_alex", 77.5, 8, 2),
        ("ex_bench", "p_maria", 35.0, 10, 0),
        ("ex_bench", "p_maria", 35.0, 9, 1),
        ("ex_bench", "p_maria", 35.0, 8, 2),
        ("ex_incline", "p_alex", 30.0, 9, 0),
        ("ex_incline", "p_alex", 30.0, 8, 1),
        ("ex_incline", "p_alex", 28.0, 10, 2),
        ("ex_incline", "p_maria", 14.0, 12, 0),
        ("ex_incline", "p_maria", 14.0, 11, 1),
        ("ex_incline", "p_maria", 14.0, 10, 2),
        ("ex_cablefly", "p_maria", 12.5, 15, 0),
        ("ex_cablefly", "p_maria", 12.5, 13, 1),
        ("ex_cablefly", "p_maria", 12.5, 12, 2),
        ("ex_dip", "p_alex", 15.0, 8, 0),
        ("ex_dip", "p_alex", 15.0, 7, 1),
        ("ex_dip", "p_alex", 10.0, 8, 2),
        ("ex_pushdown", "p_alex", 40.0, 12, 0),
        ("ex_pushdown", "p_alex", 40.0, 10, 1),
        ("ex_pushdown", "p_alex", 37.5, 11, 2),
        ("ex_pushdown", "p_maria", 22.5, 12, 0),
        ("ex_pushdown", "p_maria", 22.5, 11, 1),
        ("ex_pushdown", "p_maria", 22.5, 10, 2),
    ];
    for (eid, pid, weight, reps, idx) in sets {
        set_entry::ActiveModel {
            id: Set(format!("h1_{}_{}_{}", eid, pid, idx)),
            session_id: Set("sess_prev".into()),
            session_exercise_id: Set(None),
            exercise_id: Set(eid.into()),
            person_id: Set(pid.into()),
            set_index: Set(idx),
            weight: Set(Some(weight)),
            reps: Set(Some(reps)),
            duration: Set(None),
            set_type: Set("working".into()),
            timestamp: Set(None),
            note: Set(None),
        }
        .insert(db)
        .await?;
    }
    Ok(())
}

fn person_am(
    id: &str,
    name: &str,
    initials: &str,
    color: &str,
    is_owner: bool,
) -> person::ActiveModel {
    person::ActiveModel {
        id: Set(id.into()),
        name: Set(name.into()),
        initials: Set(initials.into()),
        color: Set(color.into()),
        unit: Set("kg".into()),
        is_owner: Set(is_owner),
        active: Set(true),
    }
}

#[allow(clippy::too_many_arguments)]
fn exercise_am(
    id: &str,
    name: &str,
    category: &str,
    equipment: &str,
    w: bool,
    r: bool,
    d: bool,
    rest: i32,
) -> exercise::ActiveModel {
    exercise::ActiveModel {
        id: Set(id.into()),
        name: Set(name.into()),
        category: Set(category.into()),
        equipment: Set(equipment.into()),
        tracks_weight: Set(w),
        tracks_reps: Set(r),
        tracks_duration: Set(d),
        default_rest_seconds: Set(rest),
    }
}

type ExerciseSeed = (
    &'static str,
    &'static str,
    &'static str,
    &'static str,
    bool,
    bool,
    bool,
    i32,
);

fn seed_exercises() -> [ExerciseSeed; 8] {
    [
        (
            "ex_bench",
            "Bench Press",
            "Chest",
            "Barbell",
            true,
            true,
            false,
            120,
        ),
        (
            "ex_incline",
            "Incline DB Press",
            "Chest",
            "Dumbbell",
            true,
            true,
            false,
            120,
        ),
        (
            "ex_cablefly",
            "Cable Fly",
            "Chest",
            "Cable Machine",
            true,
            true,
            false,
            90,
        ),
        (
            "ex_dip",
            "Weighted Dip",
            "Triceps",
            "Bodyweight",
            true,
            true,
            false,
            120,
        ),
        (
            "ex_pushdown",
            "Triceps Pushdown",
            "Triceps",
            "Cable Machine",
            true,
            true,
            false,
            90,
        ),
        (
            "ex_machinechest",
            "Machine Chest Press",
            "Chest",
            "Machine",
            true,
            true,
            false,
            90,
        ),
        (
            "ex_facepull",
            "Face Pull",
            "Shoulders",
            "Cable Machine",
            true,
            true,
            false,
            60,
        ),
        (
            "ex_plank",
            "Plank",
            "Core",
            "Bodyweight",
            false,
            false,
            true,
            60,
        ),
    ]
}
