import { useEffect } from 'react'
import { personPalette } from '../theme.js'

// Dark confirmation toast shown after every log action (PRD FR-106). Includes
// Undo (and Edit, when an editor is wired). Auto-dismisses after a delay.
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
        background: '#16191F',
        borderRadius: 12,
        padding: '12px 14px',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        boxShadow: '0 8px 22px rgba(0,0,0,.18)',
        animation: 'snackbar-in .2s ease',
      }}
    >
      <span style={{ width: 7, height: 7, borderRadius: '50%', background: pal.accent }} />
      <span style={{ flex: 1, fontSize: 13, color: '#fff' }} dangerouslySetInnerHTML={{ __html: text }} />
      {snackbar.undoable && (
        <button onClick={onUndo} style={{ fontSize: 13, fontWeight: 700, color: '#86AEF7' }}>
          Undo
        </button>
      )}
      {onEdit && (
        <button onClick={onEdit} style={{ fontSize: 13, fontWeight: 600, color: 'rgba(255,255,255,.55)' }}>
          Edit
        </button>
      )}
    </div>
  )
}
