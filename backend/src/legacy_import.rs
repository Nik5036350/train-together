// One-time conversion of the legacy aggregate (`StateResponse`: a PWA backup or
// the server's own legacy tables) into sync records for the iOS app.
//
// The record shapes here are the sync contract: each `data` object is exactly
// the camelCase row the iOS app stores. The golden fixture test pins the output
// and the iOS test suite decodes the same file, so change both together.

use crate::state::{SessionResp, StateResponse};
use serde_json::{json, Value};
use std::collections::HashSet;

pub struct LegacyRecord {
    pub entity: &'static str,
    pub id: String,
    pub data: Value,
}

pub struct Conversion {
    pub records: Vec<LegacyRecord>,
    pub duplicates_dropped: u64,
    pub warnings: Vec<String>,
    pub active_session: Option<String>,
}

#[derive(Default)]
struct Builder {
    records: Vec<LegacyRecord>,
    seen: HashSet<(&'static str, String)>,
    duplicates_dropped: u64,
    warnings: Vec<String>,
}

impl Builder {
    // First occurrence wins; a repeated (entity, id) would violate the store's
    // primary key, so later copies are dropped and counted.
    fn push(&mut self, entity: &'static str, id: String, data: Value) {
        if self.seen.insert((entity, id.clone())) {
            self.records.push(LegacyRecord { entity, id, data });
        } else {
            self.duplicates_dropped += 1;
        }
    }

    fn warn(&mut self, message: String) {
        self.warnings.push(message);
    }
}

// Legacy person colors map onto the five brand identities, like the web
// client's `resolveColorKey` (frontend/src/theme.js).
fn normalize_color(key: &str) -> &'static str {
    match key {
        "red" => "red",
        "steel" => "steel",
        "mustard" => "mustard",
        "green" => "green",
        "concrete" => "concrete",
        "orange" | "pink" => "red",
        _ => "steel",
    }
}

// Notes and skip reasons that are blank after trimming are stored as null, as
// the legacy `log_set` did for notes.
fn non_blank(value: &Option<String>) -> Value {
    match value {
        Some(v) if !v.trim().is_empty() => Value::String(v.clone()),
        _ => Value::Null,
    }
}

pub fn convert(state: &StateResponse) -> Conversion {
    let mut b = Builder::default();
    let person_ids: HashSet<&str> = state.people.iter().map(|p| p.id.as_str()).collect();

    let s = &state.settings;
    b.push(
        "settings",
        "app".into(),
        json!({
            "id": "app",
            "defaultParticipants": s.default_participants,
            "defaultLoggingStyle": s.default_logging_style,
            "coupleModeEnabled": s.couple_mode_enabled,
            "allowCopyPartnerValues": s.allow_copy_partner_values,
            "showPartnerHistory": s.show_partner_history,
        }),
    );

    for p in &state.people {
        b.push(
            "person",
            p.id.clone(),
            json!({
                "id": p.id,
                "name": p.name,
                "initials": p.initials,
                "color": normalize_color(&p.color),
                "unit": p.unit,
                "isOwner": p.is_owner,
                "active": p.active,
            }),
        );
    }

    for e in state.exercises.values() {
        b.push(
            "exercise",
            e.id.clone(),
            json!({
                "id": e.id,
                "name": e.name,
                "category": e.category,
                "equipment": e.equipment,
                "tracksWeight": e.tracks.weight,
                "tracksReps": e.tracks.reps,
                "tracksDuration": e.tracks.duration,
                "defaultRestSeconds": e.default_rest_seconds,
            }),
        );
    }

    for (key, p) in &state.person_exercise_profiles {
        let Some((person_id, exercise_id)) = key
            .split_once("__")
            .filter(|(pid, eid)| !pid.is_empty() && !eid.is_empty())
        else {
            b.warn(format!("profile key {key:?} is malformed; skipped"));
            continue;
        };
        if !person_ids.contains(person_id) {
            b.warn(format!(
                "profile {key} references unknown person {person_id}"
            ));
        }
        // Deterministic id: the phone derives the same one from the natural key,
        // so re-imports and later edits address the same record.
        let id = format!("prof_{person_id}__{exercise_id}");
        b.push(
            "person_exercise_profile",
            id.clone(),
            json!({
                "id": id,
                "personId": person_id,
                "exerciseId": exercise_id,
                "restSeconds": p.rest_seconds,
                "machineSetup": p.machine_setup,
                "cues": p.cues,
            }),
        );
    }

    for t in state.templates.values() {
        b.push(
            "template",
            t.id.clone(),
            json!({ "id": t.id, "name": t.name, "defaultMode": t.default_mode }),
        );
        // Legacy `order` values can repeat (removing a routine exercise never
        // renumbered the rest), so ids and orderIndex come from the position
        // after a stable sort.
        let mut exercises: Vec<_> = t.exercises.iter().collect();
        exercises.sort_by_key(|te| te.order);
        for (i, te) in exercises.into_iter().enumerate() {
            if !state.exercises.contains_key(&te.exercise_id) {
                b.warn(format!(
                    "routine {} references unknown exercise {}",
                    t.id, te.exercise_id
                ));
            }
            let id = format!("tex_{}_{i}", t.id);
            b.push(
                "template_exercise",
                id.clone(),
                json!({
                    "id": id,
                    "templateId": t.id,
                    "exerciseId": te.exercise_id,
                    "assignment": te.assignment,
                    "orderIndex": i,
                    "defaultLoggingMode": te.default_logging_mode,
                }),
            );
        }
    }

    for s in &state.history {
        let mut status = s.status.clone();
        if status == "active" {
            b.warn(format!(
                "history session {} was marked active; imported as finished",
                s.id
            ));
            status = "finished".into();
        }
        convert_session(&mut b, &person_ids, s, &status);
    }
    let mut active_session = None;
    if let Some(s) = &state.session {
        convert_session(&mut b, &person_ids, s, &s.status);
        if s.status == "active" {
            active_session = Some(s.id.clone());
        }
    }

    Conversion {
        records: b.records,
        duplicates_dropped: b.duplicates_dropped,
        warnings: b.warnings,
        active_session,
    }
}

fn convert_session(b: &mut Builder, person_ids: &HashSet<&str>, s: &SessionResp, status: &str) {
    b.push(
        "workout_session",
        s.id.clone(),
        json!({
            "id": s.id,
            "templateId": s.template_id,
            "name": s.name,
            "startTime": s.start_time,
            "endTime": s.end_time,
            "label": s.label,
            "loggingStyle": s.logging_style,
            "status": status,
        }),
    );

    for (i, pid) in s.participant_ids.iter().enumerate() {
        if !person_ids.contains(pid.as_str()) {
            b.warn(format!("session {} lists unknown participant {pid}", s.id));
        }
        let id = format!("spart_{}_{pid}", s.id);
        b.push(
            "session_participant",
            id.clone(),
            json!({ "id": id, "sessionId": s.id, "personId": pid, "orderIndex": i }),
        );
    }

    let mut session_exercise_ids = HashSet::new();
    for (order, se) in s.exercises.iter().enumerate() {
        session_exercise_ids.insert(se.id.as_str());
        b.push(
            "session_exercise",
            se.id.clone(),
            json!({
                "id": se.id,
                "sessionId": s.id,
                "exerciseId": se.exercise_id,
                "loggingMode": se.logging_mode,
                "variant": se.variant,
                "activePersonId": se.active_person_id,
                "addedDuringSession": se.added_during_session.unwrap_or(false),
                "orderIndex": order,
            }),
        );
        for (i, pid) in se.applies_to.iter().enumerate() {
            let pp = se.per_person.get(pid);
            let id = format!("sep_{}_{pid}", se.id);
            b.push(
                "session_exercise_person",
                id.clone(),
                json!({
                    "id": id,
                    "sessionExerciseId": se.id,
                    "personId": pid,
                    "status": pp.map(|p| p.status.as_str()).unwrap_or("pending"),
                    "skipReason": pp.map(|p| non_blank(&p.skip_reason)).unwrap_or(Value::Null),
                    "substituteExerciseId": pp.and_then(|p| p.substitute_exercise_id.clone()),
                    "orderIndex": i,
                }),
            );
        }
    }

    for st in &s.sets {
        if !person_ids.contains(st.person_id.as_str()) {
            b.warn(format!(
                "set {} belongs to unknown person {}",
                st.id, st.person_id
            ));
        }
        // A set pointing at a session exercise that isn't in the session would
        // be dropped as an orphan on the phone; detach it instead so it stays in
        // history like the seeded sets (which have no session exercise).
        let session_exercise_id = match &st.session_exercise_id {
            Some(seid) if !session_exercise_ids.contains(seid.as_str()) => {
                b.warn(format!(
                    "set {} references missing session exercise {seid}; detached",
                    st.id
                ));
                None
            }
            other => other.clone(),
        };
        b.push(
            "set_entry",
            st.id.clone(),
            json!({
                "id": st.id,
                "sessionId": s.id,
                "sessionExerciseId": session_exercise_id,
                "exerciseId": st.exercise_id,
                "personId": st.person_id,
                "setIndex": st.set_index,
                "weight": st.weight,
                "reps": st.reps,
                "duration": st.duration,
                "setType": st.set_type,
                "variant": st.variant,
                "timestamp": st.timestamp,
                "note": non_blank(&st.note),
            }),
        );
    }
}
