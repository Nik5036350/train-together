use sea_orm::{ConnectOptions, Database, DatabaseConnection, DbErr};

// Single connection keeps SQLite access serialized (no lock contention) — fine
// for this single-shared-dataset app. Note this is only sufficient because the
// deployment guarantees one process; see docs/adr/0002.
//
// The schema is not created here. It belongs to the migration runner in
// migrate.rs, which must have finished before this is called.
pub async fn connect(url: &str) -> Result<DatabaseConnection, DbErr> {
    let mut opt = ConnectOptions::new(url.to_owned());
    opt.max_connections(1).min_connections(1);
    Database::connect(opt).await
}
