import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { personTotals } from '../lib/selectors.js'
import { setChip, formatDate, formatElapsed, trimNum } from '../lib/format.js'
import { personPalette, COLORS } from '../theme.js'
import { Avatar } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { EditSetSheet } from '../components/EditSetSheet.jsx'
import { Sheet } from '../components/Sheet.jsx'

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
        <div style={{ fontSize: 16, color: COLORS.textSecondary, marginBottom: 16 }}>Workout not found.</div>
        <button onClick={() => nav('/history')} style={{ color: COLORS.primary, fontWeight: 700 }}>Past workouts</button>
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
      <div style={{ padding: '0 22px 14px' }}>
        <button onClick={() => nav('/history')} style={{ color: COLORS.textMuted, fontSize: 15 }}>
          Past workouts
        </button>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 24, marginTop: 8, letterSpacing: '-.3px' }}>
          {session.name}
        </div>
        <div style={{ fontSize: 13, color: COLORS.textMuted, marginTop: 3 }}>{formatDate(session.startTime)}</div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 11 }}>
        {/* shared hero */}
        <div style={{ background: COLORS.darkSurface, borderRadius: 16, padding: 16, color: '#fff' }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: 'rgba(255,255,255,.45)', marginBottom: 13 }}>
            SHARED SESSION
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <Stat value={duration} label="duration" dark />
            <Stat value={exerciseCount} label="exercises" dark />
            <Stat value={session.sets.length} label="total sets" dark />
          </div>
        </div>

        {/* per-person totals */}
        {people.map((person) => {
          const pal = personPalette(person)
          const t = personTotals(session, person.id, state.exercises)
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

        {/* per-exercise breakdown */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', margin: '8px 4px 0' }}>
          <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted }}>EXERCISES</span>
          <span style={{ fontSize: 10.5, color: COLORS.textMuted }}>Tap a set to edit</span>
        </div>
        {order.map((exId) => {
          const exercise = state.exercises[exId]
          return (
            <div key={exId} style={{ background: '#fff', borderRadius: 14, border: '1px solid rgba(15,17,21,.05)', padding: '13px 14px' }}>
              <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 10 }}>
                {exercise?.name || 'Removed exercise'}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
                {people.map((person) => {
                  const sets = session.sets
                    .filter((s) => s.exerciseId === exId && s.personId === person.id)
                    .sort((a, b) => a.setIndex - b.setIndex)
                  if (sets.length === 0) return null
                  const pal = personPalette(person)
                  return (
                    <div key={person.id} style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                      <Avatar person={person} size={22} radius={6} fontSize={11} />
                      <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', flex: 1 }}>
                        {sets.map((s) => (
                          <button
                            key={s.id}
                            onClick={() => setEditingSetId(s.id)}
                            className="num"
                            style={{ fontSize: 12, fontWeight: 600, color: pal.text, background: pal.tint, padding: '3px 9px', borderRadius: 6, cursor: 'pointer' }}
                          >
                            {setChip(s, exercise)}
                          </button>
                        ))}
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          )
        })}

        <button
          onClick={() => setConfirmDelete(true)}
          style={{
            marginTop: 4,
            height: 48,
            borderRadius: 12,
            background: '#fff',
            border: '1px solid rgba(214,51,108,.25)',
            color: '#D6336C',
            fontWeight: 700,
            fontSize: 15,
            flexShrink: 0,
          }}
        >
          Delete workout
        </button>
      </div>

      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title={`Delete ${session.name}?`}>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 16 }}>
          This permanently removes this workout and all {session.sets.length}{' '}
          {session.sets.length === 1 ? 'set' : 'sets'} logged in it. Your exercises and routines stay
          intact, but the &ldquo;last time&rdquo; hints while logging will fall back to an earlier session.
        </div>
        <button
          onClick={remove}
          style={{ width: '100%', height: 50, borderRadius: 13, background: '#D6336C', color: '#fff', fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}
        >
          Delete workout
        </button>
        <button onClick={() => setConfirmDelete(false)} style={{ width: '100%', padding: 12, marginTop: 8, fontWeight: 600, color: COLORS.textMuted }}>
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
