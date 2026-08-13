# Schema migrations run at boot via refinery

The schema used to be built by `db::init_schema`, which ran
`CREATE TABLE IF NOT EXISTS` from the SeaORM entities on every boot and carried a
hand-maintained list of `ALTER TABLE` statements whose errors were discarded
(`let _ = db.execute_unprepared(stmt).await`). That made "the column already
exists" and "the statement is wrong" indistinguishable, and the process started
either way. There was also no record anywhere of which changes had been applied.

Schema changes now live in `backend/migrations/` as versioned SQL, applied by
[refinery](https://crates.io/crates/refinery) exactly once each and recorded in
`refinery_schema_history`. `migrate::run` executes before the SeaORM pool opens;
`init_schema` is deleted, so this is the only way a schema comes into existence.

## Why refinery

It is Flyway's model — `V{n}__{name}.sql`, applied once, recorded in a history
table, with divergence detection — which is what was wanted. `sea-orm-migration`
was the other credible option and would have avoided a second SQLite driver, but
its migrations are Rust rather than SQL. A hand-rolled runner (a version table
plus an ordered array) would have been about forty lines and is what the size of
this project justifies; refinery was chosen anyway for the checksumming and for
not having to maintain the runner.

Neither choice would have helped with the actual hard part: SQLite cannot express
type or constraint changes, so those still need the twelve-step table rebuild.
Versioned migrations solve bookkeeping, not expressiveness.

## SeaORM 2 was a prerequisite, not a bundled nice-to-have

`libsqlite3-sys` declares `links = "sqlite3"`, and Cargo refuses to build when two
semver-incompatible versions of a `links` crate are in one graph. refinery's only
SQLite driver is rusqlite, which needs `libsqlite3-sys ^0.37`; `sqlx-sqlite` 0.8
(via `sea-orm` 1.1) pinned `^0.30.1`. Staying on SeaORM 1.1 would have meant
pinning rusqlite back to 0.32.1. `sqlx-sqlite` 0.9 widened its range to
`>=0.30.1, <0.38.0`, which accommodates current rusqlite, so upgrading SeaORM
first removed the constraint instead of working around it. One `libsqlite3-sys`
0.37.0 is now shared by both drivers, with `bundled` enabled once, so the static
musl binary still contains a single SQLite.

## V1 is a deliberately idempotent baseline

The live database (`couples.db` on `home.lan`) already has every table — the old
`init_schema` built them — but no `refinery_schema_history`, so refinery sees V1
as unapplied and runs it there. V1 is therefore written as
`CREATE TABLE IF NOT EXISTS` throughout: a no-op against the live database,
correct against a fresh one. The alternative — inserting a baseline row into
`refinery_schema_history` by hand on the node — is a one-shot manual step with no
second chance, and it would have left two schema-creation paths in the code
forever.

Consequences worth knowing:

- The two `variant` columns carry `DEFAULT 'normal'` in V1 to match the live
  database, where they arrived by `ALTER TABLE`. Their **column position** still
  differs there (appended rather than mid-table). Harmless, because all access is
  by name, but "the live database and a fresh one are byte-identical" is not a
  claim this makes.
- A database created *before* the variant feature and never booted on
  variant-era code is **not supported**. V1 would no-op over its existing tables
  without adding the column, and the failure would surface later as
  `no such column: variant`. No such database is known to exist: the deployed
  image (`sha-f5cd572`) contains the old ALTERs and has booted, so the live file
  has the columns. Restore old data through `PUT /api/state` (JSON), not by
  dropping in a `.db` file.

## Failure is fatal

Any error in `migrate::run` aborts startup with a non-zero exit rather than
falling through to serve requests against a half-migrated schema. `set_grouped(true)`
puts all pending migrations in one transaction, so a failure rolls back rather
than leaving the schema partway. Verified end to end: with a deliberately invalid
V2, the process snapshots, prints `FATAL`, exits 1, and the database is left
untouched at V1 with `integrity_check` clean.

## Snapshots use VACUUM INTO, not fs::copy

Before applying anything, `migrate::run` writes a snapshot beside the database as
`<db>.pre-v<n>-<unix>` using SQLite's `VACUUM INTO`. Not `fs::copy`: in WAL mode
the committed-but-not-yet-checkpointed tail lives in the `-wal` sidecar, so
copying the main file alone would silently drop the newest writes from the file
being relied on for recovery. The deployed database is currently in `delete`
journal mode, not WAL, so that hazard is not live today — `VACUUM INTO` is used
because it is correct under either mode and stays correct if anyone adds
`journal_mode=wal` to the URL or a future sqlx changes its default.

Snapshots are only taken when something is actually going to be applied,
otherwise every pod restart would leave another copy. They are kept, not pruned:
the database is a few hundred KB and disk on `home.lan` is not the constraint.

## This is not a backup

The snapshot protects against exactly one failure: a migration that goes wrong.
It sits on the same disk, in the same `hostPath` directory, on the same node.

There is no automated backup of this data anywhere. `infra/gym.yaml` uses a raw
`hostPath` at `/home/nk/services/gym/data` on `home.lan` — no PVC, so no volume
snapshots — and the infra repository contains no CronJob, Velero, volsync or
restic. If that disk dies, every logged workout is gone. The only existing
recovery path is a human tapping Export in the UI. An off-node JSON backup
(`GET /api/state` on a schedule) is tracked as a separate issue and deliberately
out of scope here.

## Gotcha: editing `migrations/` does not trigger a rebuild

`embed_migrations!` reads the directory at compile time, but changing a file in it
does not invalidate the crate. `cargo build` after adding a migration can be a
no-op and produce a binary that silently lacks it — observed during verification.
Touch a source file (or `cargo clean -p train-together`) after changing anything
under `migrations/`. Docker builds are unaffected, since they always compile from
scratch.
