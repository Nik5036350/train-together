import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { COLORS, FONTS, RADII, BORDER } from '../theme.js'
import { Icon } from '../components/Icon.jsx'

// Human-readable summary of what an exercise tracks, e.g. "Weight · Reps".
export function tracksSummary(tracks = {}) {
  const parts = []
  if (tracks.weight) parts.push('Weight')
  if (tracks.reps) parts.push('Reps')
  if (tracks.duration) parts.push('Duration')
  return parts.join(' · ') || 'Custom'
}

export function ExerciseLibrary() {
  const { state } = useApp()
  const nav = useNavigate()
  const exercises = Object.values(state.exercises).sort((a, b) => a.name.localeCompare(b.name))

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 20px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav('/')} className="meta" style={{ color: COLORS.textSecondary }}>
            ← Back
          </button>
          <button onClick={() => nav('/exercise/new')} className="meta" style={{ color: COLORS.primaryText }}>
            New
          </button>
        </div>
        <div className="display" style={{ fontSize: 32, textTransform: 'uppercase', marginTop: 8, lineHeight: 1 }}>
          Exercises
        </div>
        <div style={{ height: 3, background: COLORS.rule, margin: '10px 0 8px' }} />
        <div className="meta" style={{ color: COLORS.textSecondary }}>
          {exercises.length} {exercises.length === 1 ? 'exercise' : 'exercises'} · shared by both of you
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {exercises.map((ex) => (
          <button
            key={ex.id}
            onClick={() => nav(`/exercise/${ex.id}/edit`)}
            style={{
              textAlign: 'left',
              background: COLORS.card,
              borderRadius: RADII.sm,
              border: `1px solid ${COLORS.ruleSoft}`,
              padding: '12px 14px',
              display: 'flex',
              alignItems: 'center',
              gap: 11,
            }}
          >
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="display" style={{ fontSize: 16, textTransform: 'uppercase' }}>{ex.name}</div>
              <div className="meta" style={{ fontSize: 10, color: COLORS.textSecondary, marginTop: 3 }}>
                {tracksSummary(ex.tracks)}
              </div>
            </div>
            <span style={{ color: COLORS.textSecondary }}>
              <Icon name="chevronRight" size={9} />
            </span>
          </button>
        ))}

        <button
          onClick={() => nav('/exercise/new')}
          style={{
            border: `${BORDER}px dashed ${COLORS.rule}`,
            borderRadius: RADII.sm,
            padding: 14,
            fontFamily: FONTS.heading,
            fontSize: 14,
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '0.04em',
            color: COLORS.text,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
          }}
        >
          <Icon name="plus" size={13} />
          New exercise
        </button>
      </div>
    </div>
  )
}
