import { COLORS, FONTS } from '../theme.js'

// A number and what it counts (guide §24) — numerals are a central visual asset,
// so the value is large and condensed and the label is small, uppercase meta.
export function StatBlock({ value, label, size = 30, tone = 'light', flex = 1, align = 'left' }) {
  const valueColor = tone === 'dark' ? COLORS.onDark : tone === 'accent' ? COLORS.primaryText : COLORS.text
  const labelColor = tone === 'dark' ? COLORS.onDarkMuted : COLORS.textSecondary

  return (
    <div style={{ flex, textAlign: align, minWidth: 0 }}>
      <div
        className="num"
        style={{
          fontFamily: FONTS.heading,
          fontWeight: 800,
          fontSize: size,
          lineHeight: 1,
          letterSpacing: '-0.01em',
          color: valueColor,
        }}
      >
        {value}
      </div>
      <div className="meta" style={{ color: labelColor, marginTop: 5, fontSize: 11 }}>
        {label}
      </div>
    </div>
  )
}
