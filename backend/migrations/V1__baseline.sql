-- Baseline schema. Generated from the SeaORM entities in src/entities.rs (via
-- Schema::create_table_from_entity), which is what db::init_schema used to build
-- at every boot before refinery took over.
--
-- Deliberately idempotent (CREATE TABLE IF NOT EXISTS). The live database was
-- created by the old init_schema and has every table already, but has no
-- refinery_schema_history table, so refinery considers V1 unapplied and runs it
-- there. Being a no-op on an existing database is what lets the live database
-- and a fresh one converge on this one file.
--
-- The two `variant` columns carry DEFAULT 'normal' to match the live database,
-- where they were added by `ALTER TABLE ... ADD COLUMN variant TEXT NOT NULL
-- DEFAULT 'normal'` rather than by CREATE TABLE. Nothing inserts a row without
-- a variant, so the default is never used — it exists so a fresh database is
-- not stricter than the live one. (Column position still differs there:
-- appended by ALTER rather than mid-table. Harmless — all access is by name.)

CREATE TABLE IF NOT EXISTS "person" ( "id" varchar NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "initials" varchar NOT NULL, "color" varchar NOT NULL, "unit" varchar NOT NULL, "is_owner" boolean NOT NULL, "active" boolean NOT NULL );

CREATE TABLE IF NOT EXISTS "exercise" ( "id" varchar NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "category" varchar NOT NULL, "equipment" varchar NOT NULL, "tracks_weight" boolean NOT NULL, "tracks_reps" boolean NOT NULL, "tracks_duration" boolean NOT NULL, "default_rest_seconds" integer NOT NULL );

CREATE TABLE IF NOT EXISTS "person_exercise_profile" ( "id" varchar NOT NULL PRIMARY KEY, "person_id" varchar NOT NULL, "exercise_id" varchar NOT NULL, "rest_seconds" integer, "machine_setup" varchar NOT NULL, "cues" varchar NOT NULL );

CREATE TABLE IF NOT EXISTS "template" ( "id" varchar NOT NULL PRIMARY KEY, "name" varchar NOT NULL, "default_mode" varchar NOT NULL );

CREATE TABLE IF NOT EXISTS "template_exercise" ( "id" varchar NOT NULL PRIMARY KEY, "template_id" varchar NOT NULL, "exercise_id" varchar NOT NULL, "assignment" varchar NOT NULL, "order_index" integer NOT NULL, "default_logging_mode" varchar );

CREATE TABLE IF NOT EXISTS "app_settings" ( "id" varchar NOT NULL PRIMARY KEY, "couple_mode_enabled" boolean NOT NULL, "default_participants" varchar NOT NULL, "default_logging_style" varchar NOT NULL, "allow_copy_partner_values" boolean NOT NULL, "show_partner_history" boolean NOT NULL, "onboarded" boolean NOT NULL, "version" integer NOT NULL );

CREATE TABLE IF NOT EXISTS "workout_session" ( "id" varchar NOT NULL PRIMARY KEY, "template_id" varchar, "name" varchar NOT NULL, "start_time" integer NOT NULL, "end_time" integer, "label" varchar, "logging_style" varchar NOT NULL, "status" varchar NOT NULL );

CREATE TABLE IF NOT EXISTS "session_participant" ( "id" varchar NOT NULL PRIMARY KEY, "session_id" varchar NOT NULL, "person_id" varchar NOT NULL, "order_index" integer NOT NULL );

CREATE TABLE IF NOT EXISTS "session_exercise" ( "id" varchar NOT NULL PRIMARY KEY, "session_id" varchar NOT NULL, "exercise_id" varchar NOT NULL, "logging_mode" varchar NOT NULL, "variant" varchar NOT NULL DEFAULT 'normal', "active_person_id" varchar, "added_during_session" boolean NOT NULL, "order_index" integer NOT NULL );

CREATE TABLE IF NOT EXISTS "session_exercise_person" ( "id" varchar NOT NULL PRIMARY KEY, "session_exercise_id" varchar NOT NULL, "person_id" varchar NOT NULL, "status" varchar NOT NULL, "skip_reason" varchar, "substitute_exercise_id" varchar, "order_index" integer NOT NULL );

CREATE TABLE IF NOT EXISTS "set_entry" ( "id" varchar NOT NULL PRIMARY KEY, "session_id" varchar NOT NULL, "session_exercise_id" varchar, "exercise_id" varchar NOT NULL, "person_id" varchar NOT NULL, "set_index" integer NOT NULL, "weight" double, "reps" integer, "duration" integer, "set_type" varchar NOT NULL, "variant" varchar NOT NULL DEFAULT 'normal', "timestamp" integer, "note" varchar );

CREATE TABLE IF NOT EXISTS "rest_timer" ( "id" varchar NOT NULL PRIMARY KEY, "session_id" varchar NOT NULL, "person_id" varchar NOT NULL, "session_exercise_id" varchar NOT NULL, "started_at" integer NOT NULL, "duration_seconds" integer NOT NULL );
