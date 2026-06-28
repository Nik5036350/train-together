import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { participantsOf, sessionSets } from '../lib/selectors.js'
import { useNow, timerState } from '../lib/useNow.js'
import { formatElapsed, formatDuration } from '../lib/format.js'
import { personPalette, COLORS } from '../theme.js'
import { Avatar, PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { Segmented } from '../components/Segmented.jsx'

export function LiveOverview() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const session = state.session
  const now = useNow(true)
  const [addOpen, setAddOpen] = useState(false)
  const [addAssign, setAddAssign] = useState('both')
  const [finishOpen, setFinishOpen] = useState(false)

  if (!session) {
    return (
      <Empty onHome={() => nav('/')} />
    )
  }

  const people = participantsOf(state, session)
  const elapsed = formatElapsed(now - session.startTime)

  // The first exercise still needing work is the "active" one.
  const activeIdx = session.exercises.findIndex((se) =>
    se.appliesTo.some((pid) => {
      const st = se.perPerson[pid]?.status
      return st !== 'skipped' && st !== 'done'
    }),
  )

  const finish = () => {
    dispatch({ type: 'FINISH_SESSION' })
    nav('/summary')
  }

  const incomplete = session.exercises.filter((se) =>
    se.appliesTo.some((pid) => {
      const st = se.perPerson[pid]?.status
      const has = sessionSets(session, se.id, pid).length > 0
      return st !== 'skipped' && st !== 'done' && !has
    }),
  )

  const libraryNotInSession = Object.values(state.exercises).filter(
    (ex) => !session.exercises.some((se) => se.exerciseId === ex.id),
  )

  return (
    <div style={{ padding: '52px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '4px 20px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <div>
            <button onClick={() => nav('/')} style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 23, letterSpacing: '-.3px', textAlign: 'left' }}>
              {session.name}
            </button>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 7 }}>
              <PersonPair people={people} size={21} />
              <span style={{ fontSize: 13, color: COLORS.textSecondary, fontWeight: 500 }}>
                {people.map((p) => p.name).join(' + ')}
              </span>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: COLORS.textSecondary }}>
              <Icon name="clock" size={14} />
              <span className="num" style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 17 }}>
                {elapsed}
              </span>
            </div>
            <button onClick={() => setFinishOpen(true)} style={{ padding: '8px 15px', background: '#0F1115', color: '#fff', borderRadius: 10, fontWeight: 700, fontSize: 13 }}>
              Finish
            </button>
          </div>
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {session.exercises.map((se, idx) => (
          <ExerciseRow
            key={se.id}
            state={state}
            session={session}
            se={se}
            index={idx}
            active={idx === activeIdx}
            now={now}
            onOpen={() => nav(`/session/exercise/${se.id}`)}
          />
        ))}

        <button
          onClick={() => setAddOpen(true)}
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
          Add exercise
        </button>
      </div>

      {/* Add exercise sheet */}
      <Sheet open={addOpen} onClose={() => setAddOpen(false)} title="Add exercise">
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, marginBottom: 10 }}>FOR WHOM</div>
        <div style={{ marginBottom: 16 }}>
          <Segmented
            variant="cards"
            options={[
              { value: 'owner', label: people[0]?.name || 'Owner' },
              { value: 'partner', label: people.find((p) => !p.isOwner)?.name || 'Partner' },
              { value: 'both', label: 'Both' },
            ].filter((o) => o.value === 'both' ? people.length > 1 : true)}
            value={addAssign}
            onChange={setAddAssign}
          />
        </div>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, marginBottom: 10 }}>EXERCISE</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {libraryNotInSession.map((ex) => (
            <button
              key={ex.id}
              onClick={() => {
                dispatch({ type: 'ADD_SESSION_EXERCISE', payload: { exerciseId: ex.id, assignment: addAssign } })
                setAddOpen(false)
              }}
              style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: '#fff', borderRadius: 12, padding: '13px 14px', border: '1px solid rgba(15,17,21,.06)' }}
            >
              <div style={{ textAlign: 'left' }}>
                <div style={{ fontWeight: 700, fontSize: 15 }}>{ex.name}</div>
                <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>{ex.equipment || ex.category}</div>
              </div>
              <Icon name="plus" size={14} />
            </button>
          ))}
        </div>
      </Sheet>

      {/* Finish confirmation (PRD FR-220 — warns about incomplete items) */}
      <Sheet open={finishOpen} onClose={() => setFinishOpen(false)} title="Finish workout?">
        {incomplete.length > 0 ? (
          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 14, color: COLORS.textSecondary, marginBottom: 10 }}>
              Some planned exercises aren't done yet:
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {incomplete.map((se) => (
                <div key={se.id} style={{ background: '#fff', borderRadius: 10, padding: '10px 12px', fontSize: 13, fontWeight: 600 }}>
                  {state.exercises[se.exerciseId]?.name}
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div style={{ fontSize: 14, color: COLORS.textSecondary, marginBottom: 16 }}>
            Everything's logged. Nice work, both of you.
          </div>
        )}
        <button onClick={finish} style={{ width: '100%', height: 50, borderRadius: 13, background: COLORS.primary, color: '#fff', fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}>
          {incomplete.length > 0 ? 'Finish anyway' : 'Finish & see summary'}
        </button>
        <button onClick={() => setFinishOpen(false)} style={{ width: '100%', padding: 12, marginTop: 8, fontWeight: 600, color: COLORS.textMuted }}>
          Return to workout
        </button>
      </Sheet>
    </div>
  )
}

function ExerciseRow({ state, session, se, index, active, now, onOpen }) {
  const exercise = state.exercises[se.exerciseId]
  const people = se.appliesTo.map((id) => personById(state, id))
  const anySkipped = se.appliesTo.find((id) => se.perPerson[id]?.status === 'skipped')
  const anySub = se.appliesTo.find((id) => se.perPerson[id]?.substituteExerciseId)

  if (active) {
    const activePerson = personById(state, se.activePersonId)
    const pal = personPalette(activePerson)
    return (
      <button
        onClick={onOpen}
        style={{
          textAlign: 'left',
          background: '#fff',
          borderRadius: 14,
          padding: 14,
          border: `1.5px solid ${pal.accent}`,
          boxShadow: `0 6px 18px ${pal.accent}1A`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span className="num" style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 14, color: '#C2C6CD' }}>{index + 1}</span>
          <span style={{ flex: 1, fontWeight: 700, fontSize: 16 }}>{exercise?.name}</span>
          <span style={{ fontSize: 10.5, fontWeight: 700, color: pal.text, background: pal.tint, padding: '4px 9px', borderRadius: 7, letterSpacing: '.3px' }}>
            NEXT · {activePerson?.name?.toUpperCase()}
          </span>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
          {people.map((p) => {
            const count = sessionSets(session, se.id, p.id).length
            const pp = personPalette(p)
            return (
              <div key={p.id} style={{ flex: 1, background: '#F4F5F7', borderRadius: 10, padding: '8px 11px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontSize: 12, color: pp.text, fontWeight: 700 }}>{p.name}</span>
                <span className="num" style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 15 }}>{count} {count === 1 ? 'set' : 'sets'}</span>
              </div>
            )
          })}
        </div>
        <div style={{ display: 'flex', gap: 16, marginTop: 10, fontSize: 12, flexWrap: 'wrap' }}>
          {people.map((p) => {
            const t = session.timers[p.id]
            const onThis = t && t.sessionExerciseId === se.id
            const ts = onThis ? timerState(t, now) : { state: 'ready' }
            if (ts.state === 'resting') {
              return (
                <span key={p.id} style={{ color: COLORS.textMuted, fontWeight: 500 }}>
                  {p.name} resting {formatDuration(ts.remaining)}
                </span>
              )
            }
            return (
              <span key={p.id} style={{ color: COLORS.success, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 5 }}>
                <span style={{ width: 6, height: 6, borderRadius: '50%', background: COLORS.success }} />
                {p.name} ready
              </span>
            )
          })}
        </div>
      </button>
    )
  }

  // Compact / inactive row
  let subtitle = 'Not started yet'
  if (anySkipped) {
    const sp = personById(state, anySkipped)
    const reason = se.perPerson[anySkipped]?.skipReason
    subtitle = `Skipped for ${sp?.name}${reason ? ' · ' + reason : ''}`
  }
  const someProgress = se.appliesTo.some((id) => sessionSets(session, se.id, id).length > 0)
  if (someProgress && !anySkipped) subtitle = 'In progress'

  return (
    <button
      onClick={onOpen}
      style={{
        textAlign: 'left',
        background: '#fff',
        borderRadius: 14,
        border: '1px solid rgba(15,17,21,.05)',
        padding: '13px 14px',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        opacity: anySkipped ? 0.6 : 1,
      }}
    >
      <span className="num" style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 14, color: '#C2C6CD' }}>{index + 1}</span>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 700, fontSize: 15, display: 'flex', alignItems: 'center', gap: 7 }}>
          {exercise?.name}
          {anySub && (
            <span style={{ fontSize: 10.5, fontWeight: 600, color: '#C2570C', background: '#FBF1E9', padding: '2px 7px', borderRadius: 6 }}>substituted</span>
          )}
        </div>
        <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>{subtitle}</div>
      </div>
      {people.map((p, idx) => (
        <Avatar key={p.id} person={p} size={20} radius={6} fontSize={10} style={idx > 0 ? { marginLeft: -6, border: '1.5px solid #fff' } : undefined} />
      ))}
    </button>
  )
}

function Empty({ onHome }) {
  return (
    <div style={{ padding: '120px 30px', textAlign: 'center' }}>
      <div style={{ fontSize: 16, fontWeight: 600, color: COLORS.textSecondary, marginBottom: 16 }}>No active workout.</div>
      <button onClick={onHome} style={{ color: COLORS.primary, fontWeight: 700 }}>Back to workouts</button>
    </div>
  )
}
