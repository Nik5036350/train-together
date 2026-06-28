import { uid } from '../lib/ids.js'
import { makeInitialState } from './seed.js'

// ---- selectors used inside the reducer --------------------------------------

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

// Which people a template exercise applies to, given the session participants.
function appliesTo(assignment, participantIds, owner, partner) {
  const wanted =
    assignment === 'both'
      ? [owner?.id, partner?.id]
      : assignment === 'owner'
        ? [owner?.id]
        : [partner?.id]
  return wanted.filter((id) => id && participantIds.includes(id))
}

// ---- reducer ----------------------------------------------------------------

export function reducer(state, action) {
  switch (action.type) {
    case 'RESET_DEMO':
      return makeInitialState()

    case 'RESTORE_DEMO_ROUTINE': {
      // Bring back the seeded "Push Day" routine without disturbing the user's
      // own data. Re-adds any seed exercises it references that were deleted.
      const seed = makeInitialState()
      return {
        ...state,
        exercises: { ...seed.exercises, ...state.exercises },
        templates: { ...state.templates, t_push: seed.templates.t_push },
      }
    }

    case 'HYDRATE':
      return action.state

    // -- onboarding / settings ------------------------------------------------
    case 'SAVE_PARTNER': {
      const { name, color, unit, initials } = action.payload
      const partner = partnerOf(state)
      const people = partner
        ? state.people.map((p) =>
            p.id === partner.id ? { ...p, name, color, unit, initials: initials || name[0] } : p,
          )
        : [
            ...state.people,
            {
              id: uid('p'),
              name,
              initials: initials || name[0],
              color,
              unit,
              isOwner: false,
              active: true,
            },
          ]
      return {
        ...state,
        people,
        onboarded: true,
        settings: { ...state.settings, coupleModeEnabled: true },
      }
    }

    case 'UPDATE_PERSON': {
      // Edit any person (owner or partner): name, color, unit, initials.
      const { personId, patch } = action.payload
      return {
        ...state,
        people: state.people.map((p) => (p.id === personId ? { ...p, ...patch } : p)),
      }
    }

    case 'UPDATE_SETTINGS':
      return { ...state, settings: { ...state.settings, ...action.payload } }

    case 'TOGGLE_COUPLE_MODE':
      return {
        ...state,
        settings: { ...state.settings, coupleModeEnabled: !state.settings.coupleModeEnabled },
      }

    // -- exercise library -----------------------------------------------------
    case 'CREATE_EXERCISE': {
      const { exercise, profiles } = action.payload
      const id = exercise.id || uid('ex')
      const exercises = { ...state.exercises, [id]: { ...exercise, id } }
      const personExerciseProfiles = { ...state.personExerciseProfiles }
      Object.entries(profiles || {}).forEach(([personId, prof]) => {
        personExerciseProfiles[`${personId}__${id}`] = prof
      })
      return { ...state, exercises, personExerciseProfiles }
    }

    case 'DELETE_EXERCISE': {
      const { exerciseId } = action.payload
      const exercises = { ...state.exercises }
      delete exercises[exerciseId]

      // Strip the exercise from every routine that referenced it.
      const templates = {}
      Object.entries(state.templates).forEach(([tid, tpl]) => {
        templates[tid] = { ...tpl, exercises: tpl.exercises.filter((e) => e.exerciseId !== exerciseId) }
      })

      // Drop its per-person profiles. History set records keep their raw
      // exerciseId — they just stop matching the (now deleted) definition.
      const personExerciseProfiles = {}
      Object.entries(state.personExerciseProfiles).forEach(([key, prof]) => {
        if (!key.endsWith(`__${exerciseId}`)) personExerciseProfiles[key] = prof
      })

      return { ...state, exercises, templates, personExerciseProfiles }
    }

    // -- template builder -----------------------------------------------------
    case 'SAVE_TEMPLATE': {
      const tpl = action.payload
      const id = tpl.id || uid('t')
      return { ...state, templates: { ...state.templates, [id]: { ...tpl, id } } }
    }

    case 'DELETE_TEMPLATE': {
      const templates = { ...state.templates }
      delete templates[action.payload.templateId]
      return { ...state, templates }
    }

    case 'SET_ASSIGNMENT': {
      const { templateId, exerciseId, assignment } = action.payload
      const tpl = state.templates[templateId]
      if (!tpl) return state
      const exercises = tpl.exercises.map((e) =>
        e.exerciseId === exerciseId ? { ...e, assignment } : e,
      )
      return {
        ...state,
        templates: { ...state.templates, [templateId]: { ...tpl, exercises } },
      }
    }

    // -- session lifecycle ----------------------------------------------------
    case 'START_SESSION': {
      const { templateId, participantIds, loggingStyle } = action.payload
      const tpl = state.templates[templateId]
      const owner = ownerOf(state)
      const partner = partnerOf(state)
      const sessionExercises = tpl.exercises
        .slice()
        .sort((a, b) => a.order - b.order)
        .map((te) => {
          const people = appliesTo(te.assignment, participantIds, owner, partner)
          if (people.length === 0) return null
          const perPerson = {}
          people.forEach((pid) => {
            perPerson[pid] = { status: 'pending', skipReason: null, substituteExerciseId: null }
          })
          return {
            id: uid('se'),
            exerciseId: te.exerciseId,
            appliesTo: people,
            loggingMode: te.defaultLoggingMode || loggingStyle || tpl.defaultMode || 'alternate',
            perPerson,
            activePersonId: people[0],
          }
        })
        .filter(Boolean)

      return {
        ...state,
        session: {
          id: uid('sess'),
          templateId,
          name: tpl.name,
          startTime: Date.now(),
          participantIds,
          loggingStyle: loggingStyle || tpl.defaultMode || 'alternate',
          status: 'active',
          exercises: sessionExercises,
          sets: [],
          timers: {}, // keyed by personId -> { sessionExerciseId, startedAt, durationSeconds }
        },
        snackbar: null,
      }
    }

    case 'LOG_SET': {
      const { sessionExerciseId, personId, values, setType, source } = action.payload
      const session = state.session
      if (!session) return state
      const se = session.exercises.find((e) => e.id === sessionExerciseId)
      if (!se) return state
      const exId = effectiveExerciseId(se, personId)
      const priorCount = session.sets.filter(
        (s) => s.sessionExerciseId === sessionExerciseId && s.personId === personId,
      ).length

      const set = {
        id: uid('set'),
        sessionExerciseId,
        exerciseId: exId,
        personId,
        setIndex: priorCount,
        weight: values.weight ?? null,
        reps: values.reps ?? null,
        duration: values.duration ?? null,
        setType: setType || 'working',
        timestamp: Date.now(),
        note: values.note || null,
      }

      // Switch active row for alternate / turns modes (PRD FR-140/142).
      const others = se.appliesTo.filter((id) => id !== personId)
      const switchActive = se.loggingMode === 'alternate' || se.loggingMode === 'turns'
      const nextActive = switchActive && others.length ? others[0] : personId

      const exercises = session.exercises.map((e) =>
        e.id === sessionExerciseId
          ? {
              ...e,
              activePersonId: nextActive,
              perPerson: {
                ...e.perPerson,
                [personId]: { ...e.perPerson[personId], status: 'logged' },
              },
            }
          : e,
      )

      const timers = {
        ...session.timers,
        [personId]: {
          sessionExerciseId,
          startedAt: Date.now(),
          durationSeconds: restSecondsFor(state, personId, exId),
        },
      }

      const person = personById(state, personId)
      return {
        ...state,
        session: { ...session, sets: [...session.sets, set], exercises, timers },
        snackbar: {
          id: uid('snk'),
          setId: set.id,
          personId,
          sessionExerciseId,
          prevActivePersonId: se.activePersonId,
          kind: source === 'repeat' ? 'repeat' : 'log',
          undoable: true,
          createdAt: Date.now(),
          // text is composed in the UI where unit + exercise are available
          person: person?.name,
        },
      }
    }

    case 'UNDO_LAST': {
      const session = state.session
      const snk = state.snackbar
      if (!session || !snk?.setId) return state
      const sets = session.sets.filter((s) => s.id !== snk.setId)
      // Restore the active row to whoever logged the undone set.
      const exercises = session.exercises.map((e) =>
        e.id === snk.sessionExerciseId ? { ...e, activePersonId: snk.personId } : e,
      )
      // Drop the rest timer that the undone set started.
      const timers = { ...session.timers }
      const t = timers[snk.personId]
      if (t && t.sessionExerciseId === snk.sessionExerciseId) delete timers[snk.personId]
      return {
        ...state,
        session: { ...session, sets, exercises, timers },
        snackbar: null,
      }
    }

    case 'REASSIGN_SET': {
      const { setId, toPersonId } = action.payload
      const session = state.session
      if (!session) return state
      const sets = session.sets.map((s) => (s.id === setId ? { ...s, personId: toPersonId } : s))
      return { ...state, session: { ...session, sets } }
    }

    case 'EDIT_SET': {
      const { setId, values } = action.payload
      const session = state.session
      if (!session) return state
      const sets = session.sets.map((s) =>
        s.id === setId
          ? {
              ...s,
              ...(values.weight !== undefined ? { weight: values.weight } : {}),
              ...(values.reps !== undefined ? { reps: values.reps } : {}),
              ...(values.duration !== undefined ? { duration: values.duration } : {}),
              ...(values.note !== undefined ? { note: values.note } : {}),
            }
          : s,
      )
      return { ...state, session: { ...session, sets } }
    }

    case 'DELETE_SET': {
      const session = state.session
      if (!session) return state
      const removed = session.sets.find((s) => s.id === action.payload.setId)
      let sets = session.sets.filter((s) => s.id !== action.payload.setId)
      // Renumber the remaining sets for the affected person+exercise so setIndex
      // stays contiguous (LOG_SET derives the next index from the count).
      if (removed) {
        let i = 0
        sets = sets
          .map((s) => ({ s, key: s.sessionExerciseId === removed.sessionExerciseId && s.personId === removed.personId }))
          .map(({ s, key }) => (key ? { ...s, setIndex: i++ } : s))
      }
      return { ...state, session: { ...session, sets } }
    }

    // -- editing sets in a finished (history) session -------------------------
    case 'EDIT_HISTORY_SET': {
      const { sessionId, setId, values } = action.payload
      const history = state.history.map((h) => {
        if (h.id !== sessionId) return h
        return {
          ...h,
          sets: h.sets.map((s) =>
            s.id === setId
              ? {
                  ...s,
                  ...(values.weight !== undefined ? { weight: values.weight } : {}),
                  ...(values.reps !== undefined ? { reps: values.reps } : {}),
                  ...(values.duration !== undefined ? { duration: values.duration } : {}),
                  ...(values.note !== undefined ? { note: values.note } : {}),
                }
              : s,
          ),
        }
      })
      return { ...state, history }
    }

    case 'DELETE_HISTORY_SET': {
      const { sessionId, setId } = action.payload
      const history = state.history.map((h) => {
        if (h.id !== sessionId) return h
        const removed = h.sets.find((s) => s.id === setId)
        let sets = h.sets.filter((s) => s.id !== setId)
        // Renumber remaining sets for the affected exercise+person (history
        // groups by exerciseId) so setIndex stays contiguous.
        if (removed) {
          let i = 0
          sets = sets.map((s) =>
            s.exerciseId === removed.exerciseId && s.personId === removed.personId
              ? { ...s, setIndex: i++ }
              : s,
          )
        }
        return { ...h, sets }
      })
      return { ...state, history }
    }

    case 'REASSIGN_HISTORY_SET': {
      const { sessionId, setId, toPersonId } = action.payload
      const history = state.history.map((h) =>
        h.id === sessionId
          ? { ...h, sets: h.sets.map((s) => (s.id === setId ? { ...s, personId: toPersonId } : s)) }
          : h,
      )
      return { ...state, history }
    }

    case 'SET_PERSON_STATUS': {
      // Generic per-person status change: 'done' / 'pending'.
      const { sessionExerciseId, personId, status } = action.payload
      const session = state.session
      if (!session) return state
      const exercises = session.exercises.map((e) =>
        e.id === sessionExerciseId
          ? { ...e, perPerson: { ...e.perPerson, [personId]: { ...e.perPerson[personId], status } } }
          : e,
      )
      return { ...state, session: { ...session, exercises } }
    }

    case 'SKIP_TURN': {
      // Pass this turn to the other participant without logging a set or
      // starting a rest timer. The person stays in the exercise.
      const { sessionExerciseId, personId } = action.payload
      const session = state.session
      if (!session) return state
      const se = session.exercises.find((e) => e.id === sessionExerciseId)
      if (!se) return state
      const others = se.appliesTo.filter(
        (id) => id !== personId && se.perPerson[id]?.status !== 'skipped',
      )
      const nextActive = others[0] || se.activePersonId
      const exercises = session.exercises.map((e) =>
        e.id === sessionExerciseId ? { ...e, activePersonId: nextActive } : e,
      )
      const person = personById(state, personId)
      return {
        ...state,
        session: { ...session, exercises },
        snackbar: {
          id: uid('snk'),
          kind: 'skipturn',
          personId,
          sessionExerciseId,
          undoable: false,
          createdAt: Date.now(),
          person: person?.name,
        },
      }
    }

    case 'SKIP_EXERCISE': {
      const { sessionExerciseId, personId, reason } = action.payload
      const session = state.session
      if (!session) return state
      const exercises = session.exercises.map((e) => {
        if (e.id !== sessionExerciseId) return e
        const others = e.appliesTo.filter((id) => id !== personId)
        return {
          ...e,
          activePersonId: others[0] || e.activePersonId,
          perPerson: {
            ...e.perPerson,
            [personId]: { ...e.perPerson[personId], status: 'skipped', skipReason: reason || null },
          },
        }
      })
      return { ...state, session: { ...session, exercises } }
    }

    case 'SUBSTITUTE_EXERCISE': {
      const { sessionExerciseId, personId, substituteExerciseId } = action.payload
      const session = state.session
      if (!session) return state
      const exercises = session.exercises.map((e) =>
        e.id === sessionExerciseId
          ? {
              ...e,
              perPerson: {
                ...e.perPerson,
                [personId]: { ...e.perPerson[personId], substituteExerciseId },
              },
            }
          : e,
      )
      return { ...state, session: { ...session, exercises } }
    }

    case 'ADD_SESSION_EXERCISE': {
      const { exerciseId, assignment } = action.payload
      const session = state.session
      if (!session) return state
      const owner = ownerOf(state)
      const partner = partnerOf(state)
      const people = appliesTo(assignment, session.participantIds, owner, partner)
      if (people.length === 0) return state
      const perPerson = {}
      people.forEach((pid) => {
        perPerson[pid] = { status: 'pending', skipReason: null, substituteExerciseId: null }
      })
      const se = {
        id: uid('se'),
        exerciseId,
        appliesTo: people,
        loggingMode: session.loggingStyle,
        perPerson,
        activePersonId: people[0],
        addedDuringSession: true,
      }
      return { ...state, session: { ...session, exercises: [...session.exercises, se] } }
    }

    case 'SET_LOGGING_MODE': {
      const { sessionExerciseId, mode } = action.payload
      const session = state.session
      if (!session) return state
      const exercises = session.exercises.map((e) =>
        e.id === sessionExerciseId ? { ...e, loggingMode: mode } : e,
      )
      return { ...state, session: { ...session, exercises } }
    }

    case 'SET_ACTIVE_ROW': {
      const { sessionExerciseId, personId } = action.payload
      const session = state.session
      if (!session) return state
      const exercises = session.exercises.map((e) =>
        e.id === sessionExerciseId ? { ...e, activePersonId: personId } : e,
      )
      return { ...state, session: { ...session, exercises } }
    }

    case 'CLEAR_SNACKBAR':
      return { ...state, snackbar: null }

    case 'FINISH_SESSION': {
      const session = state.session
      if (!session) return state
      const finished = { ...session, endTime: Date.now(), status: 'finished' }
      return {
        ...state,
        session: null,
        lastSummary: finished,
        history: [finished, ...state.history],
        snackbar: null,
      }
    }

    case 'DISMISS_SUMMARY':
      return { ...state, lastSummary: null }

    default:
      return state
  }
}
