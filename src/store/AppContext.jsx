import { createContext, useContext, useEffect, useReducer } from 'react'
import { reducer } from './reducer.js'
import { makeInitialState, SEED_VERSION } from './seed.js'

const STORAGE_KEY = 'couples-recording-mode/v1'

const AppContext = createContext(null)

// Load persisted state, falling back to a fresh seed when absent or stale.
function init() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw)
      if (parsed && parsed.version === SEED_VERSION) return parsed
    }
  } catch {
    // ignore corrupt storage and reseed
  }
  return makeInitialState()
}

export function AppProvider({ children }) {
  const [state, dispatch] = useReducer(reducer, undefined, init)

  // Persist the whole store on every change (offline/local MVP, restores an
  // in-progress session after a reload — PRD §10 "App closes during workout").
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    } catch {
      // storage full / unavailable — non-fatal
    }
  }, [state])

  return <AppContext.Provider value={{ state, dispatch }}>{children}</AppContext.Provider>
}

export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used within <AppProvider>')
  return ctx
}
