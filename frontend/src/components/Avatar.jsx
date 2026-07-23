import { personPalette } from '../theme.js'

// Rounded-square initial chip in the person's identity color (PRD: identity must
// never rely on color alone — the initial is always shown).
export function Avatar({ person, size = 27, radius, fontSize, style }) {
  const pal = personPalette(person)
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: radius ?? Math.round(size * 0.3),
        background: pal.accent,
        color: '#fff',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: "'Archivo', sans-serif",
        fontWeight: 700,
        fontSize: fontSize ?? Math.round(size * 0.48),
        flexShrink: 0,
        ...style,
      }}
    >
      {person?.initials || person?.name?.[0] || '?'}
    </div>
  )
}

// Two overlapping avatars used wherever an exercise / session is for "Both".
export function PersonPair({ people, size = 21 }) {
  return (
    <div style={{ display: 'flex' }}>
      {people.map((p, i) => (
        <Avatar
          key={p.id}
          person={p}
          size={size}
          radius={Math.round(size * 0.28)}
          style={
            i === 0
              ? undefined
              : { marginLeft: -Math.round(size * 0.3), border: '1.5px solid #fff' }
          }
        />
      ))}
    </div>
  )
}
