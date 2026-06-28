// Read helpers shared by screens. Kept pure so they can be called during render.

import { ownerOf, partnerOf } from '../store/reducer.js'

export { ownerOf, partnerOf }

// Most recent prior-session sets for a person on an exercise, with a label
// ("Mon"). Used for the "LAST TIME" snippet on the logging card.
export function lastTimeFor(state, personId, exerciseId) {
  for (const sess of state.history) {
    const sets = sess.sets.filter((s) => s.personId === personId && s.exerciseId === exerciseId)
    if (sets.length) {
      return { label: sess.label || 'Last', sets: sets.sort((a, b) => a.setIndex - b.setIndex) }
    }
  }
  return null
}

// A person's most recent set for an exercise across history (for Repeat fallback
// / default input values).
export function lastSetValues(state, personId, exerciseId) {
  const lt = lastTimeFor(state, personId, exerciseId)
  if (!lt) return null
  return lt.sets[lt.sets.length - 1]
}

// Sets logged this session for a given session-exercise + person.
export function sessionSets(session, sessionExerciseId, personId) {
  return session.sets
    .filter((s) => s.sessionExerciseId === sessionExerciseId && s.personId === personId)
    .sort((a, b) => a.setIndex - b.setIndex)
}

// Per-person totals for the summary screen.
export function personTotals(session, personId, exercises) {
  const sets = session.sets.filter((s) => s.personId === personId)
  const exIds = new Set(sets.map((s) => s.exerciseId))
  const volume = sets.reduce((sum, s) => sum + (s.weight || 0) * (s.reps || 0), 0)
  return {
    exercises: exIds.size,
    sets: sets.length,
    reps: sets.reduce((sum, s) => sum + (s.reps || 0), 0),
    volume,
  }
}

export function participantsOf(state, session) {
  const ids = session ? session.participantIds : []
  return state.people.filter((p) => ids.includes(p.id))
}
