import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { COLORS } from '../theme.js'
import { Avatar, PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { PrimaryButton } from '../components/Button.jsx'

const MODE_LABELS = { alternate: 'Alternate sets', turns: 'Turns', independent: 'Independent' }

export function RoutineBuilder() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { id } = useParams()
  const tpl = state.templates[id]
  const owner = ownerOf(state)
  const partner = partnerOf(state)

  const [editing, setEditing] = useState(null) // exerciseId being assigned
  const [adding, setAdding] = useState(false)
  const [modeOpen, setModeOpen] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)

  if (!tpl) return null

  const save = (patch) => dispatch({ type: 'SAVE_TEMPLATE', payload: { ...tpl, ...patch } })

  const assignmentLabel = (a) => (a === 'both' ? 'Both of you' : a === 'owner' ? `${owner.name} only` : `${partner.name} only`)
  const peopleFor = (a) => (a === 'both' ? [owner, partner] : a === 'owner' ? [owner] : [partner])

  const setAssignment = (exerciseId, assignment) => {
    dispatch({ type: 'SET_ASSIGNMENT', payload: { templateId: id, exerciseId, assignment } })
    setEditing(null)
  }

  const addExercise = (exerciseId, assignment) => {
    save({ exercises: [...tpl.exercises, { exerciseId, assignment, order: tpl.exercises.length }] })
    setAdding(false)
  }

  const removeExercise = (exerciseId) => {
    save({ exercises: tpl.exercises.filter((e) => e.exerciseId !== exerciseId) })
    setEditing(null)
  }

  const remove = () => {
    dispatch({ type: 'DELETE_TEMPLATE', payload: { templateId: id } })
    nav('/')
  }

  const libraryNotInTemplate = Object.values(state.exercises).filter(
    (ex) => !tpl.exercises.some((te) => te.exerciseId === ex.id),
  )

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 22px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav('/')} style={{ color: COLORS.textMuted, fontSize: 15 }}>
            Routines
          </button>
          <button onClick={() => nav('/')} style={{ color: COLORS.primary, fontSize: 15, fontWeight: 700 }}>
            Done
          </button>
        </div>
        <input
          value={tpl.name}
          onChange={(e) => save({ name: e.target.value })}
          placeholder="Routine name"
          style={{
            width: '100%',
            border: 'none',
            outline: 'none',
            background: 'transparent',
            fontFamily: "'Archivo', sans-serif",
            fontWeight: 700,
            fontSize: 25,
            marginTop: 8,
            letterSpacing: '-.4px',
            padding: 0,
          }}
        />
        <div style={{ display: 'flex', gap: 8, marginTop: 11 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '6px 11px', borderRadius: 8, background: '#fff', border: '1px solid rgba(15,17,21,.06)', fontSize: 12, fontWeight: 600 }}>
            <PersonPair people={[owner, partner]} size={14} />
            <span>Both</span>
          </div>
          <button
            onClick={() => setModeOpen(true)}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 11px', borderRadius: 8, background: '#fff', border: '1px solid rgba(15,17,21,.06)', fontSize: 12, fontWeight: 600, color: COLORS.textSecondary }}
          >
            {MODE_LABELS[tpl.defaultMode] || 'Alternate sets'}
            <span style={{ color: COLORS.textMuted }}><Icon name="chevronDown" size={9} /></span>
          </button>
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px' }}>
        {tpl.exercises.length > 0 && (
          <div style={{ background: '#fff', borderRadius: 14, overflow: 'hidden', border: '1px solid rgba(15,17,21,.05)' }}>
            {tpl.exercises
              .slice()
              .sort((a, b) => a.order - b.order)
              .map((te, i, arr) => {
                const ex = state.exercises[te.exerciseId]
                return (
                  <button
                    key={te.exerciseId}
                    onClick={() => setEditing(te.exerciseId)}
                    style={{
                      width: '100%',
                      textAlign: 'left',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 11,
                      padding: '13px 14px',
                      borderBottom: i < arr.length - 1 ? '1px solid rgba(15,17,21,.06)' : 'none',
                    }}
                  >
                    <span style={{ color: '#CDD0D6' }}>
                      <Icon name="grip" size={10} />
                    </span>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 700, fontSize: 15 }}>{ex?.name || 'Removed exercise'}</div>
                      <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>{assignmentLabel(te.assignment)}</div>
                    </div>
                    {peopleFor(te.assignment).map((p, idx) => (
                      <Avatar key={p.id} person={p} size={20} radius={6} fontSize={10} style={idx > 0 ? { marginLeft: -6, border: '1.5px solid #fff' } : undefined} />
                    ))}
                  </button>
                )
              })}
          </div>
        )}

        <button
          onClick={() => setAdding(true)}
          style={{
            width: '100%',
            marginTop: 12,
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

        <button
          onClick={() => setConfirmDelete(true)}
          style={{
            width: '100%',
            marginTop: 12,
            height: 48,
            borderRadius: 12,
            background: '#fff',
            border: '1px solid rgba(214,51,108,.25)',
            color: '#D6336C',
            fontWeight: 700,
            fontSize: 15,
          }}
        >
          Delete routine
        </button>
      </div>

      <div style={{ padding: '12px 18px 0' }}>
        <PrimaryButton onClick={() => nav('/')} shadow="0 4px 14px rgba(43,102,224,.22)">
          Save routine
        </PrimaryButton>
      </div>

      {/* Assignment editor + remove */}
      <Sheet open={!!editing} onClose={() => setEditing(null)} title={editing ? `Who does ${state.exercises[editing]?.name || 'this'}?` : ''}>
        {editing && (
          <>
            <Segmented
              variant="cards"
              options={[
                { value: 'owner', label: owner.name },
                { value: 'partner', label: partner.name },
                { value: 'both', label: 'Both' },
              ]}
              value={tpl.exercises.find((e) => e.exerciseId === editing)?.assignment}
              onChange={(v) => setAssignment(editing, v)}
            />
            <div style={{ fontSize: 12, color: COLORS.textMuted, margin: '14px 0', lineHeight: 1.45 }}>
              Changing assignment affects future sessions only — past workouts stay unchanged.
            </div>
            <button
              onClick={() => removeExercise(editing)}
              style={{ width: '100%', height: 46, borderRadius: 12, background: '#fff', border: '1px solid rgba(214,51,108,.25)', color: '#D6336C', fontWeight: 700, fontSize: 14 }}
            >
              Remove from routine
            </button>
          </>
        )}
      </Sheet>

      {/* Default logging style */}
      <Sheet open={modeOpen} onClose={() => setModeOpen(false)} title="Default logging style">
        <Segmented
          variant="cards"
          options={[
            { value: 'alternate', label: 'Alternate' },
            { value: 'turns', label: 'Turns' },
            { value: 'independent', label: 'Independent' },
          ]}
          value={tpl.defaultMode}
          onChange={(v) => {
            save({ defaultMode: v })
            setModeOpen(false)
          }}
        />
        <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 14, lineHeight: 1.45 }}>
          The starting style for new sessions of this routine. You can still switch it per workout.
        </div>
      </Sheet>

      {/* Add exercise */}
      <Sheet open={adding} onClose={() => setAdding(false)} title="Add exercise">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {libraryNotInTemplate.length === 0 && (
            <div style={{ fontSize: 14, color: COLORS.textMuted }}>All your exercises are already in this routine.</div>
          )}
          {libraryNotInTemplate.map((ex) => (
            <button
              key={ex.id}
              onClick={() => addExercise(ex.id, 'both')}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                background: '#fff',
                borderRadius: 12,
                padding: '13px 14px',
                border: '1px solid rgba(15,17,21,.06)',
              }}
            >
              <div style={{ textAlign: 'left' }}>
                <div style={{ fontWeight: 700, fontSize: 15 }}>{ex.name}</div>
                <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 2 }}>{ex.equipment || ex.category}</div>
              </div>
              <span style={{ color: COLORS.primary, fontWeight: 700, fontSize: 13 }}>Add · Both</span>
            </button>
          ))}
        </div>
      </Sheet>

      {/* Delete routine confirm */}
      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title={`Delete ${tpl.name}?`}>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 16 }}>
          This removes the routine. Your exercises and past workout history stay intact.
        </div>
        <button
          onClick={remove}
          style={{ width: '100%', height: 50, borderRadius: 13, background: '#D6336C', color: '#fff', fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}
        >
          Delete routine
        </button>
        <button onClick={() => setConfirmDelete(false)} style={{ width: '100%', padding: 12, marginTop: 8, fontWeight: 600, color: COLORS.textMuted }}>
          Keep it
        </button>
      </Sheet>
    </div>
  )
}
