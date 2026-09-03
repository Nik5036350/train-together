mod db;
mod dto;
mod entities;
mod error;
mod handlers;
mod ids;
mod migrate;
mod services;
mod state;

#[cfg(test)]
mod tests;

#[tokio::main]
async fn main() {
    let url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "sqlite://./data/train-together.db?mode=rwc".to_string());

    // Migrate before the pool opens, and refuse to start if it fails — a
    // half-migrated schema must never serve requests. A snapshot of the database
    // is taken first, so aborting here is always recoverable.
    match migrate::run(&url) {
        Ok(0) => {}
        Ok(n) => println!("Applied {n} migration(s)"),
        Err(e) => {
            eprintln!("FATAL: schema migration failed: {e}");
            std::process::exit(1);
        }
    }

    let db = db::connect(&url)
        .await
        .expect("failed to connect to database");
    services::seed::seed_if_empty(&db)
        .await
        .expect("failed to seed");

    let app = handlers::router(db);
    let addr = "0.0.0.0:8080";
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind");
    println!("Train Together backend listening on {addr}");
    axum::serve(listener, app).await.expect("server error");
}
