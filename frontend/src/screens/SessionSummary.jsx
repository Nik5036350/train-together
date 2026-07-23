import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { personTotals } from '../lib/selectors.js'
import { formatElapsed, trimNum } from '../lib/format.js'
import { personPalette, COLORS } from '../theme.js'
import { Avatar } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { GhostButton, PrimaryButton } from '../components/Button.jsx'

export function SessionSummary() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const summary = state.lastSummary

  if (!summary) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <div style={{ fontSize: 16, color: COLORS.textSecondary, marginBottom: 16 }}>No recent session.</div>
        <button onClick={() => nav('/')} style={{ color: COLORS.primary, fontWeight: 700 }}>Back to workouts</button>
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
    <div style={{ padding: '58px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '10px 20px 18px', textAlign: 'center' }}>
        <div style={{ width: 52, height: 52, borderRadius: '50%', background: COLORS.success, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
          <Icon name="checkBig" size={22} />
        </div>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 24, letterSpacing: '-.3px' }}>
          {summary.name} complete
        </div>
        <div style={{ fontSize: 14, color: COLORS.textMuted, marginTop: 4 }}>
          {people.length > 1 ? 'Great session, both of you.' : 'Great session.'}
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 11 }}>
        {/* shared hero card */}
        <div style={{ background: COLORS.darkSurface, borderRadius: 16, padding: 16, color: '#fff' }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: 'rgba(255,255,255,.45)', marginBottom: 13 }}>
            SHARED SESSION
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <Stat value={duration} label="duration" dark />
            <Stat value={exerciseCount} label="exercises" dark />
            <Stat value={totalSets} label="total sets" dark />
          </div>
        </div>

        {/* per-person cards */}
        {people.map((person) => {
          const pal = personPalette(person)
          const t = personTotals(summary, person.id, state.exercises)
          return (
            <div key={person.id} style={{ background: '#fff', borderRadius: 16, border: '1px solid rgba(15,17,21,.05)', borderLeft: `3px solid ${pal.accent}`, padding: 15 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 13 }}>
                <Avatar person={person} size={26} radius={8} />
                <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}>{person.name}</span>
              </div>
              <div style={{ display: 'flex', gap: 10 }}>
                <Stat value={t.exercises} label="exercises" />
                <Stat value={t.sets} label="sets" />
                <Stat value={`${trimNum(t.volume)} ${person.unit}`} label="volume" flex={1.4} />
              </div>
            </div>
          )
        })}
      </div>

      <div style={{ padding: '12px 18px 0', display: 'flex', gap: 9 }}>
        <GhostButton onClick={() => nav(`/history/${summary.id}`)}>View details</GhostButton>
        <PrimaryButton onClick={done} style={{ height: 48, fontSize: 15 }}>Done</PrimaryButton>
      </div>
    </div>
  )
}

function Stat({ value, label, dark, flex = 1 }) {
  return (
    <div style={{ flex }}>
      <div className="num" style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: dark ? 22 : 19 }}>
        {value}
      </div>
      <div style={{ fontSize: 11, color: dark ? 'rgba(255,255,255,.45)' : COLORS.textMuted, marginTop: 2 }}>{label}</div>
    </div>
  )
}
