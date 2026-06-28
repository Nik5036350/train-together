import { useRef } from 'react'

// The big tappable input wells used on the logging card. Tapping the value lets
// you type; the −/+ controls step it. `accentBorder` highlights the well for the
// active participant's row.
export function ValueInput({ label, value, onChange, step = 1, min = 0, accent, accentBorder }) {
  const inputRef = useRef(null)
  const display = value === '' || value == null ? '' : value

  const bump = (dir) => {
    const next = Math.max(min, round((Number(value) || 0) + dir * step))
    onChange(next)
  }

  return (
    <div
      style={{
        flex: 1,
        background: '#F4F5F7',
        border: accentBorder
          ? `1px solid ${accent}55`
          : '1px solid rgba(15,17,21,.08)',
        borderRadius: 12,
        padding: '8px 10px 9px',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
        <input
          ref={inputRef}
          className="num"
          inputMode="decimal"
          value={display}
          onChange={(e) => {
            const raw = e.target.value.replace(/[^0-9.]/g, '')
            onChange(raw === '' ? '' : Number(raw))
          }}
          style={{
            width: '100%',
            border: 'none',
            outline: 'none',
            background: 'transparent',
            fontFamily: "'Archivo', sans-serif",
            fontWeight: 700,
            fontSize: 25,
            padding: 0,
            color: '#0F1115',
          }}
        />
        <span style={{ fontSize: 13, color: '#9AA0AC', fontWeight: 600 }}>{label}</span>
      </div>
      <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
        <StepBtn onClick={() => bump(-1)}>−</StepBtn>
        <StepBtn onClick={() => bump(1)}>+</StepBtn>
      </div>
    </div>
  )
}

function StepBtn({ children, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        flex: 1,
        height: 22,
        borderRadius: 7,
        background: '#fff',
        border: '1px solid rgba(15,17,21,.08)',
        fontSize: 15,
        fontWeight: 700,
        color: '#5B616E',
        lineHeight: 1,
      }}
    >
      {children}
    </button>
  )
}

function round(n) {
  return Math.round(n * 100) / 100
}
