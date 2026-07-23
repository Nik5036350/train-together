// Formatting helpers for displaying logged performance.

// Render a single set as the compact "80×8" chip used across the design.
export function setChip(set, exercise) {
  const tracks = exercise?.tracks || {}
  if (tracks.duration && !tracks.reps) {
    return formatDuration(set.duration)
  }
  if (tracks.weight && tracks.reps) {
    return `${trimNum(set.weight)}×${set.reps}`
  }
  if (tracks.reps) {
    return `${set.reps}`
  }
  if (tracks.duration) {
    return formatDuration(set.duration)
  }
  return `${trimNum(set.weight ?? 0)}`
}

// "Logged Alex · 80 kg × 8" style summary used in the snackbar.
export function setSummary(set, exercise, unit = 'kg') {
  const tracks = exercise?.tracks || {}
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
