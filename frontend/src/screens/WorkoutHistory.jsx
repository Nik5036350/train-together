import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { formatDate, formatElapsed, totalVolume } from '../lib/format.js'
import { COLORS, FONTS, RADII } from '../theme.js'
import { PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'

// History reads as a training ledger, not a social feed (guide §26): date,
// routine, participants, duration, sets, volume — and nothing to react to.
export function WorkoutHistory() {
  const { state } = useApp()
  const nav = useNavigate()
  const sessions = [...state.history].sort((a, b) => (b.startTime || 0) - (a.startTime || 0))

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 20px 12px' }}>
        <button onClick={() => nav('/')} className="meta" style={{ color: COLORS.textSecondary }}>
          ← Back
        </button>
        <div className="display" style={{ fontSize: 32, textTransform: 'uppercase', marginTop: 8, lineHeight: 1 }}>
          Past workouts
        </div>
        <div style={{ height: 3, background: COLORS.rule, margin: '10px 0 8px' }} />
        <div className="meta num" style={{ color: COLORS.textSecondary }}>
          {sessions.length} {sessions.length === 1 ? 'session' : 'sessions'}
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {sessions.length === 0 && (
          <div className="grain" style={{ position: 'relative', textAlign: 'center', padding: '60px 20px' }}>
            <div className="display" style={{ fontSize: 22, textTransform: 'uppercase' }}>No workouts yet</div>
            <div style={{ fontSize: 13, color: COLORS.textSecondary, marginTop: 8, lineHeight: 1.5 }}>
              Start your first session.
              <br />
              Your history will appear here.
            </div>
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
  const volume = totalVolume(session.sets)
  const unit = people[0]?.unit || 'kg'

  return (
    <button
      onClick={onOpen}
      style={{
        textAlign: 'left',
        background: COLORS.card,
        borderRadius: RADII.sm,
        border: `1px solid ${COLORS.ruleSoft}`,
        borderLeft: `4px solid ${COLORS.rule}`,
        padding: '12px 14px',
        width: '100%',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span className="display" style={{ flex: 1, fontSize: 17, textTransform: 'uppercase' }}>
          {session.name}
        </span>
        {people.length > 0 && <PersonPair people={people} size={18} />}
        <span style={{ color: COLORS.textSecondary }}>
          <Icon name="chevronRight" size={9} />
        </span>
      </div>
      <div className="meta" style={{ color: COLORS.textSecondary, marginTop: 4, fontSize: 11 }}>
        {formatDate(session.startTime)}
      </div>
      {/* the ledger line: duration · sets · volume, aligned across every row */}
      <div style={{ display: 'flex', gap: 16, marginTop: 8 }}>
        <LedgerFigure value={duration || '—'} label="time" />
        <LedgerFigure value={session.sets.length} label="sets" />
        <LedgerFigure value={volume > 0 ? `${Math.round(volume)}` : '—'} label={`volume ${unit}`} />
      </div>
    </button>
  )
}

function LedgerFigure({ value, label }) {
  return (
    <div>
      <div className="num" style={{ fontFamily: FONTS.heading, fontWeight: 800, fontSize: 18, lineHeight: 1 }}>
        {value}
      </div>
      <div className="meta" style={{ fontSize: 10, color: COLORS.textSecondary, marginTop: 3 }}>
        {label}
      </div>
    </div>
  )
}
