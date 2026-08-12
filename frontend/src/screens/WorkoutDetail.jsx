import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { personTotals } from '../lib/selectors.js'
import { formatDate, formatElapsed, trimNum } from '../lib/format.js'
import { personPalette, COLORS, RADII } from '../theme.js'
import { Avatar } from '../components/Avatar.jsx'
import { EditSetSheet } from '../components/EditSetSheet.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
import { StatBlock } from '../components/StatBlock.jsx'
import { SetLedger } from '../components/SetLedger.jsx'
import { DangerButton, PrimaryButton } from '../components/Button.jsx'
import { variantLabel } from '../lib/variants.js'

export function WorkoutDetail() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { id } = useParams()
  const session = state.history.find((s) => s.id === id)
  const [editingSetId, setEditingSetId] = useState(null)
  const [confirmDelete, setConfirmDelete] = useState(false)

  if (!session) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <div className="display" style={{ fontSize: 22, textTransform: 'uppercase', marginBottom: 16 }}>
          Workout not found
        </div>
        <button
          onClick={() => nav('/history')}
          className="meta"
          style={{ color: COLORS.primaryText, borderBottom: `2px solid ${COLORS.primaryText}`, paddingBottom: 2 }}
        >
          Past workouts
        </button>
      </div>
    )
  }

  const people = (session.participantIds || []).map((pid) => personById(state, pid)).filter(Boolean)
  const editSet = editingSetId ? session.sets.find((s) => s.id === editingSetId) : null
  const editOther = editSet ? people.find((p) => p.id !== editSet.personId) : null
  const duration = session.endTime ? formatElapsed(session.endTime - session.startTime) : '—'
  const exerciseCount = new Set(session.sets.map((s) => s.exerciseId)).size

  // Exercise order: by first appearance in the set list (works for both seeded
  // history and finished sessions, regardless of whether `exercises` exists).
  const order = []
  session.sets.forEach((s) => {
    if (!order.includes(s.exerciseId)) order.push(s.exerciseId)
  })

  // Only leave the screen once the server confirms — on failure we stay put so
  // the ErrorBar lands where the user acted.
  const remove = async () => {
    if (await dispatch({ type: 'DELETE_WORKOUT', payload: { sessionId: session.id } })) {
      nav('/history')
    } else {
      setConfirmDelete(false)
    }
  }

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 20px 12px' }}>
        <button onClick={() => nav('/history')} className="meta" style={{ color: COLORS.textSecondary }}>
          ← Past workouts
        </button>
        <div className="display" style={{ fontSize: 28, textTransform: 'uppercase', marginTop: 8, lineHeight: 1.02 }}>
          {session.name}
        </div>
        <div style={{ height: 3, background: COLORS.rule, margin: '10px 0 8px' }} />
        <div className="meta" style={{ color: COLORS.textSecondary }}>{formatDate(session.startTime)}</div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {/* shared session figures */}
        <div style={{ background: COLORS.darkSurface, borderRadius: RADII.sm, padding: '15px 16px' }}>
          <SectionLabel tone="dark" style={{ marginBottom: 12 }}>Shared session</SectionLabel>
          <div style={{ display: 'flex', gap: 12 }}>
            <StatBlock value={duration} label="duration" tone="dark" size={26} />
            <StatBlock value={exerciseCount} label="exercises" tone="dark" size={26} />
            <StatBlock value={session.sets.length} label="total sets" tone="dark" size={26} />
          </div>
        </div>

        {/* per-person totals */}
        {people.map((person) => {
          const pal = personPalette(person)
          const t = personTotals(session, person.id, state.exercises)
          return (
            <div
              key={person.id}
              style={{
                display: 'flex',
                background: COLORS.card,
                border: `1px solid ${COLORS.ruleSoft}`,
                borderLeft: `6px solid ${pal.accent}`,
                borderRadius: RADII.sm,
                overflow: 'hidden',
              }}
            >
              <div style={{ flex: 1, minWidth: 0, padding: '13px 15px' }}>
                <div className="display" style={{ fontSize: 17, textTransform: 'uppercase', color: pal.text, marginBottom: 10 }}>
                  {person.name}
                </div>
                <div style={{ display: 'flex', gap: 12 }}>
                  <StatBlock value={t.exercises} label="exercises" size={22} />
                  <StatBlock value={t.sets} label="sets" size={22} />
                  <StatBlock value={trimNum(t.volume)} label={`volume ${person.unit}`} size={22} flex={1.4} />
                </div>
              </div>
            </div>
          )
        })}

        {/* per-exercise breakdown */}
        <SectionLabel
          style={{ marginTop: 6 }}
          action={<span className="meta" style={{ fontSize: 10, color: COLORS.textMuted }}>Tap a set to edit</span>}
        >
          Exercises
        </SectionLabel>
        {order.map((exId) => {
          const exercise = state.exercises[exId]
          return (
            <div key={exId} style={{ background: COLORS.card, borderRadius: RADII.sm, border: `1px solid ${COLORS.ruleSoft}`, padding: '12px 14px' }}>
              <div className="display" style={{ fontSize: 16, textTransform: 'uppercase', marginBottom: 8 }}>
                {exercise?.name || 'Removed exercise'}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {people.map((person) => {
                  const sets = session.sets
                    .filter((s) => s.exerciseId === exId && s.personId === person.id)
                    .sort((a, b) => a.setIndex - b.setIndex)
                  if (sets.length === 0) return null
                  const pal = personPalette(person)
                  // One ledger per training variant, in first-appearance order;
                  // sets from before the feature count as "normal".
                  const groups = []
                  sets.forEach((s) => {
                    const v = s.variant || 'normal'
                    const g = groups.find((g) => g.variant === v)
                    if (g) g.sets.push(s)
                    else groups.push({ variant: v, sets: [s] })
                  })
                  return groups.map((g, gi) => (
                    <div key={`${person.id}_${g.variant}`}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 3 }}>
                        {gi === 0 ? (
                          <Avatar person={person} size={17} fontSize={10} />
                        ) : (
                          <span style={{ width: 17, flexShrink: 0 }} />
                        )}
                        <span className="meta" style={{ fontSize: 10, color: pal.text }}>
                          {person.name}
                          {g.variant !== 'normal' ? ` · ${variantLabel(g.variant)}` : ''}
                        </span>
                      </div>
                      <SetLedger
                        sets={g.sets}
                        exercise={exercise}
                        unit={person.unit}
                        palette={pal}
                        onEdit={setEditingSetId}
                      />
                    </div>
                  ))
                })}
              </div>
            </div>
          )
        })}

        <DangerButton onClick={() => setConfirmDelete(true)} style={{ marginTop: 4, flexShrink: 0 }}>
          Delete workout
        </DangerButton>
      </div>

      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title={`Delete ${session.name}?`}>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 20 }}>
          This permanently removes this workout and all {session.sets.length}{' '}
          {session.sets.length === 1 ? 'set' : 'sets'} logged in it. Your exercises and routines stay
          intact, but the &ldquo;last time&rdquo; hints while logging will fall back to an earlier session.
        </div>
        <PrimaryButton onClick={remove}>Delete workout</PrimaryButton>
        <button
          onClick={() => setConfirmDelete(false)}
          className="meta"
          style={{ width: '100%', padding: 14, marginTop: 8, color: COLORS.textSecondary }}
        >
          Keep it
        </button>
      </Sheet>

      <EditSetSheet
        open={!!editingSetId}
        onClose={() => setEditingSetId(null)}
        set={editSet}
        exercise={editSet && state.exercises[editSet.exerciseId]}
        person={editSet && personById(state, editSet.personId)}
        otherPerson={editOther}
        onSave={(values) => { dispatch({ type: 'EDIT_HISTORY_SET', payload: { sessionId: session.id, setId: editingSetId, values } }); setEditingSetId(null) }}
        onReassign={(toPersonId) => { dispatch({ type: 'REASSIGN_HISTORY_SET', payload: { sessionId: session.id, setId: editingSetId, toPersonId } }); setEditingSetId(null) }}
        onDelete={() => { dispatch({ type: 'DELETE_HISTORY_SET', payload: { sessionId: session.id, setId: editingSetId } }); setEditingSetId(null) }}
      />
    </div>
  )
}
