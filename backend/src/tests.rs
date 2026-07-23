use crate::{db, handlers, services};
use axum::body::Body;
use axum::http::Request;
use axum::Router;
use http_body_util::BodyExt;
use serde_json::{json, Value};
use tower::util::ServiceExt;

async fn app() -> Router {
    let db = db::connect("sqlite::memory:").await.unwrap();
    db::init_schema(&db).await.unwrap();
    services::seed::reset_to_seed(&db).await.unwrap();
    handlers::router(db)
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
