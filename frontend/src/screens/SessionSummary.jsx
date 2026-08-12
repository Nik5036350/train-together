import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { personTotals } from '../lib/selectors.js'
import { formatElapsed, trimNum } from '../lib/format.js'
import { personPalette, COLORS, BORDER } from '../theme.js'
import { StatBlock } from '../components/StatBlock.jsx'
import { GhostButton, PrimaryButton } from '../components/Button.jsx'

export function SessionSummary() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const summary = state.lastSummary

  if (!summary) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <div className="display" style={{ fontSize: 22, textTransform: 'uppercase', marginBottom: 16 }}>
          No recent session
        </div>
        <button
          onClick={() => nav('/')}
          className="meta"
          style={{ color: COLORS.primaryText, borderBottom: `2px solid ${COLORS.primaryText}`, paddingBottom: 2 }}
        >
          Back to workouts
        </button>
      </div>
    )
  }

  const people = summary.participantIds.map((id) => personById(state, id)).filter(Boolean)
  const duration = formatElapsed((summary.endTime || Date.now()) - summary.startTime)
  const exerciseCount = new Set(summary.sets.map((s) => s.exerciseId)).size
  const totalSets = summary.sets.length

  const done = () => {
    dispatch({ type: 'DISMISS_SUMMARY' })
    nav('/')
  }

  return (
    <div style={{ padding: '52px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="scroll-area" style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        {/* Completion block — the restrained geometric motif of guide §25:
            a red field cut by an ink diagonal, no confetti. */}
        <div
          className="grain"
          style={{
            position: 'relative',
            background: COLORS.primary,
            color: COLORS.onDark,
            padding: '26px 20px 22px',
            overflow: 'hidden',
          }}
        >
          <div
            aria-hidden="true"
            style={{
              position: 'absolute',
              inset: 0,
              background: `linear-gradient(206deg, ${COLORS.text} 0 30%, transparent 30.2%)`,
            }}
          />
          <div style={{ position: 'relative' }}>
            <div className="display" style={{ fontSize: 38, textTransform: 'uppercase', lineHeight: 0.98 }}>
              Workout
              <br />
              complete
            </div>
            <div className="meta" style={{ marginTop: 10, color: COLORS.onDarkMuted }}>
              {summary.name}
            </div>
          </div>
        </div>

        {/* Shared metrics */}
        <div style={{ background: COLORS.text, color: COLORS.onDark, padding: '18px 20px' }}>
          <div style={{ display: 'flex', gap: 14 }}>
            <StatBlock value={duration} label="total time" tone="dark" size={34} />
            <StatBlock value={totalSets} label="total sets" tone="dark" size={34} />
            <StatBlock value={exerciseCount} label="exercises" tone="dark" size={34} />
          </div>
        </div>

        {/* Per-person blocks — equal but distinct, never blended (guide §4.2). */}
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {people.map((person) => {
            const pal = personPalette(person)
            const t = personTotals(summary, person.id, state.exercises)
            return (
              <div
                key={person.id}
                style={{
                  display: 'flex',
                  background: COLORS.card,
                  borderBottom: `${BORDER}px solid ${COLORS.rule}`,
                }}
              >
                <div
                  style={{
                    width: 44,
                    background: pal.accent,
                    color: pal.onAccent,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <span
                    className="display"
                    style={{
                      writingMode: 'vertical-rl',
                      transform: 'rotate(180deg)',
                      fontSize: 17,
                      letterSpacing: '0.06em',
                      textTransform: 'uppercase',
                    }}
                  >
                    {person.name}
                  </span>
                </div>
                <div style={{ flex: 1, minWidth: 0, padding: '16px 18px' }}>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <StatBlock value={`${trimNum(t.volume)}`} label={`volume ${person.unit}`} size={30} flex={1.5} />
                    <StatBlock value={t.sets} label="sets" size={30} />
                    <StatBlock value={t.reps} label="reps" size={30} />
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        <div style={{ padding: '16px 20px 0', fontSize: 13, color: COLORS.textSecondary }}>
          {people.length > 1 ? 'Logged separately, trained together.' : 'Session logged.'}
        </div>
      </div>

      <div style={{ padding: '14px 18px 0', display: 'flex', gap: 9 }}>
        <GhostButton onClick={() => nav(`/history/${summary.id}`)}>View details</GhostButton>
        <PrimaryButton onClick={done}>Done</PrimaryButton>
      </div>
    </div>
  )
}
