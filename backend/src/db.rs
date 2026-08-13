use crate::entities::*;
use sea_orm::sea_query::TableCreateStatement;
use sea_orm::{
    ConnectOptions, ConnectionTrait, Database, DatabaseConnection, DbBackend, DbErr, Schema,
};

// Single connection keeps SQLite access serialized (no lock contention) — fine
// for this single-shared-dataset app.
pub async fn connect(url: &str) -> Result<DatabaseConnection, DbErr> {
    let mut opt = ConnectOptions::new(url.to_owned());
    opt.max_connections(1).min_connections(1);
    Database::connect(opt).await
}

pub async fn init_schema(db: &DatabaseConnection) -> Result<(), DbErr> {
    let schema = Schema::new(DbBackend::Sqlite);
    macro_rules! create {
        ($ent:expr) => {{
            let stmt: TableCreateStatement = schema
                .create_table_from_entity($ent)
                .if_not_exists()
                .to_owned();
            db.execute(&stmt).await?;
        }};
    }
    create!(person::Entity);
    create!(exercise::Entity);
    create!(person_exercise_profile::Entity);
    create!(template::Entity);
    create!(template_exercise::Entity);
    create!(app_settings::Entity);
    create!(workout_session::Entity);
    create!(session_participant::Entity);
    create!(session_exercise::Entity);
    create!(session_exercise_person::Entity);
    create!(set_entry::Entity);
    create!(rest_timer::Entity);

    // Columns added after the first release. `if_not_exists()` never alters an
    // existing table, so bring old database files up to date here; the constant
    // DEFAULT backfills existing rows. "duplicate column name" errors mean the
    // column is already there and are safe to ignore.
    for stmt in [
        "ALTER TABLE session_exercise ADD COLUMN variant TEXT NOT NULL DEFAULT 'normal'",
        "ALTER TABLE set_entry ADD COLUMN variant TEXT NOT NULL DEFAULT 'normal'",
    ] {
        let _ = db.execute_unprepared(stmt).await;
    }
    Ok(())
}
