// Sync API for the offline-first iOS client, nested under `/api/v2`.
//
// The phone is the source of truth and owns every workout rule. This module is
// deliberately domain-agnostic: it stores each record's JSON per
// (entity, record_id), applies pushes last-writer-wins on the client's stamp,
// and serves a change feed ordered by a server-assigned `seq`. Every route
// requires `Authorization: Bearer $SYNC_TOKEN`; errors are JSON `{error}`.

use crate::entities::{sync_meta, sync_record};
use crate::legacy_import::{self, Conversion};
use crate::state::{build_state, StateResponse};
use axum::body::Bytes;
use axum::extract::rejection::{BytesRejection, JsonRejection, QueryRejection};
use axum::extract::{DefaultBodyLimit, Json, Query, Request, State};
use axum::http::{header, StatusCode};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::Router;
use sea_orm::sea_query::OnConflict;
use sea_orm::ActiveValue::Set;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, ConnectionTrait, DatabaseConnection, DbErr, EntityTrait,
    PaginatorTrait, QueryFilter, QueryOrder, QuerySelect, Statement, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::sync::Arc;

pub const MIN_TOKEN_LEN: usize = 32;
const MAX_PUSH_CHANGES: usize = 500;
const MAX_ID_LEN: usize = 128;
const MAX_ENTITY_LEN: usize = 41;
const DEFAULT_PULL_LIMIT: u64 = 500;
const MAX_PULL_LIMIT: u64 = 1000;
const IMPORT_BODY_LIMIT: usize = 32 << 20;
// Imported legacy records carry the lowest possible stamp, so any edit the phone
// makes afterwards wins regardless of clock skew, and the import output stays
// deterministic (see the golden fixture test).
pub const IMPORTED_UPDATED_AT: i64 = 1;

#[derive(Clone, Default)]
pub struct AppConfig {
    pub sync_token: Option<String>,
}

impl AppConfig {
    pub fn from_env() -> Self {
        Self::with_token(std::env::var("SYNC_TOKEN").ok())
    }

    // A blank token means sync is not configured. A short one is refused rather
    // than accepted: the API stays disabled (503) until a strong token is set.
    pub fn with_token(raw: Option<String>) -> Self {
        let token = raw.map(|t| t.trim().to_string()).filter(|t| !t.is_empty());
        let sync_token = match token {
            Some(t) if t.len() < MIN_TOKEN_LEN => {
                eprintln!(
                    "SYNC_TOKEN is shorter than {MIN_TOKEN_LEN} characters; the sync API stays disabled"
                );
                None
            }
            t => t,
        };
        Self { sync_token }
    }
}

// ---- errors ----

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    fn new(status: StatusCode, message: impl Into<String>) -> Self {
        Self {
            status,
            message: message.into(),
        }
    }

    fn bad_request(message: impl Into<String>) -> Self {
        Self::new(StatusCode::BAD_REQUEST, message)
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(json!({ "error": self.message }))).into_response()
    }
}

impl From<DbErr> for ApiError {
    fn from(e: DbErr) -> Self {
        Self::new(StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
    }
}

// axum's own rejections are plain text; the client expects JSON everywhere.
macro_rules! json_rejection {
    ($($rejection:ty),*) => {$(
        impl From<$rejection> for ApiError {
            fn from(r: $rejection) -> Self {
                Self::new(r.status(), r.body_text())
            }
        }
    )*};
}
json_rejection!(JsonRejection, QueryRejection, BytesRejection);

type ApiResult<T> = Result<Json<T>, ApiError>;

// ---- router ----

#[derive(Clone)]
struct SyncState {
    db: DatabaseConnection,
    token: Option<Arc<str>>,
}

pub fn router(db: DatabaseConnection, config: AppConfig) -> Router {
    let state = SyncState {
        db,
        token: config.sync_token.map(Arc::from),
    };
    Router::new()
        .route("/sync/status", get(status))
        .route("/sync/push", post(push))
        .route("/sync/pull", get(pull))
        .route(
            "/admin/import-legacy",
            post(import_legacy).layer(DefaultBodyLimit::max(IMPORT_BODY_LIMIT)),
        )
        // Without its own fallback a nested router defers to the outer SPA
        // fallback, which would answer unknown /api/v2 paths with index.html.
        .fallback(not_found)
        .layer(middleware::from_fn_with_state(state.clone(), require_token))
        .with_state(state)
}

async fn require_token(State(state): State<SyncState>, req: Request, next: Next) -> Response {
    let Some(expected) = state.token.as_deref() else {
        return ApiError::new(StatusCode::SERVICE_UNAVAILABLE, "SYNC NOT CONFIGURED")
            .into_response();
    };
    let provided = req
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .map(str::trim)
        .unwrap_or("");
    if !provided.is_empty() && constant_time_eq(provided.as_bytes(), expected.as_bytes()) {
        next.run(req).await
    } else {
        ApiError::new(StatusCode::UNAUTHORIZED, "TOKEN REJECTED").into_response()
    }
}

// Compares without short-circuiting on the first differing byte. The length is
// not secret (the minimum is public), so an early length mismatch is fine.
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

async fn not_found() -> ApiError {
    ApiError::new(StatusCode::NOT_FOUND, "NOT FOUND")
}

// ---- wire types ----

#[derive(Deserialize)]
pub struct PushRequest {
    pub changes: Vec<ChangeIn>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChangeIn {
    pub entity: String,
    pub id: String,
    pub updated_at: i64,
    #[serde(default)]
    pub deleted: bool,
    #[serde(default)]
    pub data: Option<Value>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StaleChange {
    pub entity: String,
    pub id: String,
    // The stamp the server holds; the client raises its clock above it.
    pub updated_at: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PushResponse {
    pub store_id: String,
    pub server_seq: i64,
    pub accepted: usize,
    pub stale: Vec<StaleChange>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ChangeOut {
    pub entity: String,
    pub id: String,
    pub updated_at: i64,
    pub deleted: bool,
    pub data: Value,
    pub seq: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PullResponse {
    pub store_id: String,
    pub changes: Vec<ChangeOut>,
    pub next_since: i64,
    pub has_more: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StatusResponse {
    pub store_id: String,
    pub server_seq: i64,
    pub records: u64,
    pub counts_by_entity: BTreeMap<String, u64>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportReport {
    pub store_id: String,
    pub counts_by_entity: BTreeMap<String, u64>,
    pub duplicates_dropped: u64,
    pub warnings: Vec<String>,
    pub active_session: Option<String>,
}

#[derive(Deserialize)]
struct PullQuery {
    #[serde(default)]
    since: i64,
    limit: Option<u64>,
}

#[derive(Deserialize)]
struct ImportQuery {
    #[serde(default)]
    replace: bool,
    source: Option<String>,
}

// ---- handlers ----

async fn status(State(s): State<SyncState>) -> ApiResult<StatusResponse> {
    let meta = load_meta(&s.db).await?;
    let counts_by_entity = counts_by_entity(&s.db).await?;
    Ok(Json(StatusResponse {
        store_id: meta.store_id,
        server_seq: meta.seq_counter,
        records: counts_by_entity.values().sum(),
        counts_by_entity,
    }))
}

async fn push(
    State(s): State<SyncState>,
    body: Result<Json<PushRequest>, JsonRejection>,
) -> ApiResult<PushResponse> {
    let Json(req) = body?;
    if req.changes.len() > MAX_PUSH_CHANGES {
        return Err(ApiError::bad_request(format!(
            "at most {MAX_PUSH_CHANGES} changes per push"
        )));
    }
    for change in &req.changes {
        validate(change)?;
    }
    // The pool holds one connection: everything below must go through `txn`.
    let txn = s.db.begin().await?;
    let resp = apply_push(&txn, req.changes).await?;
    txn.commit().await?;
    Ok(Json(resp))
}

async fn pull(
    State(s): State<SyncState>,
    query: Result<Query<PullQuery>, QueryRejection>,
) -> ApiResult<PullResponse> {
    let Query(q) = query?;
    let limit = q
        .limit
        .unwrap_or(DEFAULT_PULL_LIMIT)
        .clamp(1, MAX_PULL_LIMIT);
    let meta = load_meta(&s.db).await?;
    let mut rows = sync_record::Entity::find()
        .filter(sync_record::Column::Seq.gt(q.since))
        .order_by_asc(sync_record::Column::Seq)
        .limit(limit + 1)
        .all(&s.db)
        .await?;
    let has_more = rows.len() as u64 > limit;
    rows.truncate(limit as usize);
    let next_since = rows.last().map(|r| r.seq).unwrap_or(q.since);
    let changes = rows
        .into_iter()
        .map(|r| ChangeOut {
            data: stored_data(&r).unwrap_or(Value::Null),
            entity: r.entity,
            id: r.record_id,
            updated_at: r.updated_at,
            deleted: r.deleted,
            seq: r.seq,
        })
        .collect();
    Ok(Json(PullResponse {
        store_id: meta.store_id,
        changes,
        next_since,
        has_more,
    }))
}

async fn import_legacy(
    State(s): State<SyncState>,
    query: Result<Query<ImportQuery>, QueryRejection>,
    body: Result<Bytes, BytesRejection>,
) -> ApiResult<ImportReport> {
    let Query(q) = query?;
    let state: StateResponse = match q.source.as_deref() {
        // Read the legacy tables before opening the transaction (single
        // connection pool).
        Some("db") => build_state(&s.db).await?,
        Some(other) => return Err(ApiError::bad_request(format!("unknown source: {other}"))),
        None => serde_json::from_slice(&body?)
            .map_err(|e| ApiError::bad_request(format!("invalid legacy backup: {e}")))?,
    };
    let conversion = legacy_import::convert(&state);
    let txn = s.db.begin().await?;
    let report = import_records(&txn, conversion, q.replace).await?;
    txn.commit().await?;
    Ok(Json(report))
}

// ---- store operations (generic so they run inside a transaction) ----

fn validate(c: &ChangeIn) -> Result<(), ApiError> {
    let entity = c.entity.as_bytes();
    let entity_ok = !entity.is_empty()
        && entity.len() <= MAX_ENTITY_LEN
        && entity[0].is_ascii_lowercase()
        && entity.iter().all(|b| b.is_ascii_lowercase() || *b == b'_');
    if !entity_ok {
        return Err(ApiError::bad_request(format!(
            "invalid entity name: {:?}",
            c.entity
        )));
    }
    if c.id.is_empty() || c.id.len() > MAX_ID_LEN {
        return Err(ApiError::bad_request(format!(
            "record id must be 1-{MAX_ID_LEN} characters"
        )));
    }
    if !c.deleted && !matches!(c.data, Some(Value::Object(_))) {
        return Err(ApiError::bad_request(format!(
            "{}/{}: data must be a JSON object",
            c.entity, c.id
        )));
    }
    Ok(())
}

fn stored_data(r: &sync_record::Model) -> Option<Value> {
    r.data.as_deref().and_then(|d| serde_json::from_str(d).ok())
}

fn new_store_id() -> String {
    uuid::Uuid::new_v4().to_string()
}

async fn load_meta<C: ConnectionTrait>(conn: &C) -> Result<sync_meta::Model, DbErr> {
    if let Some(meta) = sync_meta::Entity::find_by_id(sync_meta::SINGLETON_ID)
        .one(conn)
        .await?
    {
        return Ok(meta);
    }
    sync_meta::ActiveModel {
        id: Set(sync_meta::SINGLETON_ID.into()),
        store_id: Set(new_store_id()),
        seq_counter: Set(0),
    }
    .insert(conn)
    .await
}

async fn save_meta<C: ConnectionTrait>(
    conn: &C,
    meta: &sync_meta::Model,
    store_id: String,
    seq_counter: i64,
) -> Result<(), DbErr> {
    let mut am: sync_meta::ActiveModel = meta.clone().into();
    am.store_id = Set(store_id);
    am.seq_counter = Set(seq_counter);
    am.update(conn).await?;
    Ok(())
}

async fn upsert_record<C: ConnectionTrait>(
    conn: &C,
    record: sync_record::Model,
) -> Result<(), DbErr> {
    use sync_record::Column;
    sync_record::Entity::insert(sync_record::ActiveModel::from(record))
        .on_conflict(
            OnConflict::columns([Column::Entity, Column::RecordId])
                .update_columns([
                    Column::Data,
                    Column::Deleted,
                    Column::UpdatedAt,
                    Column::Seq,
                ])
                .to_owned(),
        )
        .exec(conn)
        .await?;
    Ok(())
}

pub async fn apply_push<C: ConnectionTrait>(
    conn: &C,
    changes: Vec<ChangeIn>,
) -> Result<PushResponse, DbErr> {
    let meta = load_meta(conn).await?;
    let mut seq = meta.seq_counter;
    let mut accepted = 0;
    let mut stale = Vec::new();

    for change in changes {
        let data = if change.deleted { None } else { change.data };
        let existing = sync_record::Entity::find_by_id((change.entity.clone(), change.id.clone()))
            .one(conn)
            .await?;
        if let Some(e) = &existing {
            if e.updated_at > change.updated_at {
                stale.push(StaleChange {
                    entity: change.entity,
                    id: change.id,
                    updated_at: e.updated_at,
                });
                continue;
            }
            // A retried push: already applied, so don't advance the feed.
            if e.updated_at == change.updated_at
                && e.deleted == change.deleted
                && stored_data(e) == data
            {
                accepted += 1;
                continue;
            }
        }
        seq += 1;
        upsert_record(
            conn,
            sync_record::Model {
                entity: change.entity,
                record_id: change.id,
                data: data.map(|d| d.to_string()),
                deleted: change.deleted,
                updated_at: change.updated_at,
                seq,
            },
        )
        .await?;
        accepted += 1;
    }

    if seq != meta.seq_counter {
        save_meta(conn, &meta, meta.store_id.clone(), seq).await?;
    }
    Ok(PushResponse {
        store_id: meta.store_id,
        server_seq: seq,
        accepted,
        stale,
    })
}

pub async fn counts_by_entity<C: ConnectionTrait>(
    conn: &C,
) -> Result<BTreeMap<String, u64>, DbErr> {
    let rows = conn
        .query_all(Statement::from_string(
            conn.get_database_backend(),
            "SELECT entity, COUNT(*) AS n FROM sync_record WHERE deleted = 0 GROUP BY entity",
        ))
        .await?;
    rows.iter()
        .map(|row| {
            let entity: String = row.try_get("", "entity")?;
            let n: i64 = row.try_get("", "n")?;
            Ok((entity, n as u64))
        })
        .collect()
}

async fn import_records<C: ConnectionTrait>(
    conn: &C,
    conversion: Conversion,
    replace: bool,
) -> Result<ImportReport, ApiError> {
    let meta = load_meta(conn).await?;
    let mut store_id = meta.store_id.clone();
    if replace {
        sync_record::Entity::delete_many().exec(conn).await?;
        // A new identity tells a phone that already synced with this store that
        // its records are gone, so it re-uploads them.
        store_id = new_store_id();
    } else if sync_record::Entity::find().count(conn).await? > 0 {
        return Err(ApiError::new(
            StatusCode::CONFLICT,
            "SYNC STORE IS NOT EMPTY — PASS replace=true TO OVERWRITE IT",
        ));
    }

    let mut seq = meta.seq_counter;
    let rows: Vec<sync_record::ActiveModel> = conversion
        .records
        .into_iter()
        .map(|r| {
            seq += 1;
            sync_record::ActiveModel::from(sync_record::Model {
                entity: r.entity.to_string(),
                record_id: r.id,
                data: Some(r.data.to_string()),
                deleted: false,
                updated_at: IMPORTED_UPDATED_AT,
                seq,
            })
        })
        .collect();
    for chunk in rows.chunks(500) {
        sync_record::Entity::insert_many(chunk.to_vec())
            .exec(conn)
            .await?;
    }
    save_meta(conn, &meta, store_id.clone(), seq).await?;

    Ok(ImportReport {
        store_id,
        counts_by_entity: counts_by_entity(conn).await?,
        duplicates_dropped: conversion.duplicates_dropped,
        warnings: conversion.warnings,
        active_session: conversion.active_session,
    })
}
