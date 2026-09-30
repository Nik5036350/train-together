use crate::entities::*;
use crate::sync::AppConfig;
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
    (handlers::router(db.clone(), test_config()), db)
}

const TOKEN: &str = "test-sync-token-0123456789abcdefghij";

fn test_config() -> AppConfig {
    AppConfig::with_token(Some(TOKEN.to_string()))
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

// ---- sync API (/api/v2) ----

// Sends a v2 request; every v2 response (including errors) is JSON.
async fn v2(
    app: &Router,
    method: &str,
    uri: &str,
    token: Option<&str>,
    body: Option<Value>,
) -> (StatusCode, Value) {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(t) = token {
        builder = builder.header("authorization", format!("Bearer {t}"));
    }
    let req = match body {
        Some(j) => builder
            .header("content-type", "application/json")
            .body(Body::from(j.to_string()))
            .unwrap(),
        None => builder.body(Body::empty()).unwrap(),
    };
    let resp = app.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    let json = serde_json::from_slice(&bytes)
        .unwrap_or_else(|_| panic!("{method} {uri} -> {status}: body is not JSON"));
    (status, json)
}

async fn authed(app: &Router, method: &str, uri: &str, body: Option<Value>) -> Value {
    let (status, json) = v2(app, method, uri, Some(TOKEN), body).await;
    assert!(status.is_success(), "{method} {uri} -> {status}: {json}");
    json
}

fn change(entity: &str, id: &str, updated_at: i64, data: Value) -> Value {
    json!({"entity": entity, "id": id, "updatedAt": updated_at, "deleted": false, "data": data})
}

async fn pull_all(app: &Router) -> Vec<Value> {
    let r = authed(app, "GET", "/api/v2/sync/pull?since=0&limit=1000", None).await;
    assert_eq!(r["hasMore"], false);
    r["changes"].as_array().unwrap().clone()
}

fn find<'a>(changes: &'a [Value], entity: &str, id: &str) -> Option<&'a Value> {
    changes
        .iter()
        .find(|c| c["entity"] == entity && c["id"] == id)
}

#[tokio::test]
async fn sync_is_disabled_without_a_strong_token() {
    let db = db::connect("sqlite::memory:").await.unwrap();
    db::init_schema(&db).await.unwrap();
    for config in [
        AppConfig::default(),
        AppConfig::with_token(Some("   ".into())),
        AppConfig::with_token(Some("too-short".into())),
    ] {
        assert!(config.sync_token.is_none());
        let app = handlers::router(db.clone(), config);
        let (status, body) = v2(&app, "GET", "/api/v2/sync/status", Some("too-short"), None).await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(body["error"], "SYNC NOT CONFIGURED");
    }
}

#[tokio::test]
async fn sync_rejects_missing_or_wrong_token() {
    let app = app().await;
    let (status, body) = v2(&app, "GET", "/api/v2/sync/status", None, None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"], "TOKEN REJECTED");
    let wrong = "test-sync-token-0123456789abcdefghiX";
    let (status, _) = v2(&app, "GET", "/api/v2/sync/status", Some(wrong), None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    let (status, _) = v2(&app, "GET", "/api/v2/sync/status", Some(TOKEN), None).await;
    assert_eq!(status, StatusCode::OK);
}

#[tokio::test]
async fn unknown_v2_path_is_a_json_404_not_the_spa() {
    let app = app().await;
    let (status, body) = v2(&app, "GET", "/api/v2/nope", Some(TOKEN), None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"], "NOT FOUND");
}

#[tokio::test]
async fn push_then_pull_round_trips_records() {
    let app = app().await;
    let r = authed(
        &app,
        "POST",
        "/api/v2/sync/push",
        Some(json!({"changes": [
            change("person", "p1", 10, json!({"id": "p1", "name": "Anna"})),
            change("set_entry", "s1", 11, json!({"id": "s1", "weight": 42.5})),
        ]})),
    )
    .await;
    assert_eq!(r["accepted"], 2);
    assert_eq!(r["serverSeq"], 2);
    assert_eq!(r["stale"].as_array().unwrap().len(), 0);

    let changes = pull_all(&app).await;
    assert_eq!(changes.len(), 2);
    assert_eq!(changes[0]["seq"], 1);
    assert_eq!(changes[0]["data"]["name"], "Anna");
    assert_eq!(changes[1]["seq"], 2);
    assert_eq!(changes[1]["data"]["weight"], 42.5);
    assert_eq!(changes[1]["updatedAt"], 11);

    let status = authed(&app, "GET", "/api/v2/sync/status", None).await;
    assert_eq!(status["records"], 2);
    assert_eq!(status["serverSeq"], 2);
    assert_eq!(status["countsByEntity"]["person"], 1);
    assert_eq!(status["storeId"], r["storeId"]);
}

#[tokio::test]
async fn push_is_last_writer_wins_and_idempotent() {
    let app = app().await;
    let push = |changes: Value| {
        let app = app.clone();
        async move {
            authed(
                &app,
                "POST",
                "/api/v2/sync/push",
                Some(json!({"changes": changes})),
            )
            .await
        }
    };
    push(json!([change(
        "person",
        "p1",
        10,
        json!({"id": "p1", "name": "v10"})
    )]))
    .await;

    // Older stamp: reported stale with the stamp the server holds.
    let r = push(json!([change(
        "person",
        "p1",
        5,
        json!({"id": "p1", "name": "v5"})
    )]))
    .await;
    assert_eq!(r["accepted"], 0);
    assert_eq!(r["stale"][0]["id"], "p1");
    assert_eq!(r["stale"][0]["updatedAt"], 10);

    // Retried identical push: accepted, but the feed doesn't advance.
    let r = push(json!([change(
        "person",
        "p1",
        10,
        json!({"id": "p1", "name": "v10"})
    )]))
    .await;
    assert_eq!(r["accepted"], 1);
    assert_eq!(r["serverSeq"], 1);

    // Newer stamp wins and moves the record to a new seq.
    let r = push(json!([change(
        "person",
        "p1",
        11,
        json!({"id": "p1", "name": "v11"})
    )]))
    .await;
    assert_eq!(r["serverSeq"], 2);
    let changes = pull_all(&app).await;
    assert_eq!(changes.len(), 1);
    assert_eq!(changes[0]["data"]["name"], "v11");
    assert_eq!(changes[0]["seq"], 2);
}

#[tokio::test]
async fn tombstones_are_pulled_and_not_counted() {
    let app = app().await;
    authed(
        &app,
        "POST",
        "/api/v2/sync/push",
        Some(json!({"changes": [change("set_entry", "s1", 10, json!({"id": "s1"}))]})),
    )
    .await;
    authed(
        &app,
        "POST",
        "/api/v2/sync/push",
        Some(json!({"changes": [{"entity": "set_entry", "id": "s1", "updatedAt": 20, "deleted": true}]})),
    )
    .await;
    let changes = pull_all(&app).await;
    assert_eq!(changes.len(), 1);
    assert_eq!(changes[0]["deleted"], true);
    assert!(changes[0]["data"].is_null());
    let status = authed(&app, "GET", "/api/v2/sync/status", None).await;
    assert_eq!(status["records"], 0);
}

#[tokio::test]
async fn pull_pages_through_the_change_feed() {
    let app = app().await;
    let changes: Vec<Value> = (1..=5)
        .map(|i| {
            change(
                "exercise",
                &format!("e{i}"),
                i,
                json!({"id": format!("e{i}")}),
            )
        })
        .collect();
    authed(
        &app,
        "POST",
        "/api/v2/sync/push",
        Some(json!({"changes": changes})),
    )
    .await;

    let mut since = 0;
    let mut ids = Vec::new();
    loop {
        let page = authed(
            &app,
            "GET",
            &format!("/api/v2/sync/pull?since={since}&limit=2"),
            None,
        )
        .await;
        for c in page["changes"].as_array().unwrap() {
            ids.push(c["id"].as_str().unwrap().to_string());
        }
        since = page["nextSince"].as_i64().unwrap();
        if page["hasMore"] == false {
            break;
        }
    }
    assert_eq!(ids, vec!["e1", "e2", "e3", "e4", "e5"]);
    assert_eq!(since, 5);
}

#[tokio::test]
async fn push_rejects_invalid_changes_with_json_errors() {
    let app = app().await;
    for bad in [
        json!({"changes": [change("Bad-Entity", "x", 1, json!({}))]}),
        json!({"changes": [change("person", "", 1, json!({}))]}),
        json!({"changes": [change("person", "x", 1, json!([1, 2]))]}),
        json!({"changes": [{"entity": "person", "id": "x", "updatedAt": 1}]}),
    ] {
        let (status, body) = v2(&app, "POST", "/api/v2/sync/push", Some(TOKEN), Some(bad)).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert!(body["error"].is_string());
    }
    // Malformed body: axum's rejection, rewritten as JSON.
    let (status, body) = v2(
        &app,
        "POST",
        "/api/v2/sync/push",
        Some(TOKEN),
        Some(json!({"changes": "nope"})),
    )
    .await;
    assert!(status.is_client_error());
    assert!(body["error"].is_string());
}

#[tokio::test]
async fn store_id_survives_a_new_router_over_the_same_db() {
    let (app, db) = app_with_db().await;
    let first = authed(&app, "GET", "/api/v2/sync/status", None).await["storeId"].clone();
    let again = handlers::router(db, test_config());
    let second = authed(&again, "GET", "/api/v2/sync/status", None).await["storeId"].clone();
    assert!(first.is_string());
    assert_eq!(first, second);
}

// ---- legacy import ----

#[tokio::test]
async fn legacy_import_from_db_converts_the_seed() {
    let app = app().await;
    let r = authed(&app, "POST", "/api/v2/admin/import-legacy?source=db", None).await;
    let counts = &r["countsByEntity"];
    assert_eq!(counts["settings"], 1);
    assert_eq!(counts["person"], 2);
    assert_eq!(counts["exercise"], 8);
    assert_eq!(counts["person_exercise_profile"], 8);
    assert_eq!(counts["template"], 1);
    assert_eq!(counts["template_exercise"], 5);
    assert_eq!(counts["workout_session"], 1);
    assert_eq!(counts["session_participant"], 2);
    assert_eq!(counts["set_entry"], 24);
    assert_eq!(r["duplicatesDropped"], 0);
    assert_eq!(r["warnings"].as_array().unwrap().len(), 0);
    assert!(r["activeSession"].is_null());

    let changes = pull_all(&app).await;
    assert_eq!(changes.len(), 52);
    assert!(changes.iter().all(|c| c["updatedAt"] == 1));
    // Deterministic ids for rows the legacy schema generated randomly.
    let profile = find(&changes, "person_exercise_profile", "prof_p_alex__ex_bench").unwrap();
    assert_eq!(profile["data"]["restSeconds"], 150);
    let tex = find(&changes, "template_exercise", "tex_t_push_2").unwrap();
    assert_eq!(tex["data"]["exerciseId"], "ex_cablefly");
    assert_eq!(tex["data"]["assignment"], "partner");
    assert!(find(&changes, "session_participant", "spart_sess_prev_p_maria").is_some());
    // Legacy colors resolve onto brand identities.
    assert_eq!(
        find(&changes, "person", "p_alex").unwrap()["data"]["color"],
        "steel"
    );
    assert_eq!(
        find(&changes, "person", "p_maria").unwrap()["data"]["color"],
        "red"
    );
    let set = find(&changes, "set_entry", "h1_ex_bench_p_alex_0").unwrap();
    assert_eq!(set["data"]["weight"], 80.0);
    assert!(set["data"]["sessionExerciseId"].is_null());
}

#[tokio::test]
async fn legacy_import_refuses_a_non_empty_store_unless_replacing() {
    let app = app().await;
    let first = authed(&app, "POST", "/api/v2/admin/import-legacy?source=db", None).await;
    let (status, body) = v2(
        &app,
        "POST",
        "/api/v2/admin/import-legacy?source=db",
        Some(TOKEN),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(body["error"].is_string());

    let replaced = authed(
        &app,
        "POST",
        "/api/v2/admin/import-legacy?source=db&replace=true",
        None,
    )
    .await;
    assert_ne!(replaced["storeId"], first["storeId"]);
    let status = authed(&app, "GET", "/api/v2/sync/status", None).await;
    assert_eq!(status["storeId"], replaced["storeId"]);
    assert_eq!(status["records"], 52);
    // Seqs keep increasing across a replace.
    assert_eq!(status["serverSeq"], 104);
}

#[tokio::test]
async fn legacy_import_from_a_backup_body_tolerates_old_shapes() {
    let app = app().await;
    let mut backup = call(&app, "GET", "/api/state", None).await;
    // Older backups had no `variant`; removed-then-added routine exercises left
    // duplicate `order` values; a set may reference a person that is gone.
    for s in backup["history"].as_array_mut().unwrap() {
        for st in s["sets"].as_array_mut().unwrap() {
            st.as_object_mut().unwrap().remove("variant");
        }
        s["sets"].as_array_mut().unwrap().push(json!({
            "id": "ghost_set", "sessionExerciseId": "se_missing", "exerciseId": "ex_bench",
            "personId": "p_ghost", "setIndex": 0, "weight": 20.0, "reps": 5,
            "duration": null, "setType": "working", "timestamp": null, "note": "  "
        }));
    }
    let orders = [0, 2, 2, 3, 3];
    for (te, order) in backup["templates"]["t_push"]["exercises"]
        .as_array_mut()
        .unwrap()
        .iter_mut()
        .zip(orders)
    {
        te["order"] = json!(order);
    }

    let r = authed(&app, "POST", "/api/v2/admin/import-legacy", Some(backup)).await;
    assert_eq!(r["countsByEntity"]["template_exercise"], 5);
    assert_eq!(r["countsByEntity"]["set_entry"], 25);
    let warnings: Vec<&str> = r["warnings"]
        .as_array()
        .unwrap()
        .iter()
        .map(|w| w.as_str().unwrap())
        .collect();
    assert!(warnings.iter().any(|w| w.contains("p_ghost")));
    assert!(warnings.iter().any(|w| w.contains("se_missing")));

    let changes = pull_all(&app).await;
    let order_indexes: Vec<i64> = (0..5)
        .map(|i| {
            find(&changes, "template_exercise", &format!("tex_t_push_{i}")).unwrap()["data"]
                ["orderIndex"]
                .as_i64()
                .unwrap()
        })
        .collect();
    assert_eq!(order_indexes, vec![0, 1, 2, 3, 4]);
    let ghost = find(&changes, "set_entry", "ghost_set").unwrap();
    assert!(ghost["data"]["sessionExerciseId"].is_null());
    assert!(ghost["data"]["note"].is_null());
    assert_eq!(ghost["data"]["variant"], "normal");
}

#[tokio::test]
async fn legacy_import_keeps_an_active_session_without_timers() {
    let app = app().await;
    let s = call(
        &app,
        "POST",
        "/api/sessions",
        Some(json!({"templateId":"t_push","participantIds":["p_alex","p_maria"],"loggingStyle":"turns"})),
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

    let r = authed(&app, "POST", "/api/v2/admin/import-legacy?source=db", None).await;
    assert_eq!(r["activeSession"], session_id.as_str());
    let changes = pull_all(&app).await;
    let session = find(&changes, "workout_session", &session_id).unwrap();
    assert_eq!(session["data"]["status"], "active");
    let sep = find(
        &changes,
        "session_exercise_person",
        &format!("sep_{se_id}_p_alex"),
    )
    .unwrap();
    assert_eq!(sep["data"]["status"], "logged");
    let se = find(&changes, "session_exercise", &se_id).unwrap();
    assert_eq!(se["data"]["activePersonId"], "p_maria");
    assert!(changes.iter().all(|c| c["entity"] != "rest_timer"));
}

// The importer output for the seed is the sync contract the iOS app decodes
// (ios/Packages/TrainTogetherKit tests load the same file). Regenerate with
// `UPDATE_FIXTURES=1 cargo test legacy_import_matches_golden_fixture`.
#[tokio::test]
async fn legacy_import_matches_golden_fixture() {
    let app = app().await;
    authed(&app, "POST", "/api/v2/admin/import-legacy?source=db", None).await;
    let changes = Value::Array(pull_all(&app).await);
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/fixtures/seed-records.json"
    );
    if std::env::var("UPDATE_FIXTURES").is_ok() {
        std::fs::create_dir_all(std::path::Path::new(path).parent().unwrap()).unwrap();
        std::fs::write(path, serde_json::to_string_pretty(&changes).unwrap() + "\n").unwrap();
    }
    let golden: Value = serde_json::from_str(
        &std::fs::read_to_string(path).expect("fixture missing; run with UPDATE_FIXTURES=1"),
    )
    .unwrap();
    assert_eq!(
        changes, golden,
        "importer output changed; if intended, regenerate with UPDATE_FIXTURES=1 and update the iOS decoders"
    );
}
