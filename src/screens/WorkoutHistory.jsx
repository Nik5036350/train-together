import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { formatDate, formatElapsed } from '../lib/format.js'
import { COLORS } from '../theme.js'
import { PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'

export function WorkoutHistory() {
  const { state } = useApp()
  const nav = useNavigate()
  const sessions = [...state.history].sort((a, b) => (b.startTime || 0) - (a.startTime || 0))

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 22px 14px' }}>
        <button onClick={() => nav('/')} style={{ color: COLORS.textMuted, fontSize: 15 }}>
          Back
        </button>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 25, marginTop: 8, letterSpacing: '-.4px' }}>
          Past workouts
        </div>
        <div style={{ fontSize: 13, color: COLORS.textMuted, marginTop: 3 }}>
          {sessions.length} {sessions.length === 1 ? 'session' : 'sessions'}
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {sessions.length === 0 && (
          <div style={{ textAlign: 'center', color: COLORS.textMuted, fontSize: 14, padding: '60px 20px' }}>
            No finished workouts yet. Start a session and they'll show up here.
          </div>
        )}
        {sessions.map((s) => (
          <HistoryCard key={s.id} state={state} session={s} onOpen={() => nav(`/history/${s.id}`)} />
        ))}
      </div>
    </div>
  )
}

export function HistoryCard({ state, session, onOpen }) {
  const people = (session.participantIds || []).map((id) => personById(state, id)).filter(Boolean)
  const duration = session.endTime ? formatElapsed(session.endTime - session.startTime) : null

  return (
    <button
      onClick={onOpen}
      style={{
        textAlign: 'left',
        background: '#fff',
        borderRadius: 14,
        border: '1px solid rgba(15,17,21,.05)',
        padding: '14px 15px',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
      }}
    >
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}>{session.name}</div>
        <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 3 }}>
          {formatDate(session.startTime)}
          {duration ? ` · ${duration}` : ''} · {session.sets.length} sets
        </div>
      </div>
      {people.length > 0 && <PersonPair people={people} size={22} />}
      <span style={{ color: '#C2C6CD' }}>
        <Icon name="chevronRight" size={8} />
      </span>
    </button>
  )
}
