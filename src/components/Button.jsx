import { COLORS } from '../theme.js'

// Primary pill CTA used across the app. `color` overrides the fill (e.g. a
// person's identity color for "Log for Alex").
export function PrimaryButton({ children, onClick, color = COLORS.primary, shadow, style, disabled }) {
  return (
    <button
      onClick={disabled ? undefined : onClick}
      style={{
        height: 50,
        width: '100%',
        borderRadius: 13,
        background: disabled ? '#C8CBD1' : color,
        color: '#fff',
        fontFamily: "'Archivo', sans-serif",
        fontWeight: 700,
        fontSize: 16,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        boxShadow: disabled ? 'none' : shadow || '0 4px 14px rgba(43,102,224,.24)',
        cursor: disabled ? 'default' : 'pointer',
        ...style,
      }}
    >
      {children}
    </button>
  )
}

// Secondary outlined / ghost button.
export function GhostButton({ children, onClick, style }) {
  return (
    <button
      onClick={onClick}
      style={{
        height: 48,
        width: '100%',
        borderRadius: 12,
        background: '#fff',
        border: '1px solid rgba(15,17,21,.12)',
        fontWeight: 700,
        fontSize: 15,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        ...style,
      }}
    >
      {children}
    </button>
  )
}
