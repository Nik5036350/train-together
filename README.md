# Couples Recording Mode

A strength workout logger for two people sharing one phone. Originally a
browser-only PWA; now a full-stack app.

## Layout

```
frontend/   React + Vite PWA (the original app, now talking to the backend over REST)
backend/    Spring Boot + Kotlin REST API, data stored in SQLite
```

## Running locally

Two processes. Start the backend first, then the frontend.

### Backend (port 8080)

```bash
cd backend
./gradlew bootRun
```

The SQLite database is created at `backend/data/couples.db` on first run and
seeded with the demo couple (Alex & Maria) and a "Push Day" routine.

### Frontend (port 5173)

```bash
cd frontend
npm install      # first time only
npm run dev
```

The Vite dev server proxies `/api/*` to the backend at `http://localhost:8080`.
Override the API base with `VITE_API_URL` if the backend runs elsewhere.

## Running with Docker (single container)

One image builds the frontend, bakes it into the Spring Boot jar, and serves both
the UI and the API from port 8080:

```bash
docker build -t couples .
docker run --rm -p 8080:8080 -v couples-data:/app/data couples
```

Then open <http://localhost:8080/>. The `-v couples-data:/app/data` volume keeps
the SQLite database (`/app/data/couples.db`) across container restarts.

Or with Compose:

```bash
docker compose up --build
```

## Notes

- All workout data now lives in the backend database — there is no offline mode.
- The GitHub Pages workflow deploys **only the frontend** (static hosting), which
  requires a separately hosted backend to function. See `frontend/DEPLOY.md`.
  The Docker image above is the single-artifact alternative — one container
  serving both the UI and the API.
