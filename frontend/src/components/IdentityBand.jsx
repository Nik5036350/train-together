import { personPalette } from '../theme.js'

// The vertical identity band (guide §13) — the app's key brand behavior. A
// solid block in the person's color running the full height of their card, with
// their name set into it so identity never depends on color alone.
//
// Render it as the first (or last) flex child of a stretched row.
export function IdentityBand({ person, active = false, width = 30, side = 'left' }) {
  const pal = personPalette(person)
  const name = (person?.name || '').toUpperCase()

  return (
    <div
      aria-hidden="true"
      style={{
        width,
        alignSelf: 'stretch',
        flexShrink: 0,
        background: active ? pal.accent : pal.tint,
        color: active ? pal.onAccent : pal.text,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '10px 0',
        // The band slides in when the turn moves to this person.
        animation: active ? 'band-in var(--motion-slow) var(--ease-default)' : undefined,
        transformOrigin: side === 'left' ? 'top' : 'bottom',
      }}
    >
      <span
        className="display"
        style={{
          writingMode: 'vertical-rl',
          transform: 'rotate(180deg)',
          fontSize: Math.round(width * 0.52),
          letterSpacing: '0.06em',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
        }}
      >
        {name}
      </span>
    </div>
  )
}
