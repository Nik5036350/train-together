use serde::Deserialize;

// Request bodies. Field names match the JSON the frontend sends (camelCase);
// `#[serde(default)]` mirrors the optional/absent handling of the old Kotlin DTOs.

fn default_assignment() -> String {
    "both".into()
}
fn default_mode() -> String {
    "alternate".into()
}
fn default_rest() -> i32 {
    90
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SavePartnerRequest {
    pub name: String,
    pub color: String,
    pub unit: String,
    #[serde(default)]
    pub initials: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePersonRequest {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub color: Option<String>,
    #[serde(default)]
    pub unit: Option<String>,
    #[serde(default)]
    pub initials: Option<String>,
    #[serde(default)]
    pub active: Option<bool>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSettingsRequest {
    #[serde(default)]
    pub couple_mode_enabled: Option<bool>,
    #[serde(default)]
    pub default_participants: Option<String>,
    #[serde(default)]
    pub default_logging_style: Option<String>,
    #[serde(default)]
    pub allow_copy_partner_values: Option<bool>,
    #[serde(default)]
    pub show_partner_history: Option<bool>,
}

#[derive(Deserialize, Default)]
pub struct TracksInput {
    #[serde(default)]
    pub weight: bool,
    #[serde(default)]
    pub reps: bool,
    #[serde(default)]
    pub duration: bool,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ProfileInput {
    #[serde(default)]
    pub rest_seconds: Option<i32>,
    #[serde(default)]
    pub machine_setup: Option<String>,
    #[serde(default)]
    pub cues: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveExerciseRequest {
    #[serde(default)]
    pub id: Option<String>,
    pub name: String,
    #[serde(default)]
    pub category: String,
    #[serde(default)]
    pub equipment: String,
    #[serde(default)]
    pub tracks: TracksInput,
    #[serde(default = "default_rest")]
    pub default_rest_seconds: i32,
    #[serde(default)]
    pub profiles: std::collections::HashMap<String, ProfileInput>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TemplateExerciseInput {
    pub exercise_id: String,
    #[serde(default = "default_assignment")]
    pub assignment: String,
    #[serde(default)]
    pub order: i32,
    #[serde(default)]
    pub default_logging_mode: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveTemplateRequest {
    #[serde(default)]
    pub id: Option<String>,
    pub name: String,
    #[serde(default = "default_mode")]
    pub default_mode: String,
    #[serde(default)]
    pub exercises: Vec<TemplateExerciseInput>,
}

#[derive(Deserialize)]
pub struct SetAssignmentRequest {
    pub assignment: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartSessionRequest {
    pub template_id: String,
    #[serde(default)]
    pub participant_ids: Vec<String>,
    #[serde(default)]
    pub logging_style: Option<String>,
}

#[derive(Deserialize, Default)]
pub struct LogValues {
    #[serde(default)]
    pub weight: Option<f64>,
    #[serde(default)]
    pub reps: Option<i32>,
    #[serde(default)]
    pub duration: Option<i32>,
    #[serde(default)]
    pub note: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LogSetRequest {
    pub session_exercise_id: String,
    pub person_id: String,
    #[serde(default)]
    pub values: LogValues,
    #[serde(default)]
    pub set_type: Option<String>,
}

#[derive(Deserialize)]
pub struct EditSetRequest {
    #[serde(default)]
    pub values: serde_json::Map<String, serde_json::Value>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReassignSetRequest {
    pub to_person_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddSessionExerciseRequest {
    pub exercise_id: String,
    #[serde(default = "default_assignment")]
    pub assignment: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SkipTurnRequest {
    pub person_id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SkipExerciseRequest {
    pub person_id: String,
    #[serde(default)]
    pub reason: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SubstituteRequest {
    pub person_id: String,
    #[serde(default)]
    pub substitute_exercise_id: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PersonStatusRequest {
    pub person_id: String,
    pub status: String,
}

#[derive(Deserialize)]
pub struct LoggingModeRequest {
    pub mode: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActiveRowRequest {
    pub person_id: String,
}
