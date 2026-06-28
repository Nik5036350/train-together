// Design tokens extracted directly from the Claude Design mockups
// (design-for-prd/project/Couples Mode.dc.html). These px/hex values are the
// visual spec — keep them in sync with that file.

export const COLORS = {
  // Surfaces
  appBg: '#F4F5F7',
  card: '#FFFFFF',
  inset: '#F4F5F7', // inset wells inside cards
  darkSurface: '#16191F', // summary hero card / snackbar
  darkBackdrop: '#1A1C22', // start-workout sheet backdrop

  // Text
  text: '#0F1115',
  textSecondary: '#5B616E',
  textMuted: '#9AA0AC',
  hairline: 'rgba(15,17,21,.06)',
  hairlineStrong: 'rgba(15,17,21,.12)',

  // Semantic
  primary: '#2B66E0', // primary CTA (also Alex / owner)
  success: '#15935C', // ready / complete green
}

// The two participants' identity colors. Owner = blue, Partner = orange.
export const PERSON_COLORS = {
  blue: {
    accent: '#2B66E0',
    text: '#2B66E0',
    tint: '#EEF3FD',
    shadow: 'rgba(43,102,224,.26)',
  },
  orange: {
    accent: '#E2702C',
    text: '#C2570C', // darker variant for readable text on light tint
    tint: '#FBF1E9',
    shadow: 'rgba(226,112,44,.26)',
  },
  // Additional picker options shown on the partner-setup screen.
  purple: { accent: '#7C3AED', text: '#6D28D9', tint: '#F1ECFE', shadow: 'rgba(124,58,237,.26)' },
  green: { accent: '#15935C', text: '#0F7A4A', tint: '#E7F4EE', shadow: 'rgba(21,147,92,.26)' },
  pink: { accent: '#D6336C', text: '#B02458', tint: '#FCEAF1', shadow: 'rgba(214,51,108,.26)' },
}

export const FONTS = {
  heading: "'Archivo', system-ui, sans-serif",
  body: "'Hanken Grotesk', system-ui, sans-serif",
}

export const RADII = {
  card: 16,
  cardSm: 14,
  input: 12,
  chip: 8,
  pill: 9999,
}

// Resolve a person's color palette from their stored `color` key.
export function personPalette(person) {
  return PERSON_COLORS[person?.color] || PERSON_COLORS.blue
}
