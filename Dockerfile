# Single-image build: the Rust backend serves the compiled frontend (embedded in
# the binary). Stage 1 builds the React/Vite app, stage 2 builds a static musl
# binary with the frontend baked in, stage 3 is an empty `scratch` image holding
# just that binary (~20 MB total).

# ---- Stage 1: build the frontend ----
FROM node:20-alpine AS web
WORKDIR /web
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ---- Stage 2: build the static Rust binary ----
# rust:alpine targets x86_64-unknown-linux-musl by default -> fully static binary.
# build-base provides the C toolchain sqlx's bundled SQLite needs.
FROM rust:1-alpine AS builder
RUN apk add --no-cache build-base
WORKDIR /app
COPY backend/Cargo.toml backend/Cargo.lock ./
COPY backend/src ./src
# refinery's embed_migrations! reads this directory at compile time.
COPY backend/migrations ./migrations
# Embed the built frontend into the binary (rust-embed reads ./static at compile time).
COPY --from=web /web/dist/ ./static/
RUN cargo build --release

# ---- Stage 3: runtime ----
FROM scratch AS runtime
WORKDIR /app
COPY --from=builder /app/target/release/train-together /train-together
# SQLite DB lives at /app/data/train-together.db (created on boot). Mount a volume
# to persist workout data across container recreation.
ENV TMPDIR=/app/data
VOLUME ["/app/data"]
EXPOSE 8080
ENTRYPOINT ["/train-together"]
