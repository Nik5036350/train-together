// Schema migrations. refinery owns the schema: versioned SQL files under
// migrations/, each applied exactly once, recorded in refinery_schema_history.
// There is no other path to a schema — this replaced db::init_schema, which
// rebuilt the tables from the entities on every boot and carried an ad-hoc list
// of ALTER TABLE statements whose errors were discarded.
//
// Runs on a plain rusqlite connection before the SeaORM pool opens, because
// refinery's only SQLite driver is rusqlite. Both share one statically linked
// libsqlite3-sys, so the binary still contains a single SQLite.
//
// Two properties matter here:
//   - Nothing is applied before a consistent snapshot of the database exists.
//   - Any failure aborts startup. Serving requests against a half-migrated
//     schema is the outcome worth preventing, and aborting is safe precisely
//     because the snapshot was taken first.

use std::error::Error;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

mod embedded {
    use refinery::embed_migrations;
    embed_migrations!("./migrations");
}

// Pull the filesystem path out of a SQLite connection URL. Handles the deployed
// form (`sqlite:///app/data/couples.db?mode=rwc`, absolute) and the dev default
// (`sqlite://./data/train-together.db?mode=rwc`, relative). In-memory URLs get
// None: a rusqlite connection to `:memory:` is a *different* database from the
// pool's, so migrating one would silently do nothing useful.
pub fn db_path_from_url(url: &str) -> Option<PathBuf> {
    let rest = url
        .strip_prefix("sqlite://")
        .or_else(|| url.strip_prefix("sqlite:"))?;
    let path = rest.split('?').next().unwrap_or(rest);
    if path.is_empty() || path.starts_with(":memory:") || path.contains("mode=memory") {
        return None;
    }
    Some(PathBuf::from(path))
}

// SQLite's own consistent-snapshot mechanism. Deliberately not fs::copy: in WAL
// mode the committed-but-not-yet-checkpointed tail lives in the -wal sidecar, so
// copying the main file alone silently drops the most recent writes — the newest
// workouts — from the file we would be relying on to recover. VACUUM INTO is
// correct under any journal mode and yields a single clean file.
fn snapshot(
    conn: &rusqlite::Connection,
    db: &Path,
    from_version: i32,
) -> rusqlite::Result<PathBuf> {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let mut dest = db.as_os_str().to_owned();
    dest.push(format!(".pre-v{from_version}-{stamp}"));
    let dest = PathBuf::from(dest);
    conn.execute("VACUUM INTO ?1", [dest.to_string_lossy().as_ref()])?;
    Ok(dest)
}

fn applied_version(
    runner: &refinery::Runner,
    conn: &mut rusqlite::Connection,
) -> Result<i32, Box<dyn Error>> {
    // Ask whether refinery's bookkeeping table exists before querying it, rather
    // than running the query and treating any error as "nothing applied" — that
    // would hide a real failure behind the same branch as a first-ever run.
    let has_history: i64 = conn.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'refinery_schema_history'",
        [],
        |row| row.get(0),
    )?;
    if has_history == 0 {
        return Ok(0);
    }
    Ok(runner
        .get_last_applied_migration(conn)?
        .map(|m| m.version())
        .unwrap_or(0))
}

// Bring the database at `url` up to date. Returns the number of migrations
// applied. Any error here should abort startup.
pub fn run(url: &str) -> Result<usize, Box<dyn Error>> {
    let path = db_path_from_url(url).ok_or_else(|| {
        format!("DATABASE_URL {url:?} is not a file-backed SQLite database; migrations need a file")
    })?;

    // SQLite will not create missing parent directories for the database file.
    if let Some(parent) = path.parent().filter(|p| !p.as_os_str().is_empty()) {
        std::fs::create_dir_all(parent)?;
    }

    let mut conn = rusqlite::Connection::open(&path)?;
    let runner = embedded::migrations::runner().set_grouped(true);

    let current = applied_version(&runner, &mut conn)?;
    let target = runner
        .get_migrations()
        .iter()
        .map(|m| m.version())
        .max()
        .unwrap_or(0);
    if target <= current {
        println!("Schema up to date at V{current}");
        return Ok(0);
    }

    // Only snapshot when something is actually going to be applied — otherwise
    // every pod restart would leave another copy behind.
    let existing = std::fs::metadata(&path)
        .map(|m| m.len() > 0)
        .unwrap_or(false);
    if existing {
        let dest = snapshot(&conn, &path, current)?;
        println!(
            "Snapshotted database to {} before migrating",
            dest.display()
        );
    }

    println!("Migrating schema V{current} -> V{target}");
    let report = runner.run(&mut conn)?;
    let applied = report.applied_migrations().len();
    for m in report.applied_migrations() {
        println!("  applied V{} {}", m.version(), m.name());
    }
    Ok(applied)
}
