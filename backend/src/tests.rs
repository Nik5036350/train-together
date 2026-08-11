use crate::entities::*;
use crate::{db, handlers, services};
use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Router;
use http_body_util::BodyExt;
use sea_orm::{ColumnTrait, DatabaseConnection, EntityTrait, PaginatorTrait, QueryFilter};
use serde_json::{json, Value};
use tower::util::ServiceExt;

async fn app() -> Router {
    app_with_db().await.0
}

// Same harness, but hands back the connection so a test can assert on rows the
// aggregate response doesn't expose (e.g. cascade deletes).
async fn app_with_db() -> (Router, DatabaseConnection) {
    let db = db::connect("sqlite::memory:").await.unwrap();
    db::init_schema(&db).await.unwrap();
    services::seed::reset_to_seed(&db).await.unwrap();
    (handlers::router(db.clone()), db)
}

async fn call(app: &Router, method: &str, uri: &str, body: Option<Value>) -> Value {
    let builder = Request::builder().method(method).uri(uri);
    let req = match body {
        Some(j) => builder
            .header("content-type", "application/json")
            .body(Body::from(j.to_string()))
            .unwrap(),
        None => builder.body(Body::empty()).unwrap(),
    };
    let resp = app.clone().oneshot(req).await.unwrap();
    assert!(
        resp.status().is_success(),
        "{} {} -> {}",
        method,
        uri,
        resp.status()
    );
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap()
}

// `call` asserts 2xx; use this when the rejection itself is what's under test.
async fn call_status(app: &Router, method: &str, uri: &str) -> StatusCode {
    let req = Request::builder()
        .method(method)
        .uri(uri)
        .body(Body::empty())
        .unwrap();
    app.clone().oneshot(req).await.unwrap().status()
}

#[tokio::test]
async fn get_state_returns_seeded_shape() {
    let app = app().await;
    let s = call(&app, "GET", "/api/state", None).await;
    assert_eq!(s["people"].as_array().unwrap().len(), 2);
    assert_eq!(s["exercises"].as_object().unwrap().len(), 8);
    assert_eq!(s["templates"]["t_push"]["name"], "Push Day");
    assert_eq!(s["history"].as_array().unwrap().len(), 1);
    assert_eq!(s["history"][0]["sets"].as_array().unwrap().len(), 24);
    assert!(s["session"].is_null());
    assert_eq!(s["version"], 3);
}

#[tokio::test]
async fn logging_switches_active_row_and_increments_set_index() {
    let app = app().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"],"loggingStyle":"alternate"})),
    )
    .await;
    let se_id = s["session"]["exercises"][0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    let session_id = s["session"]["id"].as_str().unwrap().to_string();
    assert_eq!(s["session"]["exercises"][0]["activePersonId"], "p_alex");

    // Alex logs -> active flips to Maria, set index 0, 150s bench timer.
    let s = call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/sets"),
        Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":80,"reps":8}})),
    )
    .await;
    let se = &s["session"]["exercises"][0];
    assert_eq!(se["activePersonId"], "p_maria");
    assert_eq!(se["perPerson"]["p_alex"]["status"], "logged");
    let alex_sets: Vec<&Value> = s["session"]["sets"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|st| st["personId"] == "p_alex")
        .collect();
    assert_eq!(alex_sets.len(), 1);
    assert_eq!(alex_sets[0]["setIndex"], 0);
    assert_eq!(s["session"]["timers"]["p_alex"]["durationSeconds"], 150);

    // Second Alex set -> index 1.
    let s = call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/sets"),
        Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":80,"reps":7}})),
    )
    .await;
    let mut idx: Vec<i64> = s["session"]["sets"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|st| st["personId"] == "p_alex")
        .map(|st| st["setIndex"].as_i64().unwrap())
        .collect();
    idx.sort();
    assert_eq!(idx, vec![0, 1]);
}

#[tokio::test]
async fn deleting_a_set_renumbers_remaining() {
    let app = app().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"],"loggingStyle":"independent"})),
    )
    .await;
    let se_id = s["session"]["exercises"][0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    let session_id = s["session"]["id"].as_str().unwrap().to_string();

    for w in [80, 81, 82] {
        call(
            &app,
            "POST",
            &format!("/api/sessions/{session_id}/sets"),
            Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":w,"reps":8}})),
        )
        .await;
    }
    let s = call(&app, "GET", "/api/state", None).await;
    let mid = s["session"]["sets"]
        .as_array()
        .unwrap()
        .iter()
        .find(|st| st["personId"] == "p_alex" && st["setIndex"] == 1)
        .unwrap()["id"]
        .as_str()
        .unwrap()
        .to_string();

    let s = call(
        &app,
        "DELETE",
        &format!("/api/sessions/{session_id}/sets/{mid}"),
        None,
    )
    .await;
    let mut idx: Vec<i64> = s["session"]["sets"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|st| st["personId"] == "p_alex")
        .map(|st| st["setIndex"].as_i64().unwrap())
        .collect();
    idx.sort();
    assert_eq!(idx, vec![0, 1]);
}

#[tokio::test]
async fn variant_selector_tags_sets_and_defaults_to_normal() {
    let app = app().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"],"loggingStyle":"independent"})),
    )
    .await;
    let se_id = s["session"]["exercises"][0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    let session_id = s["session"]["id"].as_str().unwrap().to_string();
    assert_eq!(s["session"]["exercises"][0]["variant"], "normal");

    // A set logged before switching carries the default variant.
    let s = call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/sets"),
        Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":80,"reps":8}})),
    )
    .await;
    let alex_sets = |s: &Value| -> Vec<Value> {
        s["session"]["sets"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|st| st["personId"] == "p_alex")
            .cloned()
            .collect()
    };
    assert_eq!(alex_sets(&s)[0]["variant"], "normal");

    // Switch the card to highReps -> subsequent sets are tagged with it while
    // earlier sets keep theirs, and setIndex stays one global sequence.
    let s = call(
        &app,
        "PATCH",
        &format!("/api/session-exercises/{se_id}/variant"),
        Some(json!({"variant":"highReps"})),
    )
    .await;
    assert_eq!(s["session"]["exercises"][0]["variant"], "highReps");
    let s = call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/sets"),
        Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":50,"reps":15}})),
    )
    .await;
    let sets = alex_sets(&s);
    assert_eq!(sets.len(), 2);
    assert_eq!(sets[0]["variant"], "normal");
    assert_eq!(sets[1]["variant"], "highReps");
    assert_eq!(sets[0]["setIndex"], 0);
    assert_eq!(sets[1]["setIndex"], 1);

    // An explicit variant in the log request overrides the card's selection.
    let s = call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/sets"),
        Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":100,"reps":2}, "variant":"maxWeight"})),
    )
    .await;
    assert_eq!(alex_sets(&s)[2]["variant"], "maxWeight");
}

#[tokio::test]
async fn import_backup_without_variant_defaults_to_normal() {
    fn strip_variant(v: &mut Value) {
        match v {
            Value::Object(map) => {
                map.remove("variant");
                map.values_mut().for_each(strip_variant);
            }
            Value::Array(arr) => arr.iter_mut().for_each(strip_variant),
            _ => {}
        }
    }

    let app = app().await;
    let mut backup = call(&app, "GET", "/api/state", None).await;
    strip_variant(&mut backup); // simulate a pre-variant backup
    let s = call(&app, "PUT", "/api/state", Some(backup)).await;
    for st in s["history"][0]["sets"].as_array().unwrap() {
        assert_eq!(st["variant"], "normal");
    }
}

#[tokio::test]
async fn finishing_moves_session_to_history() {
    let app = app().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"]})),
    )
    .await;
    let session_id = s["session"]["id"].as_str().unwrap().to_string();

    let s = call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/finish"),
        None,
    )
    .await;
    assert!(s["session"].is_null());
    assert_eq!(s["history"].as_array().unwrap().len(), 2);
    let newest = s["history"]
        .as_array()
        .unwrap()
        .iter()
        .find(|h| h["id"] == session_id.as_str())
        .unwrap();
    assert_eq!(newest["status"], "finished");
    assert!(newest["endTime"].is_i64());
}

#[tokio::test]
async fn deleting_a_finished_workout_removes_it_and_its_sets() {
    let (app, db) = app_with_db().await;
    let s = call(&app, "GET", "/api/state", None).await;
    assert_eq!(s["history"].as_array().unwrap().len(), 1);
    assert_eq!(s["history"][0]["id"], "sess_prev");

    let s = call(&app, "DELETE", "/api/sessions/sess_prev", None).await;
    assert!(s["history"].as_array().unwrap().is_empty());
    // Untouched by the cascade: the library and routines stand on their own.
    assert_eq!(s["exercises"].as_object().unwrap().len(), 8);
    assert_eq!(s["templates"]["t_push"]["name"], "Push Day");

    // The children the aggregate no longer surfaces are gone from the DB too.
    let sets = set_entry::Entity::find()
        .filter(set_entry::Column::SessionId.eq("sess_prev"))
        .count(&db)
        .await
        .unwrap();
    assert_eq!(sets, 0);
    let participants = session_participant::Entity::find()
        .filter(session_participant::Column::SessionId.eq("sess_prev"))
        .count(&db)
        .await
        .unwrap();
    assert_eq!(participants, 0);
    let exercises = session_exercise::Entity::find()
        .filter(session_exercise::Column::SessionId.eq("sess_prev"))
        .count(&db)
        .await
        .unwrap();
    assert_eq!(exercises, 0);
}

#[tokio::test]
async fn deleting_a_finished_workout_cascades_session_exercise_people() {
    // The seeded history session has no session_exercise rows, so drive the
    // cascade with a session that actually built the full graph.
    let (app, db) = app_with_db().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"]})),
    )
    .await;
    let session_id = s["session"]["id"].as_str().unwrap().to_string();
    let se_id = s["session"]["exercises"][0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/sets"),
        Some(json!({"sessionExerciseId": se_id, "personId":"p_alex", "values":{"weight":80,"reps":8}})),
    )
    .await;
    call(
        &app,
        "POST",
        &format!("/api/sessions/{session_id}/finish"),
        None,
    )
    .await;

    let s = call(&app, "DELETE", &format!("/api/sessions/{session_id}"), None).await;
    assert_eq!(s["history"].as_array().unwrap().len(), 1);
    assert_eq!(s["history"][0]["id"], "sess_prev");

    let sep = session_exercise_person::Entity::find()
        .filter(session_exercise_person::Column::SessionExerciseId.eq(se_id))
        .count(&db)
        .await
        .unwrap();
    assert_eq!(sep, 0);
}

#[tokio::test]
async fn deleting_an_active_session_is_rejected() {
    let app = app().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"]})),
    )
    .await;
    let session_id = s["session"]["id"].as_str().unwrap().to_string();

    let status = call_status(&app, "DELETE", &format!("/api/sessions/{session_id}")).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    // Still live and untouched.
    let s = call(&app, "GET", "/api/state", None).await;
    assert_eq!(s["session"]["id"], session_id.as_str());
}

#[tokio::test]
async fn deleting_an_unknown_workout_is_not_found() {
    let app = app().await;
    let status = call_status(&app, "DELETE", "/api/sessions/sess_nope").await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}
