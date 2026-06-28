import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { COLORS } from '../theme.js'
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
      <div style={{ padding: '0 22px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav('/')} style={{ color: COLORS.textMuted, fontSize: 15 }}>
            Back
          </button>
          <button onClick={() => nav('/exercise/new')} style={{ color: COLORS.primary, fontSize: 15, fontWeight: 700 }}>
            New
          </button>
        </div>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 25, marginTop: 8, letterSpacing: '-.4px' }}>
          Exercises
        </div>
        <div style={{ fontSize: 13, color: COLORS.textMuted, marginTop: 3 }}>
          {exercises.length} {exercises.length === 1 ? 'exercise' : 'exercises'} · shared by both of you
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {exercises.map((ex) => (
          <button
            key={ex.id}
            onClick={() => nav(`/exercise/${ex.id}/edit`)}
            style={{
              textAlign: 'left',
              background: '#fff',
              borderRadius: 14,
              border: '1px solid rgba(15,17,21,.05)',
              padding: '13px 14px',
              display: 'flex',
              alignItems: 'center',
              gap: 11,
            }}
          >
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, fontSize: 15 }}>{ex.name}</div>
              <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>{tracksSummary(ex.tracks)}</div>
            </div>
            <span style={{ color: '#C2C6CD' }}>
              <Icon name="chevronRight" size={8} />
            </span>
          </button>
        ))}

        <button
          onClick={() => nav('/exercise/new')}
          style={{
            border: '1.5px dashed rgba(15,17,21,.15)',
            borderRadius: 12,
            padding: 13,
            fontSize: 14,
            fontWeight: 600,
            color: COLORS.textSecondary,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 7,
          }}
        >
          <Icon name="plus" size={13} />
          New exercise
        </button>
      </div>
    </div>
  )
}
