mod db;
mod dto;
mod entities;
mod error;
mod handlers;
mod ids;
mod services;
mod state;

#[cfg(test)]
mod tests;

#[tokio::main]
async fn main() {
    // SQLite won't create missing parent directories for the DB file.
    std::fs::create_dir_all("data").ok();

    let url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "sqlite://./data/couples.db?mode=rwc".to_string());
    let db = db::connect(&url)
        .await
        .expect("failed to connect to database");
    db::init_schema(&db).await.expect("failed to create schema");
    services::seed::seed_if_empty(&db)
        .await
        .expect("failed to seed");

    let app = handlers::router(db);
    let addr = "0.0.0.0:8080";
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind");
    println!("Couples Recording backend listening on {addr}");
    axum::serve(listener, app).await.expect("server error");
}
