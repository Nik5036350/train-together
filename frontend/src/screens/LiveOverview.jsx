import { useEffect, useState } from 'react'
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
  const [addingExerciseId, setAddingExerciseId] = useState(null)
  const [finishOpen, setFinishOpen] = useState(false)
  const [finishing, setFinishing] = useState(false)

  // Adding an exercise returns a refreshed aggregate through AppContext. Wait
  // for that state before navigating so the logger always receives the new
  // session-exercise id rather than the library exercise id.
  useEffect(() => {
    if (!addingExerciseId) return
    const added = session?.exercises.find((se) => se.exerciseId === addingExerciseId)
    if (!added) return
    setAddingExerciseId(null)
    nav(`/session/exercise/${added.id}`)
  }, [addingExerciseId, nav, session])

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
  const activeExercise = session.exercises.find((se) =>
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

  const standardExercises = session.exercises.filter((se) => !se.addedDuringSession)
  const addedExercises = session.exercises.filter((se) => se.addedDuringSession)
  const libraryNotInSession = Object.values(state.exercises)
    .filter((ex) => !session.exercises.some((se) => se.exerciseId === ex.id))
    .sort((a, b) => a.name.localeCompare(b.name))

  const addAndOpen = async (exerciseId) => {
    if (addingExerciseId) return
    setAddingExerciseId(exerciseId)
    const ok = await dispatch({
      type: 'ADD_SESSION_EXERCISE',
      payload: { exerciseId, assignment: 'both' },
    })
    if (!ok) setAddingExerciseId(null)
  }

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
        <div>
          <SectionLabel
            action={<span className="meta" style={{ color: COLORS.textSecondary }}>{standardExercises.length} exercises</span>}
            style={{ marginBottom: 8 }}
          >
            Standard plan
          </SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {standardExercises.map((se, idx) => (
              <ExerciseRow
                key={se.id}
                state={state}
                session={session}
                se={se}
                index={idx}
                active={se.id === activeExercise?.id}
                now={now}
                onOpen={() => nav(`/session/exercise/${se.id}`)}
              />
            ))}
          </div>
        </div>

        {addedExercises.length > 0 && (
          <div style={separatedSection}>
            <SectionLabel
              action={<span className="meta" style={{ color: COLORS.textSecondary }}>Not in standard plan</span>}
              style={{ marginBottom: 8 }}
            >
              Added today
            </SectionLabel>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {addedExercises.map((se) => (
                <ExerciseRow
                  key={se.id}
                  state={state}
                  session={session}
                  se={se}
                  active={se.id === activeExercise?.id}
                  extra
                  now={now}
                  onOpen={() => nav(`/session/exercise/${se.id}`)}
                />
              ))}
            </div>
          </div>
        )}

        <div style={separatedSection}>
          <SectionLabel
            action={<span className="meta" style={{ color: COLORS.textSecondary }}>{libraryNotInSession.length} available</span>}
            style={{ marginBottom: 6 }}
          >
            Optional exercises
          </SectionLabel>
          <div style={{ fontSize: 12, lineHeight: 1.4, color: COLORS.textSecondary, marginBottom: 10 }}>
            Not part of the standard plan · tap to add for {people.length > 1 ? 'both' : people[0]?.name}
          </div>
          {libraryNotInSession.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {libraryNotInSession.map((ex) => {
                const isAdding = addingExerciseId === ex.id
                const addBusy = !!addingExerciseId
                return (
                  <button
                    key={ex.id}
                    onClick={() => addAndOpen(ex.id)}
                    disabled={addBusy}
                    aria-label={`Add ${ex.name} for ${people.length > 1 ? 'both' : people[0]?.name}`}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      gap: 12,
                      width: '100%',
                      minHeight: 52,
                      background: COLORS.card,
                      borderRadius: RADII.sm,
                      padding: '10px 12px',
                      border: `1px dashed ${COLORS.rule}`,
                      opacity: addBusy && !isAdding ? 0.5 : 1,
                      cursor: addBusy ? 'default' : 'pointer',
                    }}
                  >
                    <div style={{ minWidth: 0, textAlign: 'left' }}>
                      <div className="display" style={{ fontSize: 15, textTransform: 'uppercase' }}>{ex.name}</div>
                      <div style={{ fontSize: 11, color: COLORS.textSecondary, marginTop: 2 }}>{ex.equipment || ex.category}</div>
                    </div>
                    <span
                      className="meta"
                      style={{ display: 'flex', alignItems: 'center', gap: 6, color: COLORS.textSecondary, flexShrink: 0 }}
                    >
                      {isAdding ? 'Adding…' : <><span>{people.length > 1 ? 'Both' : people[0]?.name}</span><Icon name="plus" size={13} /></>}
                    </span>
                  </button>
                )
              })}
            </div>
          ) : (
            <div style={{ fontSize: 13, color: COLORS.textSecondary, padding: '10px 0' }}>
              Every library exercise is already in today&apos;s session.
            </div>
          )}
        </div>
      </div>

      {/* Finish confirmation (PRD FR-220 — warns about incomplete items) */}
      <Sheet open={finishOpen} onClose={() => setFinishOpen(false)} title="Finish workout?">
        {incomplete.length > 0 ? (
          <div style={{ marginBottom: 20 }}>
            <div style={{ fontSize: 14, color: COLORS.textSecondary, marginBottom: 12 }}>
              Some exercises aren't done yet:
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
                  {se.addedDuringSession && (
                    <span className="meta" style={{ marginLeft: 8, color: COLORS.textSecondary }}>extra</span>
                  )}
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

function ExerciseRow({ state, session, se, index, active, extra = false, now, onOpen }) {
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
            {extra ? (
              <span className="meta" style={extraMarker}>Extra</span>
            ) : (
              <span className="num display" style={{ fontSize: 20, color: COLORS.textSecondary }}>
                {String(index + 1).padStart(2, '0')}
              </span>
            )}
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
      {extra ? (
        <span className="meta" style={{ ...extraMarker, minWidth: 45, textAlign: 'center' }}>Extra</span>
      ) : (
        <span className="num display" style={{ fontSize: 19, color: COLORS.textSecondary, minWidth: 24 }}>
          {String(index + 1).padStart(2, '0')}
        </span>
      )}
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

const separatedSection = {
  marginTop: 8,
  paddingTop: 16,
  borderTop: `${BORDER}px dashed ${COLORS.rule}`,
}

const extraMarker = {
  color: COLORS.textSecondary,
  border: `1px dashed ${COLORS.rule}`,
  borderRadius: RADII.sm,
  padding: '3px 6px',
  flexShrink: 0,
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
