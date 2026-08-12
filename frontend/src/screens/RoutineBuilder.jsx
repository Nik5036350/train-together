import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { COLORS, FONTS, RADII, BORDER } from '../theme.js'
import { Avatar, PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { PrimaryButton, DangerButton } from '../components/Button.jsx'

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
      <div style={{ padding: '0 20px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav('/')} className="meta" style={{ color: COLORS.textSecondary }}>
            ← Routines
          </button>
          <button onClick={() => nav('/')} className="meta" style={{ color: COLORS.primaryText }}>
            Done
          </button>
        </div>
        <input
          value={tpl.name}
          onChange={(e) => save({ name: e.target.value })}
          placeholder="Routine name"
          aria-label="Routine name"
          className="display"
          style={{
            width: '100%',
            border: 'none',
            outline: 'none',
            background: 'transparent',
            fontSize: 30,
            textTransform: 'uppercase',
            marginTop: 8,
            padding: 0,
            color: COLORS.text,
          }}
        />
        <div style={{ height: 3, background: COLORS.rule, margin: '8px 0 10px' }} />
        <div style={{ display: 'flex', gap: 8 }}>
          <div style={{ ...chip, gap: 8 }}>
            <PersonPair people={[owner, partner].filter(Boolean)} size={14} />
            <span>Both</span>
          </div>
          <button onClick={() => setModeOpen(true)} style={chip}>
            {MODE_LABELS[tpl.defaultMode] || 'Alternate sets'}
            <Icon name="chevronDown" size={9} />
          </button>
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px' }}>
        {tpl.exercises.length > 0 && (
          <div style={{ background: COLORS.card, borderRadius: RADII.sm, overflow: 'hidden', border: `${BORDER}px solid ${COLORS.rule}` }}>
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
                      padding: '12px 14px',
                      borderBottom: i < arr.length - 1 ? `1px solid ${COLORS.ruleSoft}` : 'none',
                    }}
                  >
                    <span className="num display" style={{ fontSize: 16, color: COLORS.textSecondary, minWidth: 22 }}>
                      {String(i + 1).padStart(2, '0')}
                    </span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="display" style={{ fontSize: 16, textTransform: 'uppercase' }}>
                        {ex?.name || 'Removed exercise'}
                      </div>
                      <div className="meta" style={{ fontSize: 10, color: COLORS.textSecondary, marginTop: 3 }}>
                        {assignmentLabel(te.assignment)}
                      </div>
                    </div>
                    {peopleFor(te.assignment).filter(Boolean).map((p, idx) => (
                      <Avatar key={p.id} person={p} size={20} fontSize={11} style={idx > 0 ? { marginLeft: 2 } : undefined} />
                    ))}
                    <span style={{ color: COLORS.disabled }}>
                      <Icon name="grip" size={10} />
                    </span>
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

        <DangerButton onClick={() => setConfirmDelete(true)} style={{ marginTop: 12 }}>
          Delete routine
        </DangerButton>
      </div>

      <div style={{ padding: '12px 18px 0' }}>
        <PrimaryButton onClick={() => nav('/')}>Save routine</PrimaryButton>
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
            <div style={sheetHelp}>
              Changing assignment affects future sessions only — past workouts stay unchanged.
            </div>
            <DangerButton onClick={() => removeExercise(editing)} style={{ marginTop: 16 }}>
              Remove from routine
            </DangerButton>
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
        <div style={sheetHelp}>
          The starting style for new sessions of this routine. You can still switch it per workout.
        </div>
      </Sheet>

      {/* Add exercise */}
      <Sheet open={adding} onClose={() => setAdding(false)} title="Add exercise">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {libraryNotInTemplate.length === 0 && (
            <div style={{ fontSize: 14, color: COLORS.textSecondary }}>All your exercises are already in this routine.</div>
          )}
          {libraryNotInTemplate.map((ex) => (
            <button
              key={ex.id}
              onClick={() => addExercise(ex.id, 'both')}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
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
              <span className="meta" style={{ color: COLORS.primaryText }}>Add · Both</span>
            </button>
          ))}
        </div>
      </Sheet>

      {/* Delete routine confirm */}
      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title={`Delete ${tpl.name}?`}>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 20 }}>
          This removes the routine. Your exercises and past workout history stay intact.
        </div>
        <PrimaryButton onClick={remove}>Delete routine</PrimaryButton>
        <button
          onClick={() => setConfirmDelete(false)}
          className="meta"
          style={{ width: '100%', padding: 14, marginTop: 8, color: COLORS.textSecondary }}
        >
          Keep it
        </button>
      </Sheet>
    </div>
  )
}

const chip = {
  display: 'flex',
  alignItems: 'center',
  gap: 6,
  padding: '6px 10px',
  borderRadius: RADII.sm,
  background: COLORS.card,
  border: `${BORDER}px solid ${COLORS.ruleSoft}`,
  fontFamily: FONTS.heading,
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase',
  letterSpacing: '0.04em',
  color: COLORS.text,
}

const sheetHelp = {
  fontSize: 13,
  color: COLORS.textSecondary,
  marginTop: 14,
  lineHeight: 1.5,
}
