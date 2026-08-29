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

Backend layout: `handlers.rs` defines the full router and thin handler fns; business logic lives in `services/` (`catalog` = people/settings/exercises/templates, `session` = workout lifecycle and set logging, `admin` = import/reset, `seed` = demo data). `db.rs` creates the schema directly from the SeaORM entities on boot — there are no migration files; schema changes mean editing `entities.rs` (existing databases are not migrated). The connection pool is intentionally capped at 1 connection to serialize SQLite access.

Backend tests are integration-style: they build the real router against in-memory SQLite and drive it with `tower::ServiceExt::oneshot` (see `src/tests.rs`).

## Static serving and deployment

- The Dockerfile builds the frontend, copies `dist/` into the Rust build's `static/` directory, and `rust-embed` bakes it into a static musl binary (`FROM scratch` final image). The axum router's fallback serves these embedded assets.
- Vite builds for `/` by default; `VITE_BASE` is available for an intentional subpath deployment. The app uses `HashRouter`, so the server does not need route-specific fallbacks.
- `.github/workflows/docker.yml` publishes the image to GHCR. A successful push to `main` then updates `infra/gym.yaml` in `Nik5036350/home-infra` for the GitOps rollout.

## Gotchas

- `backend/src/test/resources/application.yml` is a leftover from the former Kotlin/Spring Boot backend.
- CI (`.github/workflows/backend.yml`) runs `cargo fmt --check` and `clippy -D warnings` — run both before committing backend changes.
