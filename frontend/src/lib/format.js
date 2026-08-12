// Formatting helpers for displaying logged performance.

// "80 kg × 8" style summary, used by the snackbar and the set ledgers.
export function setSummary(set, exercise, unit = 'kg') {
  // History keeps sets whose exercise has since been deleted from the library.
  // With no `tracks` to consult we can't know what the exercise measured, so
  // fall back to whatever the set itself recorded — otherwise those rows render
  // blank and the logged numbers look lost.
  const tracks = exercise?.tracks || { weight: true, reps: true, duration: true }
  const parts = []
  if (tracks.weight && set.weight != null) parts.push(`${trimNum(set.weight)} ${unit}`)
  if (tracks.reps && set.reps != null) parts.push(`× ${set.reps}`)
  if (tracks.duration && set.duration != null) parts.push(formatDuration(set.duration))
  return parts.join(' ')
}

// Seconds → "mm:ss" (used for rest timers and short durations).
export function formatDuration(totalSeconds) {
  const s = Math.max(0, Math.round(totalSeconds || 0))
  const m = Math.floor(s / 60)
  const rem = s % 60
  return `${m}:${String(rem).padStart(2, '0')}`
}

// Seconds → "00:42". Same value as formatDuration, but zero-padded to a fixed
// width so the rest timer's digits never reflow as it counts down (guide §24).
export function formatClock(totalSeconds) {
  const s = Math.max(0, Math.round(totalSeconds || 0))
  const m = Math.floor(s / 60)
  const rem = s % 60
  return `${String(m).padStart(2, '0')}:${String(rem).padStart(2, '0')}`
}

// Elapsed milliseconds → "1:12" hours:minutes for the session timer / summary.
export function formatElapsed(ms) {
  const totalMin = Math.floor((ms || 0) / 60000)
  const h = Math.floor(totalMin / 60)
  const m = totalMin % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}`
  const s = Math.floor((ms || 0) / 1000) % 60
  return `${m}:${String(s).padStart(2, '0')}`
}

// Timestamp → "Mon, Jun 23" for workout history lists.
export function formatDate(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  return d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })
}

// Drop trailing ".0" so 80.0 shows as 80 but 77.5 stays 77.5.
export function trimNum(n) {
  if (n == null) return ''
  return Number.isInteger(n) ? String(n) : String(Number(n.toFixed(2)))
}

// Total volume (weight × reps) for a list of sets.
export function totalVolume(sets) {
  return sets.reduce((sum, s) => sum + (s.weight || 0) * (s.reps || 0), 0)
}
