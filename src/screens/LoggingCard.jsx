import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById, effectiveExerciseId } from '../store/reducer.js'
import { sessionSets, lastTimeFor, lastSetValues } from '../lib/selectors.js'
import { useNow, timerState } from '../lib/useNow.js'
import { setChip, setSummary, formatDuration, trimNum } from '../lib/format.js'
import { personPalette, COLORS } from '../theme.js'
import { Avatar } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { ValueInput } from '../components/Stepper.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { Snackbar } from '../components/Snackbar.jsx'
import { EditSetSheet } from '../components/EditSetSheet.jsx'

const MODE_LABELS = { alternate: 'Alternate', turns: 'Turns', independent: 'Independent' }

export function LoggingCard() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { id } = useParams()
  const session = state.session
  const now = useNow(true)

  const se = session?.exercises.find((e) => e.id === id)
  const [inputs, setInputs] = useState({}) // { [personId]: {weight, reps, duration, note} }
  const [modeOpen, setModeOpen] = useState(false)
  const [skipFor, setSkipFor] = useState(null) // personId
  const [skipReason, setSkipReason] = useState('')
  const [subFor, setSubFor] = useState(null)
  const [notesFor, setNotesFor] = useState(null)
  const [editingSetId, setEditingSetId] = useState(null)

  if (!session || !se) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <button onClick={() => nav('/session')} style={{ color: COLORS.primary, fontWeight: 700 }}>Back to session</button>
      </div>
    )
  }

  const exercise = state.exercises[se.exerciseId]
  const people = se.appliesTo
    .filter((pid) => se.perPerson[pid]?.status !== 'skipped')
    .map((pid) => personById(state, pid))

  // Lazy default inputs from a person's own last values (never the partner's).
  const getInputs = (personId) => {
    if (inputs[personId]) return inputs[personId]
    const exId = effectiveExerciseId(se, personId)
    const last = sessionSets(session, se.id, personId).slice(-1)[0] || lastSetValues(state, personId, exId)
    return { weight: last?.weight ?? '', reps: last?.reps ?? '', duration: last?.duration ?? '', note: '' }
  }
  const setField = (personId, field, value) =>
    setInputs((s) => ({ ...s, [personId]: { ...getInputs(personId), [field]: value } }))

  const log = (personId, source) => {
    const vals = getInputs(personId)
    dispatch({
      type: 'LOG_SET',
      payload: {
        sessionExerciseId: se.id,
        personId,
        values: { weight: numOrNull(vals.weight), reps: numOrNull(vals.reps), duration: numOrNull(vals.duration), note: vals.note },
        source,
      },
    })
    // clear any one-shot note after logging
    setInputs((s) => ({ ...s, [personId]: { ...getInputs(personId), note: '' } }))
  }

  const repeat = (personId) => {
    const exId = effectiveExerciseId(se, personId)
    const last = sessionSets(session, se.id, personId).slice(-1)[0] || lastSetValues(state, personId, exId)
    if (!last) return
    dispatch({
      type: 'LOG_SET',
      payload: {
        sessionExerciseId: se.id,
        personId,
        values: { weight: last.weight, reps: last.reps, duration: last.duration },
        source: 'repeat',
      },
    })
  }

  const isSingle = people.length === 1
  const isTurns = se.loggingMode === 'turns' && !isSingle

  // Snackbar text composition
  let snackText = ''
  let snackPerson = null
  if (state.snackbar && state.snackbar.sessionExerciseId === se.id) {
    snackPerson = personById(state, state.snackbar.personId)
    if (state.snackbar.kind === 'skipturn') {
      const tail = !isSingle ? ` — ${otherName(people, state.snackbar.personId)}'s turn` : ''
      snackText = `Skipped <b>${snackPerson?.name}</b>'s turn${tail}`
    } else {
      const set = session.sets.find((s) => s.id === state.snackbar.setId)
      if (set) {
        const exId = set.exerciseId
        const verb = state.snackbar.kind === 'repeat' ? 'Repeated' : 'Logged'
        const tail = isTurns ? ` — ${otherName(people, set.personId)}'s turn` : ''
        snackText = `${verb} <b>${snackPerson?.name}</b> · ${setSummary(set, state.exercises[exId], snackPerson?.unit)}${tail}`
      }
    }
  }

  // Resolve the set being edited (chips in the THIS SESSION block) + the other
  // participant it could be reassigned to.
  const editSet = editingSetId ? session.sets.find((s) => s.id === editingSetId) : null
  const editOtherId = editSet ? se.appliesTo.find((id) => id !== editSet.personId) : null
  const editOther = editOtherId ? personById(state, editOtherId) : null

  return (
    <div style={{ padding: '52px 0 14px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* header */}
      <div style={{ padding: '4px 20px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav('/session')} style={{ color: COLORS.textMuted }}>
            <Icon name="chevronLeft" size={9} style={{ height: 16 }} />
          </button>
          {!isSingle ? (
            <button
              onClick={() => setModeOpen(true)}
              style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '7px 12px', background: '#fff', border: '1px solid rgba(15,17,21,.07)', borderRadius: 9, fontSize: 13, fontWeight: 700 }}
            >
              {MODE_LABELS[se.loggingMode]}
              <span style={{ color: COLORS.textMuted }}><Icon name="chevronDown" size={9} /></span>
            </button>
          ) : (
            <span style={{ fontSize: 13, fontWeight: 700, color: COLORS.textMuted }}>{people[0]?.name} only</span>
          )}
          <span style={{ color: COLORS.textMuted }}><Icon name="dots" size={18} /></span>
        </div>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 26, marginTop: 11, letterSpacing: '-.5px' }}>
          {exercise?.name}
        </div>
        <div style={{ fontSize: 13, color: COLORS.textMuted, marginTop: 2 }}>{exercise?.category}</div>
      </div>

      {/* rows */}
      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 11 }}>
        {people.map((person) => {
          const isActive = se.activePersonId === person.id || isSingle
          if (isTurns && !isActive) {
            return <WaitingRow key={person.id} state={state} session={session} se={se} person={person} now={now} />
          }
          return (
            <ActiveRow
              key={person.id}
              state={state}
              session={session}
              se={se}
              person={person}
              isActive={isActive}
              isTurns={isTurns}
              isSingle={isSingle}
              otherName={otherName(people, person.id)}
              now={now}
              vals={getInputs(person.id)}
              onField={(f, v) => setField(person.id, f, v)}
              onLog={() => log(person.id)}
              onRepeat={() => repeat(person.id)}
              onEditSet={setEditingSetId}
              onActivate={() => dispatch({ type: 'SET_ACTIVE_ROW', payload: { sessionExerciseId: se.id, personId: person.id } })}
            />
          )
        })}

        {/* secondary actions */}
        <div style={{ display: 'flex', justifyContent: 'space-around', padding: '6px 0', fontSize: 12, fontWeight: 600, color: COLORS.textMuted }}>
          <ActionBtn icon="pencil" label="Notes" onClick={() => setNotesFor(se.activePersonId || people[0].id)} />
          <ActionBtn icon="skip" label="Skip" onClick={() => setSkipFor(se.activePersonId || people[0].id)} />
          <ActionBtn icon="swap" label="Substitute" onClick={() => setSubFor(se.activePersonId || people[0].id)} />
          {!isSingle && <ActionBtn icon="mode" label="Mode" onClick={() => setModeOpen(true)} />}
        </div>
      </div>

      {/* snackbar */}
      <div style={{ padding: '6px 18px 0' }}>
        <Snackbar
          snackbar={state.snackbar && state.snackbar.sessionExerciseId === se.id ? state.snackbar : null}
          person={snackPerson}
          text={snackText}
          onUndo={() => dispatch({ type: 'UNDO_LAST' })}
          onDismiss={() => dispatch({ type: 'CLEAR_SNACKBAR' })}
        />
      </div>

      {/* mode sheet */}
      <Sheet open={modeOpen} onClose={() => setModeOpen(false)} title="Logging style">
        <Segmented
          variant="cards"
          options={[
            { value: 'alternate', label: 'Alternate' },
            { value: 'turns', label: 'Turns' },
            { value: 'independent', label: 'Independent' },
          ]}
          value={se.loggingMode}
          onChange={(v) => {
            dispatch({ type: 'SET_LOGGING_MODE', payload: { sessionExerciseId: se.id, mode: v } })
            setModeOpen(false)
          }}
        />
        <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 14, lineHeight: 1.45 }}>
          <b>Alternate</b> shows both rows live and passes after each set. <b>Turns</b> shows one at a time.
          <b> Independent</b> never switches automatically.
        </div>
      </Sheet>

      {/* skip sheet */}
      <Sheet open={!!skipFor} onClose={() => { setSkipFor(null); setSkipReason('') }} title="Skip">
        {skipFor && (
          <>
            {!isSingle && (
              <button
                onClick={() => {
                  dispatch({ type: 'SKIP_TURN', payload: { sessionExerciseId: se.id, personId: se.activePersonId || skipFor } })
                  setSkipFor(null)
                  setSkipReason('')
                  // stay on the card
                }}
                style={{
                  width: '100%',
                  textAlign: 'left',
                  background: '#fff',
                  border: '1px solid rgba(15,17,21,.08)',
                  borderRadius: 12,
                  padding: '13px 14px',
                  marginBottom: 16,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                <span style={{ width: 34, height: 34, borderRadius: 10, background: '#F1F2F4', color: COLORS.textSecondary, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <Icon name="arrowRight" size={16} />
                </span>
                <span style={{ flex: 1 }}>
                  <span style={{ display: 'block', fontWeight: 700, fontSize: 15 }}>Skip this turn</span>
                  <span style={{ display: 'block', fontSize: 12.5, color: COLORS.textMuted, marginTop: 2 }}>
                    Pass to {otherName(people, se.activePersonId || skipFor)} — keep doing the exercise
                  </span>
                </span>
              </button>
            )}

            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, margin: '0 2px 10px' }}>
              SKIP THE EXERCISE
            </div>
            {!isSingle && (
              <PersonPicker people={people} value={skipFor} onChange={setSkipFor} />
            )}
            <input
              value={skipReason}
              onChange={(e) => setSkipReason(e.target.value)}
              placeholder="Reason (optional) · e.g. shoulder"
              style={sheetInput}
            />
            <button
              onClick={() => {
                dispatch({ type: 'SKIP_EXERCISE', payload: { sessionExerciseId: se.id, personId: skipFor, reason: skipReason } })
                setSkipFor(null)
                setSkipReason('')
                nav('/session')
              }}
              style={sheetPrimary}
            >
              Skip exercise for {personById(state, skipFor)?.name}
            </button>
          </>
        )}
      </Sheet>

      {/* substitute sheet */}
      <Sheet open={!!subFor} onClose={() => setSubFor(null)} title="Substitute exercise">
        {subFor && (
          <>
            {!isSingle && <PersonPicker people={people} value={subFor} onChange={setSubFor} />}
            <div style={{ fontSize: 13, color: COLORS.textSecondary, margin: '4px 2px 10px' }}>
              {personById(state, subFor)?.name} will do this instead — just for today.
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {Object.values(state.exercises)
                .filter((ex) => ex.id !== se.exerciseId)
                .map((ex) => (
                  <button
                    key={ex.id}
                    onClick={() => {
                      dispatch({ type: 'SUBSTITUTE_EXERCISE', payload: { sessionExerciseId: se.id, personId: subFor, substituteExerciseId: ex.id } })
                      setSubFor(null)
                    }}
                    style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: '#fff', borderRadius: 12, padding: '13px 14px', border: '1px solid rgba(15,17,21,.06)' }}
                  >
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontWeight: 700, fontSize: 15 }}>{ex.name}</div>
                      <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>{ex.equipment || ex.category}</div>
                    </div>
                    <Icon name="chevronRight" size={8} />
                  </button>
                ))}
            </div>
          </>
        )}
      </Sheet>

      {/* notes sheet (attached to the next logged set) */}
      <Sheet open={!!notesFor} onClose={() => setNotesFor(null)} title="Set note">
        {notesFor && (
          <>
            <div style={{ fontSize: 13, color: COLORS.textSecondary, margin: '0 2px 10px' }}>
              Added to {personById(state, notesFor)?.name}'s next set.
            </div>
            <textarea
              value={getInputs(notesFor).note}
              onChange={(e) => setField(notesFor, 'note', e.target.value)}
              placeholder="e.g. felt heavy, increase next time"
              rows={3}
              style={{ ...sheetInput, resize: 'none' }}
            />
            <button onClick={() => setNotesFor(null)} style={sheetPrimary}>Done</button>
          </>
        )}
      </Sheet>

      {/* edit-set sheet (correct a set logged this session) */}
      <EditSetSheet
        open={!!editingSetId}
        onClose={() => setEditingSetId(null)}
        set={editSet}
        exercise={editSet && state.exercises[editSet.exerciseId]}
        person={editSet && personById(state, editSet.personId)}
        otherPerson={editOther}
        onSave={(values) => { dispatch({ type: 'EDIT_SET', payload: { setId: editingSetId, values } }); setEditingSetId(null) }}
        onReassign={(toPersonId) => { dispatch({ type: 'REASSIGN_SET', payload: { setId: editingSetId, toPersonId } }); setEditingSetId(null) }}
        onDelete={() => { dispatch({ type: 'DELETE_SET', payload: { setId: editingSetId } }); setEditingSetId(null) }}
      />
    </div>
  )
}

function ActiveRow({ state, session, se, person, isActive, isTurns, isSingle, otherName, now, vals, onField, onLog, onRepeat, onEditSet, onActivate }) {
  const pal = personPalette(person)
  const exId = effectiveExerciseId(se, person.id)
  const exercise = state.exercises[exId]
  const tracks = exercise?.tracks || {}
  const doneSets = sessionSets(session, se.id, person.id)
  const setNo = doneSets.length + 1
  const lt = lastTimeFor(state, person.id, exId)

  const timer = session.timers[person.id]
  const onThis = timer && timer.sessionExerciseId === se.id
  const ts = onThis ? timerState(timer, now) : { state: 'none' }
  const hasLast = !!(sessionSets(session, se.id, person.id).slice(-1)[0] || lt)

  const subbed = se.perPerson[person.id]?.substituteExerciseId

  return (
    <div
      onClick={!isActive ? onActivate : undefined}
      style={{
        background: '#fff',
        borderRadius: 16,
        // Use side-specific longhand (not the `border` shorthand) so it never
        // conflicts with borderLeft when isActive toggles on rerender.
        borderTop: isActive ? `1.5px solid ${pal.accent}` : '1px solid rgba(15,17,21,.06)',
        borderRight: isActive ? `1.5px solid ${pal.accent}` : '1px solid rgba(15,17,21,.06)',
        borderBottom: isActive ? `1.5px solid ${pal.accent}` : '1px solid rgba(15,17,21,.06)',
        borderLeft: `4px solid ${pal.accent}`,
        boxShadow: isActive ? `0 8px 22px ${pal.accent}1A` : 'none',
        padding: 15,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
        <Avatar person={person} size={27} radius={8} />
        <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}>{person.name}</span>
        <span style={{ fontSize: 13, color: COLORS.textMuted, fontWeight: 500 }}>Set {setNo}</span>
        <div style={{ marginLeft: 'auto' }}>
          <TimerBadge ts={ts} isActive={isActive} isTurns={isTurns} pal={pal} />
        </div>
      </div>

      {subbed && (
        <div style={{ marginTop: 10, fontSize: 12, color: '#C2570C', background: '#FBF1E9', padding: '6px 10px', borderRadius: 8 }}>
          Doing {exercise?.name} instead today
        </div>
      )}

      {/* this session */}
      {doneSets.length > 0 && (
        <div style={{ marginTop: 12, background: '#F4F5F7', borderRadius: 10, padding: '9px 11px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 7 }}>
            <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: '.5px', color: COLORS.textMuted }}>
              THIS SESSION
            </span>
            <span style={{ fontSize: 11, fontWeight: 600, color: COLORS.textSecondary }}>{doneSets.length} sets</span>
          </div>
          <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
            {doneSets.map((s) => (
              <button
                key={s.id}
                onClick={(e) => { e.stopPropagation(); onEditSet(s.id) }}
                className="num"
                style={{ fontSize: 12, fontWeight: 700, color: pal.text, background: pal.tint, padding: '3px 9px', borderRadius: 6, cursor: 'pointer' }}
              >
                {setChip(s, exercise)}
              </button>
            ))}
          </div>
          <div style={{ fontSize: 10.5, color: COLORS.textMuted, marginTop: 6 }}>Tap a set to edit</div>
        </div>
      )}

      {/* last time */}
      <div style={{ marginTop: 12, background: '#F4F5F7', borderRadius: 10, padding: '9px 11px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: lt ? 7 : 0 }}>
          <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: '.5px', color: COLORS.textMuted }}>
            {lt ? `LAST TIME · ${lt.label.toUpperCase()}` : 'NO PREVIOUS SETS'}
          </span>
          {lt && <span style={{ fontSize: 11, fontWeight: 600, color: COLORS.textSecondary }}>{lt.sets.length} sets</span>}
        </div>
        {lt && (
          <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
            {lt.sets.map((s) => (
              <span key={s.id} className="num" style={{ fontSize: 12, fontWeight: 600, color: '#0F1115', background: '#fff', border: '1px solid rgba(15,17,21,.08)', padding: '2px 8px', borderRadius: 6 }}>
                {setChip(s, exercise)}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* inputs */}
      <div style={{ display: 'flex', gap: 9, marginTop: 12 }}>
        {tracks.weight && (
          <ValueInput label={person.unit} value={vals.weight} onChange={(v) => onField('weight', v)} step={2.5} accent={pal.accent} accentBorder={isActive} />
        )}
        {tracks.reps && (
          <ValueInput label="reps" value={vals.reps} onChange={(v) => onField('reps', v)} step={1} accent={pal.accent} accentBorder={isActive} />
        )}
        {tracks.duration && (
          <ValueInput label="sec" value={vals.duration} onChange={(v) => onField('duration', v)} step={5} accent={pal.accent} accentBorder={isActive} />
        )}
      </div>

      {/* log + repeat */}
      <div style={{ display: 'flex', gap: 9, marginTop: 10 }}>
        <button
          onClick={(e) => { e.stopPropagation(); onLog() }}
          style={{
            flex: 1,
            height: 46,
            borderRadius: 12,
            background: pal.accent,
            color: '#fff',
            fontFamily: "'Archivo', sans-serif",
            fontWeight: 700,
            fontSize: 15,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            boxShadow: `0 4px 12px ${pal.shadow}`,
          }}
        >
          {isTurns && !isSingle ? (
            <>Log &amp; pass to {otherName} <Icon name="arrowRight" size={15} /></>
          ) : (
            <>Log for {person.name}</>
          )}
        </button>
        <button
          onClick={(e) => { e.stopPropagation(); onRepeat() }}
          disabled={!hasLast}
          style={{
            width: 48,
            height: 46,
            borderRadius: 12,
            background: '#fff',
            border: '1px solid rgba(15,17,21,.12)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: hasLast ? COLORS.textSecondary : '#CDD0D6',
          }}
        >
          <Icon name="repeat" size={17} />
        </button>
      </div>
    </div>
  )
}

function WaitingRow({ state, session, se, person, now }) {
  const pal = personPalette(person)
  const exId = effectiveExerciseId(se, person.id)
  const setNo = sessionSets(session, se.id, person.id).length + 1
  const last = sessionSets(session, se.id, person.id).slice(-1)[0]
  const timer = session.timers[person.id]
  const onThis = timer && timer.sessionExerciseId === se.id
  const ts = onThis ? timerState(timer, now) : { state: 'ready' }

  return (
    <div style={{ background: '#fff', borderRadius: 16, border: '1px solid rgba(15,17,21,.06)', borderLeft: `4px solid ${pal.accent}`, padding: '14px 15px', display: 'flex', alignItems: 'center', gap: 11 }}>
      <div style={{ width: 30, height: 30, borderRadius: 9, background: pal.tint, color: pal.text, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 13 }}>
        {person.initials}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}>{person.name}</span>
          <span style={{ fontSize: 13, color: COLORS.textMuted, fontWeight: 500 }}>Set {setNo}</span>
        </div>
        <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>
          {last ? `Just logged ${setChip(last, state.exercises[exId])} · waiting` : 'Waiting for their turn'}
        </div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 600, color: COLORS.textSecondary, background: '#F1F2F4', padding: '5px 10px', borderRadius: 8 }}>
          <span style={{ color: pal.text }}><Icon name="clock" size={12} /></span>
          {ts.state === 'resting' ? formatDuration(ts.remaining) : 'ready'}
        </span>
        <div style={{ fontSize: 11, color: COLORS.textMuted, marginTop: 5 }}>up next</div>
      </div>
    </div>
  )
}

function TimerBadge({ ts, isActive, isTurns, pal }) {
  if (isActive && isTurns) {
    return (
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 700, color: pal.text, background: pal.tint, padding: '5px 10px', borderRadius: 8 }}>
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: pal.accent }} />
        Your turn
      </span>
    )
  }
  if (ts.state === 'resting') {
    return (
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 600, color: COLORS.textSecondary, background: '#F1F2F4', padding: '5px 10px', borderRadius: 8 }}>
        <span style={{ color: pal.accent }}><Icon name="clock" size={12} /></span>
        {formatDuration(ts.remaining)}
      </span>
    )
  }
  if (ts.state === 'overdue') {
    return (
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 700, color: '#C2570C' }}>
        <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#E2702C' }} />
        Overdue
      </span>
    )
  }
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 600, color: COLORS.success }}>
      <span style={{ width: 7, height: 7, borderRadius: '50%', background: COLORS.success }} />
      Ready
    </span>
  )
}

function PersonPicker({ people, value, onChange }) {
  return (
    <div style={{ marginBottom: 14 }}>
      <Segmented
        variant="cards"
        options={people.map((p) => ({ value: p.id, label: p.name }))}
        value={value}
        onChange={onChange}
      />
    </div>
  )
}

function ActionBtn({ icon, label, onClick }) {
  return (
    <button onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 6, color: COLORS.textMuted, fontSize: 12, fontWeight: 600 }}>
      <Icon name={icon} size={14} />
      {label}
    </button>
  )
}

function otherName(people, personId) {
  const other = people.find((p) => p.id !== personId)
  return other?.name || ''
}

function numOrNull(v) {
  if (v === '' || v == null) return null
  return Number(v)
}

// Shared styles for the bottom-sheet forms (skip / substitute / notes).
const sheetInput = {
  width: '100%',
  background: '#fff',
  border: '1px solid rgba(15,17,21,.10)',
  borderRadius: 12,
  padding: '13px 14px',
  fontSize: 15,
  fontWeight: 500,
  outline: 'none',
}

const sheetPrimary = {
  width: '100%',
  height: 50,
  marginTop: 12,
  borderRadius: 13,
  background: COLORS.primary,
  color: '#fff',
  fontFamily: "'Archivo', sans-serif",
  fontWeight: 700,
  fontSize: 16,
}
