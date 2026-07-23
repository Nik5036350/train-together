import { useEffect, useState } from 'react'

// Ticks once per second so any component showing a live countdown / elapsed
// time re-renders. Returns Date.now(). Used by rest timers and the session
// clock. Only one interval per component instance.
export function useNow(active = true, intervalMs = 1000) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    if (!active) return undefined
    const id = setInterval(() => setNow(Date.now()), intervalMs)
    return () => clearInterval(id)
  }, [active, intervalMs])
  return now
}

// Derive a rest-timer's display state from its record + the current time.
// states: 'ready' (no timer or elapsed), 'resting' (counting down),
// 'overdue' (past rest by > grace).
export function timerState(timer, now) {
  if (!timer) return { state: 'none', remaining: 0 }
  const elapsed = (now - timer.startedAt) / 1000
  const remaining = timer.durationSeconds - elapsed
  if (remaining > 0) return { state: 'resting', remaining }
  if (remaining > -30) return { state: 'ready', remaining: 0 }
  return { state: 'overdue', remaining: 0, over: -remaining }
}
