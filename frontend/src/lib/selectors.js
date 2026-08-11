// Read helpers shared by screens. Kept pure so they can be called during render.

import { ownerOf, partnerOf } from '../store/reducer.js'

export { ownerOf, partnerOf }

// Sets from before the variant feature carry no variant field; treat them as
// "normal". A null/undefined `variant` argument means "don't filter".
function matchesVariant(set, variant) {
  return variant == null || (set.variant || 'normal') === variant
}

// Most recent prior-session sets for a person on an exercise, with a label
// ("Mon"). Used for the "LAST TIME" snippet on the logging card. With a variant
// given, this is the most recent session containing sets of that variant — each
// variant keeps its own history line.
export function lastTimeFor(state, personId, exerciseId, variant) {
  for (const sess of state.history) {
    const sets = sess.sets.filter(
      (s) => s.personId === personId && s.exerciseId === exerciseId && matchesVariant(s, variant),
    )
    if (sets.length) {
      return { label: sess.label || 'Last', sets: sets.sort((a, b) => a.setIndex - b.setIndex) }
    }
  }
  return null
}

// A person's most recent set for an exercise across history (for Repeat fallback
// / default input values).
export function lastSetValues(state, personId, exerciseId, variant) {
  const lt = lastTimeFor(state, personId, exerciseId, variant)
  if (!lt) return null
  return lt.sets[lt.sets.length - 1]
}

// Sets logged this session for a given session-exercise + person.
export function sessionSets(session, sessionExerciseId, personId, variant) {
  return session.sets
    .filter(
      (s) =>
        s.sessionExerciseId === sessionExerciseId &&
        s.personId === personId &&
        matchesVariant(s, variant),
    )
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
