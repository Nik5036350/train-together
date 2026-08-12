import { COLORS } from '../theme.js'

// Uppercase section header over a bold rule — the system separates content with
// rules rather than whitespace or card shadows (guide §3, §12). `action` is an
// optional right-aligned control (e.g. "View all").
export function SectionLabel({ children, action, rule = true, tone = 'light', style }) {
  const color = tone === 'dark' ? COLORS.onDarkMuted : COLORS.textSecondary
  return (
    <div style={{ ...style }}>
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
        <span className="meta" style={{ color }}>
          {children}
        </span>
        {action}
      </div>
      {rule && (
        <div
          style={{
            height: 2,
            background: tone === 'dark' ? COLORS.onDarkMuted : COLORS.rule,
            marginTop: 5,
          }}
        />
      )}
    </div>
  )
}
