import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { COLORS, RADII, BORDER } from '../theme.js'
import { Icon } from '../components/Icon.jsx'
import { Sheet } from '../components/Sheet.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
import { PrimaryButton, DangerButton } from '../components/Button.jsx'

const TRACK_KEYS = [
  { key: 'weight', label: 'Weight' },
  { key: 'reps', label: 'Reps' },
  { key: 'duration', label: 'Duration' },
]

// Default rest used by the live rest timer until you tweak it during a workout.
const DEFAULT_REST = 90

export function ExerciseCreate() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { id } = useParams()
  const editing = id ? state.exercises[id] : null

  const [name, setName] = useState(editing?.name || '')
  const [tracks, setTracks] = useState(
    editing?.tracks || { weight: true, reps: true, duration: false },
  )
  const [confirmDelete, setConfirmDelete] = useState(false)

  const toggleTrack = (key) => {
    const next = { ...tracks, [key]: !tracks[key] }
    if (!next.weight && !next.reps && !next.duration) return // at least one (DI §6.3)
    setTracks(next)
  }

  const save = () => {
    if (!name.trim()) return
    dispatch({
      type: 'CREATE_EXERCISE', // upserts by id, so this also handles edits
      payload: {
        exercise: {
          id: editing?.id, // undefined for new → reducer assigns one
          name: name.trim(),
          category: editing?.category || '',
          tracks,
          defaultRestSeconds: editing?.defaultRestSeconds || DEFAULT_REST,
        },
        profiles: {}, // no per-person setup up front — everything is logged live
      },
    })
    nav('/exercises')
  }

  const remove = () => {
    dispatch({ type: 'DELETE_EXERCISE', payload: { exerciseId: id } })
    nav('/exercises')
  }

  // Routines that reference this exercise (for the delete warning).
  const usedIn = editing
    ? Object.values(state.templates)
        .filter((t) => t.exercises.some((e) => e.exerciseId === id))
        .map((t) => t.name)
    : []

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav(-1)} className="meta" style={{ color: COLORS.textSecondary }}>
            Cancel
          </button>
          <span className="meta">{editing ? 'Edit exercise' : 'New exercise'}</span>
          <button
            onClick={save}
            className="meta"
            style={{ color: COLORS.primaryText, opacity: name.trim() ? 1 : 0.4 }}
          >
            Save
          </button>
        </div>
        <div style={{ height: 3, background: COLORS.rule, marginTop: 12 }} />
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div>
          <SectionLabel style={{ marginBottom: 10 }}>Exercise</SectionLabel>
          <div style={{ background: COLORS.card, borderRadius: RADII.sm, overflow: 'hidden', border: `${BORDER}px solid ${COLORS.rule}` }}>
            <div style={{ padding: '13px 15px' }}>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Exercise name · e.g. Lat Pulldown"
                aria-label="Exercise name"
                autoFocus={!editing}
                style={{
                  width: '100%',
                  border: 'none',
                  outline: 'none',
                  background: 'transparent',
                  fontWeight: 600,
                  fontSize: 16,
                  color: COLORS.text,
                }}
              />
            </div>
            <div style={{ padding: '13px 15px', borderTop: `${BORDER}px solid ${COLORS.rule}` }}>
              <div className="meta" style={{ color: COLORS.textSecondary, marginBottom: 10 }}>Tracks</div>
              <div style={{ display: 'flex', gap: 8 }}>
                {TRACK_KEYS.map(({ key, label }) => {
                  const on = tracks[key]
                  return (
                    <button
                      key={key}
                      onClick={() => toggleTrack(key)}
                      aria-pressed={on}
                      className="meta"
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 6,
                        padding: '8px 12px',
                        borderRadius: RADII.sm,
                        background: on ? COLORS.text : COLORS.appBg,
                        color: on ? COLORS.onDark : COLORS.textSecondary,
                        border: `${BORDER}px solid ${on ? COLORS.rule : COLORS.ruleSoft}`,
                      }}
                    >
                      {on && <Icon name="check" size={11} />}
                      {label}
                    </button>
                  )
                })}
              </div>
            </div>
          </div>
        </div>

        <div style={{ fontSize: 13, color: COLORS.textSecondary, lineHeight: 1.5, margin: '-4px 2px 0' }}>
          No targets, sets or weights up front — just pick what this exercise tracks and log it live as
          you train. Each person keeps their own separate history automatically.
        </div>

        {editing && (
          <DangerButton onClick={() => setConfirmDelete(true)} style={{ marginTop: 4 }}>
            Delete exercise
          </DangerButton>
        )}
      </div>

      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title={`Delete ${editing?.name}?`}>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 20 }}>
          This removes the exercise from your library.
          {usedIn.length > 0 && (
            <>
              {' '}It's used in <b>{usedIn.join(', ')}</b> — it'll be removed from{' '}
              {usedIn.length === 1 ? 'that routine' : 'those routines'} too.
            </>
          )}{' '}
          Past logged sets stay in history.
        </div>
        <PrimaryButton onClick={remove}>Delete exercise</PrimaryButton>
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
