use crate::dto::*;
use crate::error::AppResult;
use crate::services::{admin, catalog, session};
use crate::state::{build_state, StateResponse};
use axum::extract::{Json, Path, State};
use axum::http::{header, StatusCode, Uri};
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get, patch, post, put};
use axum::Router;
use rust_embed::RustEmbed;
use sea_orm::DatabaseConnection;
use tower_http::cors::CorsLayer;

type Db = State<DatabaseConnection>;

// The compiled frontend, baked into the binary (Docker copies the Vite build
// here before `cargo build`).
#[derive(RustEmbed)]
#[folder = "static/"]
struct Assets;

pub fn router(db: DatabaseConnection) -> Router {
    Router::new()
        .route("/api/state", get(get_state).put(import_state))
        .route("/api/partner", put(save_partner))
        .route("/api/people/:id", patch(update_person))
        .route("/api/settings", patch(update_settings))
        .route("/api/settings/toggle-couple-mode", post(toggle_couple_mode))
        .route("/api/exercises", post(create_exercise))
        .route(
            "/api/exercises/:id",
            put(update_exercise).delete(delete_exercise),
        )
        .route("/api/templates", post(create_template))
        .route(
            "/api/templates/:id",
            put(update_template).delete(delete_template),
        )
        .route(
            "/api/templates/:id/exercises/:exercise_id/assignment",
            patch(set_assignment),
        )
        .route("/api/sessions", post(start_session))
        .route("/api/sessions/:id", delete(delete_session))
        .route("/api/sessions/:id/finish", post(finish_session))
        .route("/api/sessions/:id/sets", post(log_set))
        .route("/api/sessions/:id/sets/:set_id/undo", post(undo_set))
        .route(
            "/api/sessions/:id/sets/:set_id",
            patch(edit_set).delete(delete_set),
        )
        .route(
            "/api/sessions/:id/sets/:set_id/reassign",
            patch(reassign_set),
        )
        .route("/api/sessions/:id/exercises", post(add_session_exercise))
        .route("/api/session-exercises/:id/skip-turn", post(skip_turn))
        .route("/api/session-exercises/:id/skip", post(skip_exercise))
        .route("/api/session-exercises/:id/substitute", patch(substitute))
        .route(
            "/api/session-exercises/:id/person-status",
            patch(person_status),
        )
        .route(
            "/api/session-exercises/:id/logging-mode",
            patch(logging_mode),
        )
        .route("/api/session-exercises/:id/active-row", patch(active_row))
        .route("/api/admin/reset-demo", post(reset_demo))
        .route(
            "/api/admin/restore-demo-routine",
            post(restore_demo_routine),
        )
        .with_state(db)
        .fallback(static_handler)
        .layer(CorsLayer::permissive())
}

async fn state_of(db: &DatabaseConnection) -> AppResult<Json<StateResponse>> {
    Ok(Json(build_state(db).await?))
}

// ---- state / import ----

async fn get_state(State(db): Db) -> AppResult<Json<StateResponse>> {
    state_of(&db).await
}

async fn import_state(
    State(db): Db,
    Json(body): Json<StateResponse>,
) -> AppResult<Json<StateResponse>> {
    admin::import_state(&db, body).await?;
    state_of(&db).await
}

// ---- people / settings ----

async fn save_partner(
    State(db): Db,
    Json(r): Json<SavePartnerRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::save_partner(&db, r.name, r.color, r.unit, r.initials).await?;
    state_of(&db).await
}

async fn update_person(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<UpdatePersonRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::update_person(&db, &id, r.name, r.color, r.unit, r.initials, r.active).await?;
    state_of(&db).await
}

async fn update_settings(
    State(db): Db,
    Json(r): Json<UpdateSettingsRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::update_settings(
        &db,
        r.couple_mode_enabled,
        r.default_participants,
        r.default_logging_style,
        r.allow_copy_partner_values,
        r.show_partner_history,
    )
    .await?;
    state_of(&db).await
}

async fn toggle_couple_mode(State(db): Db) -> AppResult<Json<StateResponse>> {
    catalog::toggle_couple_mode(&db).await?;
    state_of(&db).await
}

// ---- exercises ----

fn profiles_vec(
    profiles: std::collections::HashMap<String, ProfileInput>,
) -> Vec<(String, Option<i32>, String, String)> {
    profiles
        .into_iter()
        .map(|(pid, p)| {
            (
                pid,
                p.rest_seconds,
                p.machine_setup.unwrap_or_default(),
                p.cues.unwrap_or_default(),
            )
        })
        .collect()
}

async fn create_exercise(
    State(db): Db,
    Json(r): Json<SaveExerciseRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::save_exercise(
        &db,
        r.id,
        r.name,
        r.category,
        r.equipment,
        (r.tracks.weight, r.tracks.reps, r.tracks.duration),
        r.default_rest_seconds,
        profiles_vec(r.profiles),
    )
    .await?;
    state_of(&db).await
}

async fn update_exercise(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<SaveExerciseRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::save_exercise(
        &db,
        Some(id),
        r.name,
        r.category,
        r.equipment,
        (r.tracks.weight, r.tracks.reps, r.tracks.duration),
        r.default_rest_seconds,
        profiles_vec(r.profiles),
    )
    .await?;
    state_of(&db).await
}

async fn delete_exercise(State(db): Db, Path(id): Path<String>) -> AppResult<Json<StateResponse>> {
    catalog::delete_exercise(&db, &id).await?;
    state_of(&db).await
}

// ---- templates ----

fn template_exercises_vec(
    exs: Vec<TemplateExerciseInput>,
) -> Vec<(String, String, i32, Option<String>)> {
    exs.into_iter()
        .map(|e| (e.exercise_id, e.assignment, e.order, e.default_logging_mode))
        .collect()
}

async fn create_template(
    State(db): Db,
    Json(r): Json<SaveTemplateRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::save_template(
        &db,
        r.id,
        r.name,
        r.default_mode,
        template_exercises_vec(r.exercises),
    )
    .await?;
    state_of(&db).await
}

async fn update_template(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<SaveTemplateRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::save_template(
        &db,
        Some(id),
        r.name,
        r.default_mode,
        template_exercises_vec(r.exercises),
    )
    .await?;
    state_of(&db).await
}

async fn delete_template(State(db): Db, Path(id): Path<String>) -> AppResult<Json<StateResponse>> {
    catalog::delete_template(&db, &id).await?;
    state_of(&db).await
}

async fn set_assignment(
    State(db): Db,
    Path((id, exercise_id)): Path<(String, String)>,
    Json(r): Json<SetAssignmentRequest>,
) -> AppResult<Json<StateResponse>> {
    catalog::set_assignment(&db, &id, &exercise_id, &r.assignment).await?;
    state_of(&db).await
}

// ---- sessions ----

async fn start_session(
    State(db): Db,
    Json(r): Json<StartSessionRequest>,
) -> AppResult<Json<StateResponse>> {
    session::start_session(&db, r.template_id, r.participant_ids, r.logging_style).await?;
    state_of(&db).await
}

async fn finish_session(State(db): Db, Path(id): Path<String>) -> AppResult<Json<StateResponse>> {
    session::finish_session(&db, &id).await?;
    state_of(&db).await
}

async fn delete_session(State(db): Db, Path(id): Path<String>) -> AppResult<Json<StateResponse>> {
    session::delete_session(&db, &id).await?;
    state_of(&db).await
}

async fn log_set(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<LogSetRequest>,
) -> AppResult<Json<StateResponse>> {
    session::log_set(
        &db,
        &id,
        &r.session_exercise_id,
        &r.person_id,
        r.values,
        r.set_type,
    )
    .await?;
    state_of(&db).await
}

async fn undo_set(
    State(db): Db,
    Path((id, set_id)): Path<(String, String)>,
) -> AppResult<Json<StateResponse>> {
    session::undo_set(&db, &id, &set_id).await?;
    state_of(&db).await
}

async fn edit_set(
    State(db): Db,
    Path((_id, set_id)): Path<(String, String)>,
    Json(r): Json<EditSetRequest>,
) -> AppResult<Json<StateResponse>> {
    session::edit_set(&db, &set_id, &r.values).await?;
    state_of(&db).await
}

async fn delete_set(
    State(db): Db,
    Path((id, set_id)): Path<(String, String)>,
) -> AppResult<Json<StateResponse>> {
    session::delete_set(&db, &id, &set_id).await?;
    state_of(&db).await
}

async fn reassign_set(
    State(db): Db,
    Path((_id, set_id)): Path<(String, String)>,
    Json(r): Json<ReassignSetRequest>,
) -> AppResult<Json<StateResponse>> {
    session::reassign_set(&db, &set_id, &r.to_person_id).await?;
    state_of(&db).await
}

async fn add_session_exercise(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<AddSessionExerciseRequest>,
) -> AppResult<Json<StateResponse>> {
    session::add_session_exercise(&db, &id, &r.exercise_id, &r.assignment).await?;
    state_of(&db).await
}

// ---- session-exercise mutations ----

async fn skip_turn(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<SkipTurnRequest>,
) -> AppResult<Json<StateResponse>> {
    session::skip_turn(&db, &id, &r.person_id).await?;
    state_of(&db).await
}

async fn skip_exercise(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<SkipExerciseRequest>,
) -> AppResult<Json<StateResponse>> {
    session::skip_exercise(&db, &id, &r.person_id, r.reason).await?;
    state_of(&db).await
}

async fn substitute(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<SubstituteRequest>,
) -> AppResult<Json<StateResponse>> {
    session::substitute_exercise(&db, &id, &r.person_id, r.substitute_exercise_id).await?;
    state_of(&db).await
}

async fn person_status(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<PersonStatusRequest>,
) -> AppResult<Json<StateResponse>> {
    session::set_person_status(&db, &id, &r.person_id, &r.status).await?;
    state_of(&db).await
}

async fn logging_mode(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<LoggingModeRequest>,
) -> AppResult<Json<StateResponse>> {
    session::set_logging_mode(&db, &id, &r.mode).await?;
    state_of(&db).await
}

async fn active_row(
    State(db): Db,
    Path(id): Path<String>,
    Json(r): Json<ActiveRowRequest>,
) -> AppResult<Json<StateResponse>> {
    session::set_active_row(&db, &id, &r.person_id).await?;
    state_of(&db).await
}

// ---- admin ----

async fn reset_demo(State(db): Db) -> AppResult<Json<StateResponse>> {
    admin::reset_demo(&db).await?;
    state_of(&db).await
}

async fn restore_demo_routine(State(db): Db) -> AppResult<Json<StateResponse>> {
    admin::restore_demo_routine(&db).await?;
    state_of(&db).await
}

// ---- static frontend (embedded) ----

async fn static_handler(uri: Uri) -> Response {
    let path = uri.path().trim_start_matches('/');
    let path = if path.is_empty() { "index.html" } else { path };
    match Assets::get(path) {
        Some(content) => {
            let mime = mime_guess::from_path(path).first_or_octet_stream();
            ([(header::CONTENT_TYPE, mime.as_ref())], content.data).into_response()
        }
        // Unknown path -> serve index.html (SPA). HashRouter means this is rarely
        // needed, but it keeps deep links / refreshes working.
        None => match Assets::get("index.html") {
            Some(content) => ([(header::CONTENT_TYPE, "text/html")], content.data).into_response(),
            None => (StatusCode::NOT_FOUND, "Not found").into_response(),
        },
    }
}
