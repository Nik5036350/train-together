# Single-image build: the Spring Boot backend serves the compiled frontend.
# Stage 1 builds the React/Vite app, stage 2 bundles it into the Spring Boot fat
# jar, stage 3 runs the jar on a slim JRE.

# ---- Stage 1: build the frontend ----
FROM node:20-alpine AS web
WORKDIR /web
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
# Serve at root (not the GitHub Pages subpath) since Spring Boot hosts it at /.
ENV VITE_BASE=/
RUN npm run build

# ---- Stage 2: build the backend jar (with the frontend baked into static) ----
# Debian-based (glibc) so the bundled sqlite-jdbc native library loads.
FROM eclipse-temurin:21-jdk AS api
WORKDIR /api
# Warm the Gradle dependency cache on its own layer for faster rebuilds.
COPY backend/gradlew backend/settings.gradle.kts backend/build.gradle.kts ./
COPY backend/gradle ./gradle
RUN chmod +x gradlew && ./gradlew --no-daemon dependencies > /dev/null 2>&1 || true
COPY backend/ ./
# Spring Boot serves classpath:/static/** — drop the built SPA there.
COPY --from=web /web/dist/ src/main/resources/static/
RUN ./gradlew --no-daemon bootJar -x test

# ---- Stage 3: runtime ----
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=api /api/build/libs/*.jar /app/app.jar
# SQLite DB lives at /app/data/couples.db (created on boot). Mount a volume here
# to persist workout data across container recreation.
VOLUME ["/app/data"]
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
