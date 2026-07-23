// Pure read helpers over the aggregate state tree. The business logic that used
// to live here (the reducer) now runs on the backend; these selectors remain
// because screens call them during render. The state shape is unchanged, so they
// work as before.

export function ownerOf(state) {
  return state.people.find((p) => p.isOwner)
}
export function partnerOf(state) {
  return state.people.find((p) => !p.isOwner && p.active)
}
export function personById(state, id) {
  return state.people.find((p) => p.id === id)
}

// Rest duration for a person on an exercise: personal profile overrides the
// exercise default (PRD FR-161).
export function restSecondsFor(state, personId, exerciseId) {
  const prof = state.personExerciseProfiles[`${personId}__${exerciseId}`]
  if (prof?.restSeconds) return prof.restSeconds
  return state.exercises[exerciseId]?.defaultRestSeconds || 90
}

// The exercise id a person is actually performing for a session-exercise,
// honouring a per-person substitution (PRD FR-202/203).
export function effectiveExerciseId(sessionExercise, personId) {
  return sessionExercise.perPerson[personId]?.substituteExerciseId || sessionExercise.exerciseId
}
