import { COLORS, FONTS } from '../theme.js'
import { formatClock } from '../lib/format.js'

// Rest state → color + label. The label is not decoration: the guide forbids
// communicating state by color alone (§4.3, §29), so every ring carries its
// state in words as well.
const STATES = {
  resting: { color: COLORS.steel, label: 'RESTING' },
  ready: { color: COLORS.success, label: 'READY' },
  overdue: { color: COLORS.primary, labelColor: COLORS.primaryText, label: 'OVERDUE' },
  none: { color: COLORS.success, label: 'READY' },
}

// The signature rest timer (guide §14): thick circular progress ring, minimal
// radial marks, clear central time, crisp state change — no glow, no gloss.
//
// `ts` is the object returned by timerState() in lib/useNow.js; `total` is the
// timer's full rest duration, used to draw the remaining arc.
export function TimerRing({ ts, total, size = 88, stroke = 7 }) {
  const s = STATES[ts?.state] || STATES.none
  const remaining = ts?.state === 'resting' ? ts.remaining : 0
  const progress = total > 0 && remaining > 0 ? Math.min(1, remaining / total) : ts?.state === 'resting' ? 1 : 0

  const r = (size - stroke) / 2
  const circumference = 2 * Math.PI * r
  const timeText = ts?.state === 'overdue' ? formatClock(ts.over) : formatClock(remaining)

  return (
    <div
      style={{ width: size, height: size, position: 'relative', flexShrink: 0 }}
      role="timer"
      aria-label={`${s.label} ${timeText}`}
    >
      <svg width={size} height={size} style={{ display: 'block', transform: 'rotate(-90deg)' }}>
        {/* dashed track — the "minimal radial marks" of guide §14.1 */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={COLORS.disabled}
          strokeWidth={stroke}
          strokeDasharray="2 7"
        />
        {progress > 0 && (
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={s.color}
            strokeWidth={stroke}
            strokeLinecap="butt"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - progress)}
          />
        )}
        {/* At rest-complete the ring reads as a closed band rather than an
            empty track, so the state change is structural and not just a hue. */}
        {progress === 0 && (
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={s.color} strokeWidth={stroke} />
        )}
      </svg>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 1,
        }}
      >
        <span
          className="num"
          style={{
            fontFamily: FONTS.heading,
            fontWeight: 800,
            fontSize: Math.round(size * 0.26),
            lineHeight: 1,
            color: COLORS.text,
          }}
        >
          {timeText}
        </span>
        <span
          className="meta"
          style={{ fontSize: Math.round(size * 0.1), color: s.labelColor || s.color, fontWeight: 700 }}
        >
          {s.label}
        </span>
      </div>
    </div>
  )
}
