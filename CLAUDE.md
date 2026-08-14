# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A strength workout logger for two people sharing one phone. React + Vite PWA frontend (`frontend/`) talking to a Rust REST backend (`backend/`, axum + SeaORM + SQLite). There is no offline mode — all data lives in the backend database.

## Commands

Backend (from `backend/`):

```bash
cargo run                                # start on port 8080; creates+seeds data/train-together.db
cargo test                               # all tests live in src/tests.rs
cargo test logging_switches             # run a single test by name substring
cargo fmt --check                        # CI enforces formatting
cargo clippy --all-targets -- -D warnings  # CI treats clippy warnings as errors
```

Frontend (from `frontend/`):

```bash
npm install
npm run dev      # Vite on port 5173, proxies /api/* to localhost:8080
npm run build
```

There is no frontend test or lint script. For local development run the backend first, then the frontend.

Single-container build (frontend embedded in the Rust binary, served on 8080):

```bash
docker compose up --build    # or: docker build -t train-together . && docker run -p 8080:8080 -v train-together-data:/app/data train-together
```

## Architecture: thin client, full-state responses

The core contract of the whole app: **the backend owns all business logic, and every mutating endpoint returns the complete aggregate state** (`StateResponse` in `backend/src/state.rs`). The frontend never computes state transitions — it replaces its entire cache with each response.

- `frontend/src/store/AppContext.jsx` is the only frontend state container. It keeps the old reducer-style `dispatch(action)` interface so screens are unchanged from the original client-only app; each action case just calls the REST client (`frontend/src/lib/api.js`) and does `setServer(response)`. Only `snackbar` and `lastSummary` are client-side.
- `frontend/src/store/reducer.js` and `frontend/src/lib/selectors.js` contain no mutation logic anymore — they are pure read helpers over the aggregate, called during render.
- `StateResponse` and its nested structs mirror the frontend's JSON state tree exactly (camelCase). The same struct is the request body for `PUT /api/state` (backup import), so it must stay backward-tolerant of older backup shapes (`#[serde(default)]` on newer fields).
- ID format (`{prefix}_{base36 millis}_{base36 counter}`) is deliberately identical between `backend/src/ids.rs` and `frontend/src/lib/ids.js`. Seed data uses stable ids (`p_alex`, `t_push`, …) that tests assert against.

Backend layout: `handlers.rs` defines the full router and thin handler fns; business logic lives in `services/` (`catalog` = people/settings/exercises/templates, `session` = workout lifecycle and set logging, `admin` = import/reset, `seed` = demo data). The connection pool is intentionally capped at 1 connection to serialize SQLite access — sufficient only because the deployment guarantees a single process (`docs/adr/0002`).

Schema changes are migrations, not entity edits. `backend/migrations/V{n}__{name}.sql` is applied at boot by refinery (`src/migrate.rs`) before the pool opens, recorded in `refinery_schema_history`, and a `VACUUM INTO` snapshot of the database is written beside it first. A failure aborts startup rather than serving a half-migrated schema. Editing `entities.rs` alone changes nothing on disk — add a migration to match, and see `docs/adr/0001` for why V1 is an idempotent baseline.

Backend tests are integration-style: they build the real router against in-memory SQLite and drive it with `tower::ServiceExt::oneshot` (see `src/tests.rs`).

## Static serving and deployment

- The Dockerfile builds the frontend, copies `dist/` into `backend/static/`, and `rust-embed` bakes it into a static musl binary (`FROM scratch` final image). The axum router's fallback serves these embedded assets.
- Vite `base` defaults to `/train-together/` for GitHub Pages; the Docker build overrides with `VITE_BASE=/`. The app uses `HashRouter`, so no server-side route handling is needed.
- The GitHub Pages workflow deploys only the frontend, which is non-functional without a separately hosted backend (`VITE_API_URL`). The Docker image is the real single-artifact deployment.

## Gotchas

- The backend was rewritten from Kotlin/Spring Boot to Rust; a few frontend comments (e.g. in `api.js`, `vite.config.js`) still say "Spring Boot" — they mean the Rust backend on port 8080. `backend/src/test/resources/application.yml` is a leftover from that era.
- CI (`.github/workflows/backend.yml`) runs `cargo fmt --check` and `clippy -D warnings` — run both before committing backend changes.
- `embed_migrations!` reads `backend/migrations/` at compile time, but changing a file there does not invalidate the crate: `cargo build` can be a no-op and produce a binary missing your new migration. Touch a source file or `cargo clean -p train-together` after editing anything under `migrations/`.
- The deployed database is `couples.db`, not `train-together.db` (a `DATABASE_URL` override in `infra/gym.yaml`; renaming the file needs root on the node). Anything touching the database path must derive it from `DATABASE_URL`.

## Agent skills

### Issue tracker

Issues live as GitHub issues in `Nik5036350/train-together`, driven via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using the default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — root `CONTEXT.md` plus `docs/adr/`. See `docs/agents/domain.md`.
