import { BORDER, COLORS, FONTS, RADII } from '../theme.js'

// Bottom-sheet modal. Used for skip, substitute, add-exercise, change-mode, and
// finish confirmations. Sheets are one of the few surfaces allowed any elevation
// at all (guide §7.3), and even here it stays slight — the 2px Ink edge does the
// separating work.
export function Sheet({ open, onClose, title, children }) {
  if (!open) return null
  return (
    <div
      onClick={onClose}
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 80,
        background: 'rgba(24,24,22,.55)',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
        animation: 'fade-in var(--motion-fast) var(--ease-default)',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: COLORS.appBg,
          borderTop: `${BORDER}px solid ${COLORS.rule}`,
          borderRadius: `${RADII.lg}px ${RADII.lg}px 0 0`,
          padding: '12px 20px 36px',
          animation: 'sheet-up var(--motion-slow) var(--ease-default)',
          maxHeight: '88%',
          overflow: 'auto',
          boxShadow: '0 -6px 20px rgba(24,24,22,.10)',
        }}
        className="scroll-area"
      >
        <div
          style={{
            width: 40,
            height: 4,
            background: COLORS.rule,
            margin: '0 auto 18px',
          }}
        />
        {title && (
          <div
            className="display"
            style={{
              fontFamily: FONTS.heading,
              fontSize: 24,
              textTransform: 'uppercase',
              letterSpacing: '0.02em',
              marginBottom: 8,
            }}
          >
            {title}
          </div>
        )}
        {title && <div style={{ height: 2, background: COLORS.rule, marginBottom: 16 }} />}
        {children}
      </div>
    </div>
  )
}
