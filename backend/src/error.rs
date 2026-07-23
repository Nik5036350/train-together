use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use sea_orm::DbErr;

// Maps to the same HTTP semantics the Kotlin backend used (NotFoundException ->
// 404); DB and other failures surface as 500 / 400.
#[derive(Debug)]
pub enum AppError {
    NotFound(String),
    #[allow(dead_code)] // reserved for validation failures
    BadRequest(String),
    Db(DbErr),
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AppError::NotFound(m) => write!(f, "{m}"),
            AppError::BadRequest(m) => write!(f, "{m}"),
            AppError::Db(e) => write!(f, "{e}"),
        }
    }
}

impl From<DbErr> for AppError {
    fn from(e: DbErr) -> Self {
        AppError::Db(e)
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, msg) = match self {
            AppError::NotFound(m) => (StatusCode::NOT_FOUND, m),
            AppError::BadRequest(m) => (StatusCode::BAD_REQUEST, m),
            AppError::Db(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()),
        };
        (status, msg).into_response()
    }
}

pub type AppResult<T> = Result<T, AppError>;
