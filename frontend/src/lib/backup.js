// JSON backup/restore for the whole store. All workout data lives in
// localStorage, which iOS can evict from an installed PWA after ~7 days of
// non-use — so let people pull a file out and put it back.

// Serialize the store and trigger a download. The date is stamped here (in the
// click handler), not at module load.
export function exportState(state) {
  const json = JSON.stringify(state, null, 2)
  const blob = new Blob([json], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  const stamp = new Date().toISOString().slice(0, 10) // YYYY-MM-DD
  a.href = url
  a.download = `train-together-backup-${stamp}.json`
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

// Parse + sanity-check an imported backup. Returns the parsed store on success,
// throws a friendly Error otherwise. The caller feeds the result to HYDRATE.
export function parseImport(text) {
  let parsed
  try {
    parsed = JSON.parse(text)
  } catch {
    throw new Error("That file isn't valid JSON.")
  }
  if (
    !parsed ||
    typeof parsed !== 'object' ||
    parsed.version == null ||
    !Array.isArray(parsed.people) ||
    !Array.isArray(parsed.history) ||
    typeof parsed.exercises !== 'object' ||
    typeof parsed.templates !== 'object'
  ) {
    // Only the shape is checked, never the name — backups exported under the
    // old "Couples Recording Mode" name still import fine.
    throw new Error("That doesn't look like a Train Together backup.")
  }
  return parsed
}
