import { BORDER, COLORS, FONTS, RADII, personPalette } from '../theme.js'

// Square initial block in the person's identity color. Identity must never rely
// on color alone, so the initial is always shown. Square, not round: circles are
// reserved for timers and focus in this system (guide §3).
export function Avatar({ person, size = 28, radius = RADII.sm, fontSize, style }) {
  const pal = personPalette(person)
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        background: pal.accent,
        color: pal.onAccent,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: FONTS.heading,
        fontWeight: 800,
        fontSize: fontSize ?? Math.round(size * 0.52),
        lineHeight: 1,
        flexShrink: 0,
        ...style,
      }}
    >
      {person?.initials || person?.name?.[0] || '?'}
    </div>
  )
}

// Two adjoining identity blocks used wherever an exercise / session is for
// "Both" — butted together as RED | STEEL rather than overlapped or blended.
export function PersonPair({ people, size = 22 }) {
  return (
    <div style={{ display: 'flex' }}>
      {people.map((p, i) => (
        <Avatar
          key={p.id}
          person={p}
          size={size}
          style={i === 0 ? undefined : { marginLeft: BORDER, borderRadius: RADII.sm }}
        />
      ))}
    </div>
  )
}
