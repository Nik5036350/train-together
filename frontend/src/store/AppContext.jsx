import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { api } from '../lib/api.js'

const AppContext = createContext(null)

// The backend owns all business logic and returns the full aggregate state on
// every mutation. This store keeps that aggregate in React state and exposes the
// same `dispatch(action)` interface the screens already use, so screens are
// unchanged. Two things stay purely client-side (they were UI-only in the old
// reducer too): the `snackbar` toast and the `lastSummary` shown after finishing.
export function AppProvider({ children }) {
  const [server, setServer] = useState(null) // aggregate from the backend
  const [snackbar, setSnackbar] = useState(null)
  const [lastSummary, setLastSummary] = useState(null)
  const [error, setError] = useState(null)

  // Latest values for use inside the async dispatch without stale closures.
  const ref = useRef({ server: null, snackbar: null })
  ref.current = { server, snackbar }

  useEffect(() => {
    api.getState().then(setServer).catch((e) => setError(e.message))
  }, [])

  const dispatch = useCallback(async (action) => {
    const { server: state } = ref.current
    const session = state?.session
    try {
      switch (action.type) {
        // ---- onboarding / settings ----
        case 'SAVE_PARTNER':
          setServer(await api.savePartner(action.payload))
          break
        case 'UPDATE_PERSON':
          setServer(await api.updatePerson(action.payload.personId, action.payload.patch))
          break
        case 'UPDATE_SETTINGS':
          setServer(await api.updateSettings(action.payload))
          break
        case 'TOGGLE_COUPLE_MODE':
          setServer(await api.toggleCoupleMode())
          break

        // ---- exercise library ----
        case 'CREATE_EXERCISE': {
          const { exercise, profiles } = action.payload
          const body = {
            name: exercise.name,
            category: exercise.category || '',
            equipment: exercise.equipment || '',
            tracks: exercise.tracks,
            defaultRestSeconds: exercise.defaultRestSeconds ?? 90,
            profiles: profiles || {},
          }
          setServer(exercise.id ? await api.updateExercise(exercise.id, body) : await api.createExercise(body))
          break
        }
        case 'DELETE_EXERCISE':
          setServer(await api.deleteExercise(action.payload.exerciseId))
          break

        // ---- templates ----
        case 'SAVE_TEMPLATE': {
          const tpl = action.payload
          const body = { name: tpl.name, defaultMode: tpl.defaultMode, exercises: tpl.exercises || [] }
          setServer(tpl.id ? await api.updateTemplate(tpl.id, body) : await api.createTemplate(body))
          break
        }
        case 'DELETE_TEMPLATE':
          setServer(await api.deleteTemplate(action.payload.templateId))
          break
        case 'SET_ASSIGNMENT':
          setServer(await api.setAssignment(action.payload.templateId, action.payload.exerciseId, action.payload.assignment))
          break

        // ---- session lifecycle ----
        case 'START_SESSION':
          setSnackbar(null)
          setServer(await api.startSession(action.payload))
          break
        case 'FINISH_SESSION': {
          if (!session) break
          const finishedId = session.id
          const next = await api.finishSession(finishedId)
          setServer(next)
          setSnackbar(null)
          setLastSummary(next.history.find((h) => h.id === finishedId) || null)
          break
        }
        case 'DISMISS_SUMMARY':
          setLastSummary(null)
          break

        // ---- logging ----
        case 'LOG_SET': {
          if (!session) break
          const { sessionExerciseId, personId, values, setType, source } = action.payload
          const se = session.exercises.find((e) => e.id === sessionExerciseId)
          const prevActive = se?.activePersonId
          const next = await api.logSet(session.id, { sessionExerciseId, personId, values, setType })
          setServer(next)
          // Synthesize the confirmation toast (client-only, as before). The new
          // set is the highest-index one for this person + session-exercise.
          const mine = (next.session?.sets || []).filter(
            (s) => s.sessionExerciseId === sessionExerciseId && s.personId === personId,
          )
          const newSet = mine.sort((a, b) => b.setIndex - a.setIndex)[0]
          setSnackbar({
            id: `snk_${Date.now()}`,
            setId: newSet?.id,
            personId,
            sessionExerciseId,
            prevActivePersonId: prevActive,
            kind: source === 'repeat' ? 'repeat' : 'log',
            undoable: true,
            createdAt: Date.now(),
            person: next.people.find((p) => p.id === personId)?.name,
          })
          break
        }
        case 'UNDO_LAST': {
          const snk = ref.current.snackbar
          if (!session || !snk?.setId) break
          setServer(await api.undoSet(session.id, snk.setId))
          setSnackbar(null)
          break
        }
        case 'CLEAR_SNACKBAR':
          setSnackbar(null)
          break

        // ---- set editing (active + history, unified by owning session) ----
        case 'EDIT_SET':
          setServer(await api.editSet(session.id, action.payload.setId, action.payload.values))
          break
        case 'DELETE_SET':
          setServer(await api.deleteSet(session.id, action.payload.setId))
          break
        case 'REASSIGN_SET':
          setServer(await api.reassignSet(session.id, action.payload.setId, action.payload.toPersonId))
          break
        case 'EDIT_HISTORY_SET':
          setServer(await api.editSet(action.payload.sessionId, action.payload.setId, action.payload.values))
          break
        case 'DELETE_HISTORY_SET':
          setServer(await api.deleteSet(action.payload.sessionId, action.payload.setId))
          break
        case 'REASSIGN_HISTORY_SET':
          setServer(await api.reassignSet(action.payload.sessionId, action.payload.setId, action.payload.toPersonId))
          break

        // ---- in-session per-person mutations ----
        case 'SET_PERSON_STATUS':
          setServer(await api.personStatus(action.payload.sessionExerciseId, {
            personId: action.payload.personId,
            status: action.payload.status,
          }))
          break
        case 'SKIP_TURN': {
          const { sessionExerciseId, personId } = action.payload
          const next = await api.skipTurn(sessionExerciseId, personId)
          setServer(next)
          setSnackbar({
            id: `snk_${Date.now()}`,
            kind: 'skipturn',
            personId,
            sessionExerciseId,
            undoable: false,
            createdAt: Date.now(),
            person: next.people.find((p) => p.id === personId)?.name,
          })
          break
        }
        case 'SKIP_EXERCISE':
          setServer(await api.skipExercise(action.payload.sessionExerciseId, {
            personId: action.payload.personId,
            reason: action.payload.reason,
          }))
          break
        case 'SUBSTITUTE_EXERCISE':
          setServer(await api.substitute(action.payload.sessionExerciseId, {
            personId: action.payload.personId,
            substituteExerciseId: action.payload.substituteExerciseId,
          }))
          break
        case 'ADD_SESSION_EXERCISE':
          setServer(await api.addSessionExercise(session.id, {
            exerciseId: action.payload.exerciseId,
            assignment: action.payload.assignment,
          }))
          break
        case 'SET_LOGGING_MODE':
          setServer(await api.loggingMode(action.payload.sessionExerciseId, action.payload.mode))
          break
        case 'SET_ACTIVE_ROW':
          setServer(await api.activeRow(action.payload.sessionExerciseId, action.payload.personId))
          break

        // ---- admin / backup ----
        case 'RESET_DEMO':
          setSnackbar(null)
          setLastSummary(null)
          setServer(await api.resetDemo())
          break
        case 'RESTORE_DEMO_ROUTINE':
          setServer(await api.restoreDemoRoutine())
          break
        case 'HYDRATE':
          setSnackbar(null)
          setLastSummary(null)
          setServer(await api.importState(action.state))
          break

        default:
          break
      }
    } catch (e) {
      setError(e.message)
      // eslint-disable-next-line no-console
      console.error('dispatch failed', action.type, e)
    }
  }, [])

  // Overlay the client-only UI bits onto the server aggregate.
  const state = useMemo(
    () => (server ? { ...server, snackbar, lastSummary } : null),
    [server, snackbar, lastSummary],
  )

  if (error && !server) {
    return (
      <div style={{ padding: 40, fontFamily: 'system-ui', color: '#b00' }}>
        Couldn’t reach the backend. Is it running on port 8080?
        <div style={{ marginTop: 8, fontSize: 12, color: '#888' }}>{error}</div>
      </div>
    )
  }
  if (!state) {
    return <div style={{ padding: 40, fontFamily: 'system-ui', color: '#888' }}>Loading…</div>
  }

  return <AppContext.Provider value={{ state, dispatch }}>{children}</AppContext.Provider>
}

export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used within <AppProvider>')
  return ctx
}
