// Small monotonic id generator. Avoids pulling in a uuid dependency for a
// local-only app and keeps ids readable in devtools / localStorage.
let counter = 0

export function uid(prefix = 'id') {
  counter += 1
  return `${prefix}_${Date.now().toString(36)}_${counter.toString(36)}`
}
