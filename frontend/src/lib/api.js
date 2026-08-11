// REST client for the Spring Boot backend. Every mutating call returns the full
// refreshed aggregate state (same JSON shape the old reducer produced), so the
// store can replace its cache wholesale.

const BASE = import.meta.env.VITE_API_URL || '/api'

async function request(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: body !== undefined ? { 'Content-Type': 'application/json' } : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`${method} ${path} failed (${res.status}): ${text}`)
  }
  return res.json()
}

export const api = {
  getState: () => request('GET', '/state'),
  importState: (state) => request('PUT', '/state', state),

  // people / settings
  savePartner: (body) => request('PUT', '/partner', body),
  updatePerson: (id, patch) => request('PATCH', `/people/${id}`, patch),
  updateSettings: (patch) => request('PATCH', '/settings', patch),
  toggleCoupleMode: () => request('POST', '/settings/toggle-couple-mode'),

  // exercises
  createExercise: (body) => request('POST', '/exercises', body),
  updateExercise: (id, body) => request('PUT', `/exercises/${id}`, body),
  deleteExercise: (id) => request('DELETE', `/exercises/${id}`),

  // templates
  createTemplate: (body) => request('POST', '/templates', body),
  updateTemplate: (id, body) => request('PUT', `/templates/${id}`, body),
  deleteTemplate: (id) => request('DELETE', `/templates/${id}`),
  setAssignment: (templateId, exerciseId, assignment) =>
    request('PATCH', `/templates/${templateId}/exercises/${exerciseId}/assignment`, { assignment }),

  // session lifecycle
  startSession: (body) => request('POST', '/sessions', body),
  finishSession: (id) => request('POST', `/sessions/${id}/finish`),
  deleteSession: (id) => request('DELETE', `/sessions/${id}`),

  // sets (active + history, keyed by owning session)
  logSet: (sessionId, body) => request('POST', `/sessions/${sessionId}/sets`, body),
  undoSet: (sessionId, setId) => request('POST', `/sessions/${sessionId}/sets/${setId}/undo`),
  editSet: (sessionId, setId, values) => request('PATCH', `/sessions/${sessionId}/sets/${setId}`, { values }),
  deleteSet: (sessionId, setId) => request('DELETE', `/sessions/${sessionId}/sets/${setId}`),
  reassignSet: (sessionId, setId, toPersonId) =>
    request('PATCH', `/sessions/${sessionId}/sets/${setId}/reassign`, { toPersonId }),
  addSessionExercise: (sessionId, body) => request('POST', `/sessions/${sessionId}/exercises`, body),

  // session-exercise mutations
  skipTurn: (seId, personId) => request('POST', `/session-exercises/${seId}/skip-turn`, { personId }),
  skipExercise: (seId, body) => request('POST', `/session-exercises/${seId}/skip`, body),
  substitute: (seId, body) => request('PATCH', `/session-exercises/${seId}/substitute`, body),
  personStatus: (seId, body) => request('PATCH', `/session-exercises/${seId}/person-status`, body),
  loggingMode: (seId, mode) => request('PATCH', `/session-exercises/${seId}/logging-mode`, { mode }),
  variant: (seId, variant) => request('PATCH', `/session-exercises/${seId}/variant`, { variant }),
  activeRow: (seId, personId) => request('PATCH', `/session-exercises/${seId}/active-row`, { personId }),

  // admin
  resetDemo: () => request('POST', '/admin/reset-demo'),
  restoreDemoRoutine: () => request('POST', '/admin/restore-demo-routine'),
}
