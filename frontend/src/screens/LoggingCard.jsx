import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById, effectiveExerciseId } from '../store/reducer.js'
import { sessionSets, lastTimeFor, lastSetValues } from '../lib/selectors.js'
import { useNow, timerState } from '../lib/useNow.js'
import { setSummary } from '../lib/format.js'
import { personPalette, COLORS, FONTS, RADII, BORDER } from '../theme.js'
import { Icon } from '../components/Icon.jsx'
import { ValueInput } from '../components/Stepper.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { Snackbar } from '../components/Snackbar.jsx'
import { EditSetSheet } from '../components/EditSetSheet.jsx'
import { IdentityBand } from '../components/IdentityBand.jsx'
import { TimerRing } from '../components/TimerRing.jsx'
import { SetLedger } from '../components/SetLedger.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
import { PrimaryButton } from '../components/Button.jsx'
import { VARIANTS, variantLabel } from '../lib/variants.js'

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
  const [variantOpen, setVariantOpen] = useState(false)
  const [skipFor, setSkipFor] = useState(null) // personId
  const [skipReason, setSkipReason] = useState('')
  const [subFor, setSubFor] = useState(null)
  const [notesFor, setNotesFor] = useState(null)
  const [editingSetId, setEditingSetId] = useState(null)

  if (!session || !se) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <button onClick={() => nav('/session')} style={backLinkStyle}>Back to session</button>
      </div>
    )
  }

  const exercise = state.exercises[se.exerciseId]
  const variant = se.variant || 'normal'
  const people = se.appliesTo
    .filter((pid) => se.perPerson[pid]?.status !== 'skipped')
    .map((pid) => personById(state, pid))

  // Lazy default inputs from a person's own last values (never the partner's).
  const getInputs = (personId) => {
    if (inputs[personId]) return inputs[personId]
    const exId = effectiveExerciseId(se, personId)
    const last =
      sessionSets(session, se.id, personId, variant).slice(-1)[0] ||
      lastSetValues(state, personId, exId, variant)
    return { weight: last?.weight ?? '', reps: last?.reps ?? '', duration: last?.duration ?? '', note: '' }
  }
  const setField = (personId, field, value) =>
    setInputs((s) => ({ ...s, [personId]: { ...getInputs(personId), [field]: value } }))

  const fillFromSet = (personId, set) =>
    setInputs((s) => ({
      ...s,
      [personId]: {
        ...(s[personId] || getInputs(personId)),
        weight: set.weight ?? '',
        reps: set.reps ?? '',
        duration: set.duration ?? '',
      },
    }))

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
    const last =
      sessionSets(session, se.id, personId, variant).slice(-1)[0] ||
      lastSetValues(state, personId, exId, variant)
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

  // Resolve the set being edited (rows in the THIS SESSION ledger) + the other
  // participant it could be reassigned to.
  const editSet = editingSetId ? session.sets.find((s) => s.id === editingSetId) : null
  const editOtherId = editSet ? se.appliesTo.find((id) => id !== editSet.personId) : null
  const editOther = editOtherId ? personById(state, editOtherId) : null

  return (
    <div style={{ padding: '52px 0 14px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* header */}
      <div style={{ padding: '4px 20px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav('/session')} aria-label="Back to session" style={{ color: COLORS.text }}>
            <Icon name="chevronLeft" size={10} style={{ height: 17 }} />
          </button>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <button
              onClick={() => setVariantOpen(true)}
              style={{
                ...headerPill,
                // tint the pill so a non-default variant is visible at a glance
                borderColor: variant !== 'normal' ? COLORS.primary : COLORS.rule,
                color: variant !== 'normal' ? COLORS.primaryText : COLORS.text,
              }}
            >
              {variantLabel(variant)}
              <Icon name="chevronDown" size={9} />
            </button>
            {!isSingle ? (
              <button onClick={() => setModeOpen(true)} style={headerPill}>
                {MODE_LABELS[se.loggingMode]}
                <Icon name="chevronDown" size={9} />
              </button>
            ) : (
              <span className="meta" style={{ color: COLORS.textSecondary }}>{people[0]?.name} only</span>
            )}
          </div>
          <span style={{ color: COLORS.text }}><Icon name="dots" size={16} /></span>
        </div>
        <div
          className="display"
          style={{ fontSize: 30, marginTop: 12, textTransform: 'uppercase', lineHeight: 1.05 }}
        >
          {exercise?.name}
        </div>
        <div style={{ height: 3, background: COLORS.rule, margin: '8px 0 6px' }} />
        <div className="meta" style={{ color: COLORS.textSecondary }}>{exercise?.category}</div>
      </div>

      {/* rows */}
      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {people.map((person, idx) => {
          const isActive = se.activePersonId === person.id || isSingle
          // The identity band sits on alternating sides so the composition
          // itself reads as the phone being passed back and forth (guide §13).
          const side = idx === 0 ? 'left' : 'right'
          if (isTurns && !isActive) {
            return (
              <WaitingRow
                key={person.id}
                state={state}
                session={session}
                se={se}
                variant={variant}
                person={person}
                side={side}
                now={now}
              />
            )
          }
          return (
            <ActiveRow
              key={person.id}
              state={state}
              session={session}
              se={se}
              variant={variant}
              person={person}
              side={side}
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
              onFillSet={(set) => fillFromSet(person.id, set)}
              onActivate={() => dispatch({ type: 'SET_ACTIVE_ROW', payload: { sessionExerciseId: se.id, personId: person.id } })}
            />
          )
        })}

        {/* secondary actions */}
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 4, padding: '2px 0 4px' }}>
          <ActionBtn icon="pencil" label="Notes" onClick={() => setNotesFor(se.activePersonId || people[0].id)} />
          <ActionBtn icon="skip" label="Skip" onClick={() => setSkipFor(se.activePersonId || people[0].id)} />
          <ActionBtn icon="swap" label="Substitute" onClick={() => setSubFor(se.activePersonId || people[0].id)} />
          <ActionBtn icon="mode" label="Variant" onClick={() => setVariantOpen(true)} />
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
        <div style={sheetHelp}>
          <b>Alternate</b> shows both rows live and passes after each set. <b>Turns</b> shows one at a time.
          <b> Independent</b> never switches automatically.
        </div>
      </Sheet>

      {/* variant sheet */}
      <Sheet open={variantOpen} onClose={() => setVariantOpen(false)} title="Training variant">
        <Segmented
          variant="cards"
          options={VARIANTS}
          value={variant}
          onChange={(v) => {
            dispatch({ type: 'SET_VARIANT', payload: { sessionExerciseId: se.id, variant: v } })
            setVariantOpen(false)
          }}
        />
        <div style={sheetHelp}>
          Each variant keeps its own history: last time, suggested values and set numbers
          only count sets logged under the selected variant.
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
                  background: COLORS.card,
                  border: `${BORDER}px solid ${COLORS.rule}`,
                  borderRadius: RADII.md,
                  padding: '13px 14px',
                  marginBottom: 20,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                <span
                  style={{
                    width: 36,
                    height: 36,
                    background: COLORS.text,
                    color: COLORS.onDark,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <Icon name="arrowRight" size={16} />
                </span>
                <span style={{ flex: 1 }}>
                  <span className="display" style={{ display: 'block', fontSize: 16, textTransform: 'uppercase' }}>
                    Skip this turn
                  </span>
                  <span style={{ display: 'block', fontSize: 13, color: COLORS.textSecondary, marginTop: 2 }}>
                    Pass to {otherName(people, se.activePersonId || skipFor)} — keep doing the exercise
                  </span>
                </span>
              </button>
            )}

            <SectionLabel style={{ marginBottom: 12 }}>Skip the exercise</SectionLabel>
            {!isSingle && (
              <PersonPicker people={people} value={skipFor} onChange={setSkipFor} />
            )}
            <input
              value={skipReason}
              onChange={(e) => setSkipReason(e.target.value)}
              placeholder="Reason (optional) · e.g. shoulder"
              style={sheetInput}
            />
            <PrimaryButton
              onClick={() => {
                dispatch({ type: 'SKIP_EXERCISE', payload: { sessionExerciseId: se.id, personId: skipFor, reason: skipReason } })
                setSkipFor(null)
                setSkipReason('')
                nav('/session')
              }}
              style={{ marginTop: 14 }}
            >
              Skip exercise for {personById(state, skipFor)?.name}
            </PrimaryButton>
          </>
        )}
      </Sheet>

      {/* substitute sheet */}
      <Sheet open={!!subFor} onClose={() => setSubFor(null)} title="Substitute exercise">
        {subFor && (
          <>
            {!isSingle && <PersonPicker people={people} value={subFor} onChange={setSubFor} />}
            <div style={{ fontSize: 13, color: COLORS.textSecondary, margin: '0 0 12px' }}>
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
                    style={pickRow}
                  >
                    <div style={{ textAlign: 'left' }}>
                      <div className="display" style={{ fontSize: 16, textTransform: 'uppercase' }}>{ex.name}</div>
                      <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 2 }}>{ex.equipment || ex.category}</div>
                    </div>
                    <Icon name="chevronRight" size={9} />
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
            <div style={{ fontSize: 13, color: COLORS.textSecondary, margin: '0 0 12px' }}>
              Added to {personById(state, notesFor)?.name}'s next set.
            </div>
            <textarea
              value={getInputs(notesFor).note}
              onChange={(e) => setField(notesFor, 'note', e.target.value)}
              placeholder="e.g. felt heavy, increase next time"
              rows={3}
              style={{ ...sheetInput, resize: 'none' }}
            />
            <PrimaryButton onClick={() => setNotesFor(null)} style={{ marginTop: 14 }}>Done</PrimaryButton>
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

function ActiveRow({ state, session, se, variant, person, side, isActive, isTurns, isSingle, otherName, now, vals, onField, onLog, onRepeat, onEditSet, onFillSet, onActivate }) {
  const pal = personPalette(person)
  const exId = effectiveExerciseId(se, person.id)
  const exercise = state.exercises[exId]
  const tracks = exercise?.tracks || {}
  const doneSets = sessionSets(session, se.id, person.id, variant)
  const setNo = doneSets.length + 1
  const lt = lastTimeFor(state, person.id, exId, variant)

  const timer = session.timers[person.id]
  const onThis = timer && timer.sessionExerciseId === se.id
  const ts = onThis ? timerState(timer, now) : { state: 'none' }
  const hasLast = !!(doneSets.slice(-1)[0] || lt)

  const subbed = se.perPerson[person.id]?.substituteExerciseId
  const band = <IdentityBand person={person} active={isActive} width={32} side={side} />

  return (
    <div
      onClick={!isActive ? onActivate : undefined}
      style={{
        display: 'flex',
        background: COLORS.card,
        border: `${isActive ? BORDER : 1}px solid ${isActive ? pal.accent : COLORS.ruleSoft}`,
        borderRadius: RADII.md,
        overflow: 'hidden',
      }}
    >
      {side === 'left' && band}
      <div style={{ flex: 1, minWidth: 0, padding: 14 }}>
        {/* who + which set + rest state */}
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="display" style={{ fontSize: 22, textTransform: 'uppercase', color: pal.text }}>
              {person.name}
            </div>
            <div
              className="num"
              style={{ fontFamily: FONTS.heading, fontWeight: 700, fontSize: 14, letterSpacing: '0.06em', marginTop: 2 }}
            >
              SET {String(setNo).padStart(2, '0')}
            </div>
            {isActive && isTurns && (
              <div
                className="meta"
                style={{
                  display: 'inline-block',
                  marginTop: 8,
                  background: pal.accent,
                  color: pal.onAccent,
                  padding: '3px 8px',
                }}
              >
                Your turn
              </div>
            )}
          </div>
          <TimerRing ts={ts} total={onThis ? timer.durationSeconds : 0} size={74} />
        </div>

        {subbed && (
          <div
            className="meta"
            style={{
              marginTop: 10,
              color: COLORS.text,
              background: COLORS.warning,
              padding: '5px 9px',
              display: 'inline-block',
            }}
          >
            Doing {exercise?.name} instead today
          </div>
        )}

        {/* this session — the count and the edit hint ride in the header rather
            than costing two extra lines above the inputs */}
        {doneSets.length > 0 && (
          <div style={{ marginTop: 12 }}>
            <SectionLabel
              action={
                <span className="meta" style={{ color: COLORS.textSecondary }}>
                  {doneSets.length} {doneSets.length === 1 ? 'set' : 'sets'} · tap to edit
                </span>
              }
            >
              This session
            </SectionLabel>
            <SetLedger
              sets={doneSets}
              exercise={exercise}
              unit={person.unit}
              palette={pal}
              onEdit={onEditSet}
            />
          </div>
        )}

        {/* last time */}
        <div style={{ marginTop: 12 }}>
          <SectionLabel
            action={
              lt ? (
                <span className="meta" style={{ color: COLORS.textSecondary }}>
                  {lt.sets.length} {lt.sets.length === 1 ? 'set' : 'sets'} · tap to fill
                </span>
              ) : null
            }
          >
            {/* sessions with no label fall back to "Last" in selectors.js — don't
                render that as the stuttering "LAST TIME · LAST" */}
            {lt ? (lt.label === 'Last' ? 'Last time' : `Last time · ${lt.label}`) : 'No previous sets'}
          </SectionLabel>
          {lt && (
            <SetLedger
              sets={lt.sets}
              exercise={exercise}
              unit={person.unit}
              palette={pal}
              muted
              onSelect={onFillSet}
            />
          )}
        </div>

        {/* inputs */}
        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
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
        <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
          <PrimaryButton
            onClick={(e) => { e.stopPropagation(); onLog() }}
            color={pal.accent}
            pressColor={pal.press}
            style={{ flex: 1, width: 'auto', minHeight: 48, fontSize: 16 }}
          >
            {isTurns && !isSingle ? (
              <>Log &amp; pass to {otherName} <Icon name="arrowRight" size={15} /></>
            ) : (
              <>Log set · {person.name}</>
            )}
          </PrimaryButton>
          <button
            onClick={(e) => { e.stopPropagation(); onRepeat() }}
            disabled={!hasLast}
            aria-label="Repeat last set"
            title="Repeat last set"
            style={{
              width: 48,
              minHeight: 48,
              borderRadius: RADII.md,
              background: COLORS.card,
              border: `${BORDER}px solid ${hasLast ? COLORS.rule : COLORS.disabled}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: hasLast ? COLORS.text : COLORS.disabled,
              flexShrink: 0,
            }}
          >
            <Icon name="repeat" size={18} />
          </button>
        </div>
      </div>
      {side === 'right' && band}
    </div>
  )
}

function WaitingRow({ state, session, se, variant, person, side, now }) {
  const pal = personPalette(person)
  const exId = effectiveExerciseId(se, person.id)
  const done = sessionSets(session, se.id, person.id, variant)
  const setNo = done.length + 1
  const last = done.slice(-1)[0]
  const timer = session.timers[person.id]
  const onThis = timer && timer.sessionExerciseId === se.id
  const ts = onThis ? timerState(timer, now) : { state: 'ready' }
  const band = <IdentityBand person={person} width={28} side={side} />

  return (
    <div
      style={{
        display: 'flex',
        background: COLORS.card,
        border: `1px solid ${COLORS.ruleSoft}`,
        borderRadius: RADII.md,
        overflow: 'hidden',
      }}
    >
      {side === 'left' && band}
      <div style={{ flex: 1, minWidth: 0, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="display" style={{ fontSize: 18, textTransform: 'uppercase', color: pal.text }}>
            {person.name}
          </div>
          <div
            className="num"
            style={{ fontFamily: FONTS.heading, fontWeight: 700, fontSize: 13, letterSpacing: '0.06em', marginTop: 1 }}
          >
            SET {String(setNo).padStart(2, '0')} · UP NEXT
          </div>
          <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 3 }}>
            {last
              ? `Just logged ${setSummary(last, state.exercises[exId], person.unit)}`
              : 'Waiting for their turn'}
          </div>
        </div>
        <TimerRing ts={ts} total={onThis ? timer.durationSeconds : 0} size={62} stroke={5} />
      </div>
      {side === 'right' && band}
    </div>
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
    <button
      onClick={onClick}
      style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 5,
        padding: '9px 2px',
        border: `${BORDER}px solid ${COLORS.ruleSoft}`,
        borderRadius: RADII.sm,
        color: COLORS.text,
        background: COLORS.card,
      }}
    >
      <Icon name={icon} size={15} />
      {/* tight tracking so the longest label ("Substitute") still fits its cell */}
      <span className="meta" style={{ fontSize: 9, letterSpacing: '0.02em' }}>{label}</span>
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

// Small bordered blocks in the card header (variant / logging mode).
const headerPill = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
  padding: '6px 10px',
  background: COLORS.card,
  border: `${BORDER}px solid ${COLORS.rule}`,
  borderRadius: RADII.sm,
  fontFamily: FONTS.heading,
  fontSize: 13,
  fontWeight: 700,
  textTransform: 'uppercase',
  letterSpacing: '0.04em',
}

// Shared styles for the bottom-sheet forms (skip / substitute / notes).
const sheetInput = {
  width: '100%',
  background: COLORS.card,
  border: `${BORDER}px solid ${COLORS.rule}`,
  borderRadius: RADII.sm,
  padding: '13px 14px',
  fontSize: 15,
  fontWeight: 500,
  color: COLORS.text,
  outline: 'none',
}

const sheetHelp = {
  fontSize: 13,
  color: COLORS.textSecondary,
  marginTop: 14,
  lineHeight: 1.5,
}

const pickRow = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  background: COLORS.card,
  border: `${BORDER}px solid ${COLORS.ruleSoft}`,
  borderRadius: RADII.sm,
  padding: '12px 14px',
}

const backLinkStyle = {
  fontFamily: FONTS.heading,
  fontWeight: 700,
  fontSize: 15,
  textTransform: 'uppercase',
  letterSpacing: '0.04em',
  color: COLORS.primaryText,
  borderBottom: `2px solid ${COLORS.primary}`,
}
