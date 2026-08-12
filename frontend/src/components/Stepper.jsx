import { useState } from 'react'
import { BORDER, COLORS, FONTS, RADII } from '../theme.js'

// The big tappable input wells on the logging card, styled as functional
// equipment labels (guide §11): uppercase label above the field, Canvas well,
// 2px Ink border, and a focus ring in the active person's color. Tapping the
// value lets you type; the −/+ blocks step it.
export function ValueInput({ label, value, onChange, step = 1, min = 0, accent, accentBorder }) {
  const [focused, setFocused] = useState(false)
  const display = value === '' || value == null ? '' : value
  const ring = focused && accent ? accent : accentBorder && accent ? accent : COLORS.rule

  const bump = (dir) => {
    const next = Math.max(min, round((Number(value) || 0) + dir * step))
    onChange(next)
  }

  return (
    <div style={{ flex: 1, minWidth: 0 }}>
      <div className="meta" style={{ color: COLORS.textSecondary, marginBottom: 5, fontSize: 11 }}>
        {label}
      </div>
      <div
        style={{
          background: COLORS.card,
          border: `${BORDER}px solid ${ring}`,
          borderRadius: RADII.sm,
          padding: '6px 10px 8px',
          // A focused field gains a second ring rather than a glow.
          boxShadow: focused && accent ? `inset 0 0 0 2px ${accent}33` : 'none',
        }}
      >
        <input
          className="num"
          inputMode="decimal"
          value={display}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onChange={(e) => {
            const raw = e.target.value.replace(/[^0-9.]/g, '')
            onChange(raw === '' ? '' : Number(raw))
          }}
          style={{
            width: '100%',
            border: 'none',
            outline: 'none',
            background: 'transparent',
            fontFamily: FONTS.heading,
            fontWeight: 800,
            fontSize: 30,
            lineHeight: 1.1,
            padding: 0,
            color: COLORS.text,
          }}
        />
        <div style={{ display: 'flex', gap: 6, marginTop: 7 }}>
          <StepBtn onClick={() => bump(-1)} ariaLabel={`Decrease ${label}`}>
            −
          </StepBtn>
          <StepBtn onClick={() => bump(1)} ariaLabel={`Increase ${label}`}>
            +
          </StepBtn>
        </div>
      </div>
    </div>
  )
}

function StepBtn({ children, onClick, ariaLabel }) {
  return (
    <button
      onClick={onClick}
      aria-label={ariaLabel}
      style={{
        flex: 1,
        height: 26,
        borderRadius: RADII.sm - 2,
        background: COLORS.appBg,
        border: `${BORDER}px solid ${COLORS.rule}`,
        fontFamily: FONTS.heading,
        fontSize: 16,
        fontWeight: 700,
        color: COLORS.text,
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
