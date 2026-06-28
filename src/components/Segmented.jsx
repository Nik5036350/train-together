// Segmented control. Two visual variants:
//  - 'pill'  : light grey track with a white selected pill (unit toggle)
//  - 'cards' : separate rounded buttons, selected one is dark (logging style)
export function Segmented({ options, value, onChange, variant = 'pill' }) {
  if (variant === 'cards') {
    return (
      <div style={{ display: 'flex', gap: 9 }}>
        {options.map((o) => {
          const selected = o.value === value
          return (
            <button
              key={o.value}
              onClick={() => onChange(o.value)}
              style={{
                flex: 1,
                padding: 12,
                borderRadius: 11,
                background: selected ? '#0F1115' : '#fff',
                color: selected ? '#fff' : '#5B616E',
                border: selected ? 'none' : '1px solid rgba(15,17,21,.10)',
                fontWeight: selected ? 700 : 600,
                fontSize: 14,
                textAlign: 'center',
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
    <div style={{ display: 'flex', background: '#E9EAEC', borderRadius: 11, padding: 3 }}>
      {options.map((o) => {
        const selected = o.value === value
        return (
          <button
            key={o.value}
            onClick={() => onChange(o.value)}
            style={{
              flex: 1,
              textAlign: 'center',
              padding: 9,
              borderRadius: 8,
              background: selected ? '#fff' : 'transparent',
              fontWeight: selected ? 700 : 600,
              fontSize: 14,
              color: selected ? '#0F1115' : '#9AA0AC',
              boxShadow: selected ? '0 1px 2px rgba(0,0,0,.06)' : 'none',
            }}
          >
            {o.label}
          </button>
        )
      })}
    </div>
  )
}
