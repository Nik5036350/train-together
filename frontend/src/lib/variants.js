// Training variants an exercise can be logged under. Each variant keeps its own
// history line (LAST TIME, repeat defaults, set numbering). The backend stores
// the value as an opaque string, so adding a variant here is the only change
// needed to introduce a new one.
export const VARIANTS = [
  { value: 'normal', label: 'Normal' },
  { value: 'highReps', label: 'High Reps' },
  { value: 'maxWeight', label: 'Max Weight' },
]

// Sets and session exercises from before this feature have no variant field.
export const variantLabel = (v) =>
  VARIANTS.find((o) => o.value === (v || 'normal'))?.label || v
