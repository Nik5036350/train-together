import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { participantsOf, sessionSets } from '../lib/selectors.js'
import { useNow, timerState } from '../lib/useNow.js'
import { formatElapsed, formatClock } from '../lib/format.js'
import { personPalette, COLORS, FONTS, RADII, BORDER } from '../theme.js'
import { Avatar, PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
import { IdentityBand } from '../components/IdentityBand.jsx'
import { TimerRing } from '../components/TimerRing.jsx'
import { PrimaryButton } from '../components/Button.jsx'

// Rest state as words + color — never color alone (guide §4.3).
const STATE_TEXT = {
  resting: { label: 'Resting', color: COLORS.steel },
  ready: { label: 'Ready', color: COLORS.success },
  overdue: { label: 'Overdue', color: COLORS.primaryText },
  none: { label: 'Ready', color: COLORS.success },
}

export function LiveOverview() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const session = state.session
  const now = useNow(true)
  const [addOpen, setAddOpen] = useState(false)
  const [addAssign, setAddAssign] = useState('both')
  const [finishOpen, setFinishOpen] = useState(false)
  const [finishing, setFinishing] = useState(false)

  if (!session) {
    return (
      <Empty onHome={() => nav('/')} />
    )
  }

  const people = participantsOf(state, session)
  const elapsed = formatElapsed(now - session.startTime)

  // The first exercise still needing work is the "active" one. Per-person status
  // is one of 'pending' | 'logged' | 'skipped' — the vocabulary the backend
  // writes (services/session.rs). It is not 'done'; testing for that made every
  // exercise look outstanding forever.
  const activeIdx = session.exercises.findIndex((se) =>
    se.appliesTo.some((pid) => {
      const st = se.perPerson[pid]?.status
      return st !== 'skipped' && st !== 'logged'
    }),
  )

  // Same reasoning as starting a workout: /summary reads `lastSummary`, which is
  // only set once the backend confirms, so navigating early showed "No recent
  // session." — permanently if the request failed.
  const finish = async () => {
    if (finishing) return
    setFinishing(true)
    const ok = await dispatch({ type: 'FINISH_SESSION' })
    setFinishing(false)
    if (ok) nav('/summary')
  }

  const incomplete = session.exercises.filter((se) =>
    se.appliesTo.some((pid) => {
      const st = se.perPerson[pid]?.status
      const has = sessionSets(session, se.id, pid).length > 0
      return st !== 'skipped' && st !== 'logged' && !has
    }),
  )

  const libraryNotInSession = Object.values(state.exercises).filter(
    (ex) => !session.exercises.some((se) => se.exerciseId === ex.id),
  )

  return (
    <div style={{ padding: '52px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '4px 20px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
          <div style={{ minWidth: 0 }}>
            <button
              onClick={() => nav('/')}
              className="display"
              style={{ fontSize: 26, textTransform: 'uppercase', textAlign: 'left', lineHeight: 1.05 }}
            >
              {session.name}
            </button>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
              <PersonPair people={people} size={20} />
              <span className="meta" style={{ color: COLORS.textSecondary }}>
                {people.map((p) => p.name).join(' + ')}
              </span>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8 }}>
            <div
              className="num display"
              style={{ fontSize: 24, display: 'flex', alignItems: 'center', gap: 7 }}
            >
              <Icon name="clock" size={15} />
              {elapsed}
            </div>
            <button
              onClick={() => setFinishOpen(true)}
              style={{
                padding: '8px 14px',
                background: COLORS.text,
                color: COLORS.onDark,
                borderRadius: RADII.sm,
                fontFamily: FONTS.heading,
                fontWeight: 700,
                fontSize: 13,
                textTransform: 'uppercase',
                letterSpacing: '0.04em',
              }}
            >
              Finish
            </button>
          </div>
        </div>
        <div style={{ height: 3, background: COLORS.rule, marginTop: 12 }} />
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
          Add exercise
        </button>
      </div>

      {/* Add exercise sheet */}
      <Sheet open={addOpen} onClose={() => setAddOpen(false)} title="Add exercise">
        <SectionLabel style={{ marginBottom: 12 }}>For whom</SectionLabel>
        <div style={{ marginBottom: 20 }}>
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
        <SectionLabel style={{ marginBottom: 12 }}>Exercise</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {libraryNotInSession.map((ex) => (
            <button
              key={ex.id}
              onClick={() => {
                dispatch({ type: 'ADD_SESSION_EXERCISE', payload: { exerciseId: ex.id, assignment: addAssign } })
                setAddOpen(false)
              }}
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                background: COLORS.card,
                borderRadius: RADII.sm,
                padding: '12px 14px',
                border: `${BORDER}px solid ${COLORS.ruleSoft}`,
              }}
            >
              <div style={{ textAlign: 'left' }}>
                <div className="display" style={{ fontSize: 16, textTransform: 'uppercase' }}>{ex.name}</div>
                <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 2 }}>{ex.equipment || ex.category}</div>
              </div>
              <Icon name="plus" size={14} />
            </button>
          ))}
        </div>
      </Sheet>

      {/* Finish confirmation (PRD FR-220 — warns about incomplete items) */}
      <Sheet open={finishOpen} onClose={() => setFinishOpen(false)} title="Finish workout?">
        {incomplete.length > 0 ? (
          <div style={{ marginBottom: 20 }}>
            <div style={{ fontSize: 14, color: COLORS.textSecondary, marginBottom: 12 }}>
              Some planned exercises aren't done yet:
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              {incomplete.map((se, i) => (
                <div
                  key={se.id}
                  className="display"
                  style={{
                    padding: '10px 0',
                    fontSize: 15,
                    textTransform: 'uppercase',
                    borderTop: i === 0 ? 'none' : `1px solid ${COLORS.ruleSoft}`,
                  }}
                >
                  {state.exercises[se.exerciseId]?.name}
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div style={{ fontSize: 14, color: COLORS.textSecondary, marginBottom: 20 }}>
            Everything's logged. Nice work, both of you.
          </div>
        )}
        <PrimaryButton onClick={finish} disabled={finishing}>
          {finishing ? 'Finishing…' : incomplete.length > 0 ? 'Finish anyway' : 'Finish & see summary'}
        </PrimaryButton>
        <button
          onClick={() => setFinishOpen(false)}
          className="meta"
          style={{ width: '100%', padding: 14, marginTop: 8, color: COLORS.textSecondary }}
        >
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
    const timer = session.timers[activePerson?.id]
    const onThis = timer && timer.sessionExerciseId === se.id
    const ts = onThis ? timerState(timer, now) : { state: 'ready' }

    return (
      <button
        onClick={onOpen}
        style={{
          display: 'flex',
          textAlign: 'left',
          background: COLORS.card,
          borderRadius: RADII.md,
          border: `${BORDER}px solid ${pal.accent}`,
          overflow: 'hidden',
          width: '100%',
        }}
      >
        <IdentityBand person={activePerson} active width={30} />
        <div style={{ flex: 1, minWidth: 0, padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="meta" style={{ color: pal.text }}>
                Next · {activePerson?.name}
              </div>
              <div className="display" style={{ fontSize: 20, textTransform: 'uppercase', marginTop: 4 }}>
                {exercise?.name}
              </div>
            </div>
            <span className="num display" style={{ fontSize: 20, color: COLORS.textSecondary }}>
              {String(index + 1).padStart(2, '0')}
            </span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 12 }}>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
              {people.map((p) => {
                const count = sessionSets(session, se.id, p.id).length
                const pp = personPalette(p)
                // Each participant keeps their own rest state visible here —
                // the ring only ever shows whoever's turn it is.
                const pt = session.timers[p.id]
                const pOnThis = pt && pt.sessionExerciseId === se.id
                const pts = pOnThis ? timerState(pt, now) : { state: 'ready' }
                return (
                  <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ width: 10, height: 10, background: pp.accent, flexShrink: 0 }} />
                    <span className="meta" style={{ color: COLORS.textSecondary }}>{p.name}</span>
                    <span className="meta num" style={{ flex: 1, fontSize: 10, color: STATE_TEXT[pts.state].color }}>
                      {pts.state === 'resting'
                        ? `Rest ${formatClock(pts.remaining)}`
                        : STATE_TEXT[pts.state].label}
                    </span>
                    <span className="num" style={{ fontFamily: FONTS.heading, fontWeight: 700, fontSize: 14 }}>
                      {count} {count === 1 ? 'SET' : 'SETS'}
                    </span>
                  </div>
                )
              })}
            </div>
            <TimerRing ts={ts} total={onThis ? timer.durationSeconds : 0} size={62} stroke={5} />
          </div>
        </div>
      </button>
    )
  }

  // Compact / inactive row — a ledger line rather than a card.
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
        background: COLORS.card,
        borderRadius: RADII.sm,
        border: `1px solid ${COLORS.ruleSoft}`,
        padding: '12px 14px',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        opacity: anySkipped ? 0.65 : 1,
        width: '100%',
      }}
    >
      <span className="num display" style={{ fontSize: 19, color: COLORS.textSecondary, minWidth: 24 }}>
        {String(index + 1).padStart(2, '0')}
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span className="display" style={{ fontSize: 16, textTransform: 'uppercase' }}>{exercise?.name}</span>
          {anySub && (
            <span className="meta" style={{ fontSize: 10, color: COLORS.text, background: COLORS.warning, padding: '2px 6px' }}>
              substituted
            </span>
          )}
        </div>
        <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 2 }}>{subtitle}</div>
      </div>
      {people.map((p, idx) => (
        <Avatar key={p.id} person={p} size={20} fontSize={11} style={idx > 0 ? { marginLeft: 2 } : undefined} />
      ))}
    </button>
  )
}

function Empty({ onHome }) {
  return (
    <div style={{ padding: '120px 30px', textAlign: 'center' }}>
      <div className="display" style={{ fontSize: 24, textTransform: 'uppercase', marginBottom: 8 }}>
        No active workout
      </div>
      <div style={{ fontSize: 14, color: COLORS.textSecondary, marginBottom: 20 }}>
        Start a session from your routines.
      </div>
      <button
        onClick={onHome}
        className="meta"
        style={{ color: COLORS.primaryText, borderBottom: `2px solid ${COLORS.primaryText}`, paddingBottom: 2 }}
      >
        Back to workouts
      </button>
    </div>
  )
}
