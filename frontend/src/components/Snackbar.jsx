import { useEffect } from 'react'
import { BORDER, COLORS, FONTS, RADII, personPalette } from '../theme.js'

// Confirmation toast shown after every log action (PRD FR-106), on an Ink
// surface with a square swatch in the acting person's color. Includes Undo (and
// Edit, when an editor is wired). Auto-dismisses after a delay.
export function Snackbar({ snackbar, person, text, onUndo, onEdit, onDismiss }) {
  useEffect(() => {
    if (!snackbar) return undefined
    const id = setTimeout(onDismiss, 6000)
    return () => clearTimeout(id)
  }, [snackbar, onDismiss])

  if (!snackbar) return null
  const pal = personPalette(person)

  return (
    <div
      style={{
        background: COLORS.darkSurface,
        border: `${BORDER}px solid ${COLORS.rule}`,
        borderLeft: `6px solid ${pal.accent}`,
        borderRadius: RADII.sm,
        padding: '11px 13px',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        animation: 'snackbar-in var(--motion-default) var(--ease-default)',
      }}
    >
      <span
        style={{ flex: 1, fontSize: 13, color: COLORS.onDark, lineHeight: 1.35 }}
        dangerouslySetInnerHTML={{ __html: text }}
      />
      {snackbar.undoable && (
        <button
          onClick={onUndo}
          style={{
            fontFamily: FONTS.heading,
            fontSize: 14,
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '0.04em',
            color: COLORS.onDark,
            borderBottom: `2px solid ${COLORS.primary}`,
            paddingBottom: 1,
          }}
        >
          Undo
        </button>
      )}
      {onEdit && (
        <button
          onClick={onEdit}
          style={{
            fontFamily: FONTS.heading,
            fontSize: 14,
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '0.04em',
            color: COLORS.onDarkMuted,
          }}
        >
          Edit
        </button>
      )}
    </div>
  )
}
