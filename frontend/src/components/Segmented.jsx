import { BORDER, COLORS, FONTS, RADII } from '../theme.js'

// Segmented controls carry unit, mode and person selection (guide §11). Two
// visual variants, both flat and bordered — no pills, no sliding thumb:
//  - 'pill'  : one bordered track, the selected cell filled with Ink
//  - 'cards' : separate bordered blocks, the selected one filled with Ink
export function Segmented({ options, value, onChange, variant = 'pill' }) {
  const label = {
    fontFamily: FONTS.heading,
    fontWeight: 700,
    fontSize: 14,
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
    textAlign: 'center',
  }

  if (variant === 'cards') {
    return (
      <div style={{ display: 'flex', gap: 8 }}>
        {options.map((o) => {
          const selected = o.value === value
          return (
            <button
              key={o.value}
              onClick={() => onChange(o.value)}
              aria-pressed={selected}
              style={{
                ...label,
                flex: 1,
                minHeight: 44,
                padding: '10px 8px',
                borderRadius: RADII.md,
                background: selected ? COLORS.text : COLORS.card,
                color: selected ? COLORS.onDark : COLORS.text,
                border: `${BORDER}px solid ${COLORS.rule}`,
              }}
            >
              {o.label}
            </button>
          )
        })}
      </div>
    )
  }

  return (
    <div
      style={{
        display: 'flex',
        background: COLORS.card,
        border: `${BORDER}px solid ${COLORS.rule}`,
        borderRadius: RADII.md,
        overflow: 'hidden',
      }}
    >
      {options.map((o, i) => {
        const selected = o.value === value
        return (
          <button
            key={o.value}
            onClick={() => onChange(o.value)}
            aria-pressed={selected}
            style={{
              ...label,
              flex: 1,
              minHeight: 40,
              padding: '9px 6px',
              background: selected ? COLORS.text : 'transparent',
              color: selected ? COLORS.onDark : COLORS.textSecondary,
              borderLeft: i === 0 ? 'none' : `${BORDER}px solid ${COLORS.rule}`,
            }}
          >
            {o.label}
          </button>
        )
      })}
    </div>
  )
}
