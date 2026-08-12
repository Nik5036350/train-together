// Design tokens for the Constructivist visual system defined in
// `styleguide/train-together-style-guide.md`. The hex values here mirror
// the `:root` custom properties in styles.css — this module exists because the
// app styles almost everything with inline styles, which cannot read CSS vars.
// Keep the two in sync.

export const COLORS = {
  // Surfaces
  appBg: '#F1E6D0', // Paper — main warm background
  card: '#FAF5EA', // Canvas — cards, inputs, elevated light surfaces
  inset: '#F1E6D0', // inset wells inside cards
  darkSurface: '#181816', // Ink — snackbar, resume card, dark blocks
  darkBackdrop: '#181816', // start-workout sheet backdrop

  // Text
  text: '#181816', // Ink
  // The guide lists Concrete (#A69D8D) as "secondary text", but on Canvas that
  // is ~2.3:1 and fails the WCAG requirement the same guide sets in §29. So
  // Concrete is reserved for inactive UI / rules / disabled, and secondary text
  // uses these warm ink tints instead (~5.2:1 and ~4.6:1 on Canvas).
  textSecondary: '#6B665C',
  // Muted and secondary text converge: anything lighter than this drops below
  // 4.5:1 on Paper. Kept as its own token because the roles differ.
  textMuted: '#6B665C',
  onDark: '#F1E6D0', // Paper text on Ink surfaces
  onDarkMuted: 'rgba(241,230,208,.62)',
  // Canvas rather than Paper for text on a red fill — Paper lands at 4.40:1 on
  // Revolution Red, just under AA; Canvas clears it at 5.00:1.
  onAccent: '#FAF5EA',

  // Rules — the system separates with borders, not shadows.
  rule: '#181816',
  ruleSoft: '#A69D8D', // Concrete, for secondary separation

  // Semantic
  primary: '#C92C1C', // Revolution Red — primary action (fills)
  primaryPress: '#8F1E16', // Signal Red Dark — pressed state
  // Red *text* on a light surface uses Signal Red Dark: Revolution Red is only
  // 4.40:1 on Paper, which fails AA at label sizes.
  primaryText: '#8F1E16',
  steel: '#3F6070',
  success: '#52634B', // Field Green — ready / complete
  warning: '#C48A28', // Mustard
  disabled: '#A69D8D', // Concrete
}

// The two participants' identity colors. Revolution Red and Steel Blue are the
// primary pairing (guide §4.2) — equal but distinct, never blended.
//
// `accent` fills identity blocks, `onAccent` is text drawn on top of it, `tint`
// is a wash for secondary surfaces, `text` is the darkened variant that stays
// readable on that tint, and `press` is the active/pressed fill.
export const PERSON_COLORS = {
  red: {
    accent: '#C92C1C',
    onAccent: '#FAF5EA',
    text: '#8F1E16',
    tint: '#F4DFDA',
    press: '#8F1E16',
  },
  steel: {
    accent: '#3F6070',
    onAccent: '#FAF5EA',
    text: '#2F4855',
    tint: '#DFE6E9',
    press: '#2F4855',
  },
  mustard: {
    accent: '#C48A28',
    onAccent: '#181816',
    text: '#7A5514',
    tint: '#F6EAD3',
    press: '#9A6C1B',
  },
  green: {
    accent: '#52634B',
    onAccent: '#FAF5EA',
    text: '#3B4837',
    tint: '#E4E9E1',
    press: '#3B4837',
  },
  concrete: {
    accent: '#A69D8D',
    onAccent: '#181816',
    text: '#5E574C',
    tint: '#EDE8DF',
    press: '#8A8272',
  },
}

// Person color is stored data — the seed writes "blue" for Alex and "orange"
// for Maria (backend/src/services/seed.rs), and any database created before the
// redesign holds the old five keys. Rather than migrate, old keys resolve onto
// the closest brand identity so existing rows keep rendering.
const LEGACY_COLOR_ALIASES = {
  blue: 'steel',
  orange: 'red',
  purple: 'steel',
  pink: 'red',
}

// The keys offered in the person color pickers, in display order.
export const PERSON_COLOR_KEYS = ['red', 'steel', 'mustard', 'green', 'concrete']

// Map any stored color key (current or legacy) onto a brand key. Pickers use
// this so a partner still holding a legacy "blue" correctly marks Steel Blue as
// taken rather than letting both people end up the same color.
export function resolveColorKey(key) {
  if (PERSON_COLORS[key]) return key
  return LEGACY_COLOR_ALIASES[key] || 'steel'
}

// Resolve a person's color palette from their stored `color` key.
export function personPalette(person) {
  return PERSON_COLORS[resolveColorKey(person?.color)]
}

export const FONTS = {
  // Display / headings / all numerals — poster-like authority (guide §5.1).
  heading: "'Roboto Condensed', 'IBM Plex Sans Condensed', system-ui, sans-serif",
  // Body / UI text (guide §5.2).
  body: "'Inter', 'IBM Plex Sans', system-ui, sans-serif",
}

// Type scale from guide §5.3.
export const TYPE = {
  displayXl: 64,
  display: 44,
  section: 24,
  title: 19,
  body: 16,
  label: 14,
  meta: 12,
}

// Corner radii — used sparingly; the system avoids pill shapes entirely.
export const RADII = {
  sm: 6,
  md: 8,
  lg: 12,
}

// Clear borders instead of soft shadows (guide §7.2).
export const BORDER = 2

export const MOTION = {
  fast: '120ms',
  default: '160ms',
  slow: '180ms',
  ease: 'ease-out',
}
