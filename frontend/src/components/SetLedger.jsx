import { COLORS, FONTS } from '../theme.js'
import { setSummary } from '../lib/format.js'
import { Icon } from './Icon.jsx'

// Sets as a numbered ledger (guide §15) rather than tiny chips: the ordinal
// stays prominent, a rule carries the eye across to the values, and each
// completed set reads as a structural confirmation.
//
//   01 ──── 60 KG × 10 ✓   02 ──── 65 KG × 8 ✓
//
// Rows are laid out in two columns and kept to ~20px each — a full set history
// otherwise pushes the inputs and the log button off screen, and on the logging
// card the sets are reference material, not the main event. Drops to one column
// when the values are too wide to pair up.
//
// `onEdit` keeps the existing tap-to-edit behavior; without it rows are static
// (used for the read-only "last time" block).
export function SetLedger({ sets, exercise, unit, palette, onEdit, muted = false }) {
  const rendered = sets.map((set) => ({ set, text: setSummary(set, exercise, unit) || '—' }))
  // Duration-style values ("1:30 · 2:00") and heavy three-digit loads are the
  // long cases; pairing those would clip, so give them the full width.
  const longest = rendered.reduce((n, r) => Math.max(n, r.text.length), 0)
  const columns = longest > 13 ? 1 : 2

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`,
        columnGap: 16,
      }}
    >
      {rendered.map(({ set, text }, i) => (
        <SetRow
          key={set.id}
          set={set}
          index={i}
          text={text}
          palette={palette}
          muted={muted}
          onEdit={onEdit}
          // Only the first row of each column skips its divider.
          firstInColumn={i < columns}
        />
      ))}
    </div>
  )
}

function SetRow({ set, index, text, palette, muted, onEdit, firstInColumn }) {
  const Tag = onEdit ? 'button' : 'div'
  const accent = muted ? COLORS.textSecondary : palette?.accent || COLORS.text

  return (
    <Tag
      onClick={
        onEdit
          ? (e) => {
              e.stopPropagation()
              onEdit(set.id)
            }
          : undefined
      }
      title={onEdit ? 'Edit this set' : undefined}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 7,
        width: '100%',
        padding: '3px 0',
        textAlign: 'left',
        borderTop: firstInColumn ? 'none' : `1px solid ${COLORS.ruleSoft}`,
        color: muted ? COLORS.textSecondary : COLORS.text,
      }}
    >
      <span
        className="num display"
        style={{ fontSize: 13, lineHeight: 1.15, color: accent, minWidth: 17 }}
      >
        {String(index + 1).padStart(2, '0')}
      </span>
      {/* the rule that carries the eye from ordinal to values */}
      <span
        style={{
          flex: 1,
          minWidth: 6,
          height: 1,
          background: muted ? COLORS.ruleSoft : COLORS.rule,
          opacity: muted ? 0.6 : 0.75,
        }}
      />
      {set.note && (
        <span style={{ color: COLORS.textMuted, display: 'flex' }} title={set.note}>
          <Icon name="pencil" size={9} />
        </span>
      )}
      <span
        className="num"
        style={{
          fontFamily: FONTS.heading,
          fontWeight: 700,
          fontSize: 13,
          lineHeight: 1.15,
          textTransform: 'uppercase',
          letterSpacing: '0.01em',
          whiteSpace: 'nowrap',
        }}
      >
        {text}
      </span>
      {onEdit && (
        <span style={{ color: accent, display: 'flex', flexShrink: 0 }}>
          <Icon name="check" size={9} />
        </span>
      )}
    </Tag>
  )
}
