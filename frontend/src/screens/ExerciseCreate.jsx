import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { COLORS } from '../theme.js'
import { Icon } from '../components/Icon.jsx'
import { Sheet } from '../components/Sheet.jsx'

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
      <div style={{ padding: '0 22px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={() => nav(-1)} style={{ color: COLORS.textMuted, fontSize: 15 }}>
          Cancel
        </button>
        <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 17 }}>
          {editing ? 'Edit exercise' : 'New exercise'}
        </span>
        <button onClick={save} style={{ color: COLORS.primary, fontSize: 15, fontWeight: 700, opacity: name.trim() ? 1 : 0.4 }}>
          Save
        </button>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div>
          <SectionLabel>EXERCISE</SectionLabel>
          <div style={{ background: '#fff', borderRadius: 14, overflow: 'hidden', border: '1px solid rgba(15,17,21,.05)' }}>
            <div style={{ padding: '13px 15px' }}>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Exercise name · e.g. Lat Pulldown"
                autoFocus={!editing}
                style={{
                  width: '100%',
                  border: 'none',
                  outline: 'none',
                  background: 'transparent',
                  fontWeight: 600,
                  fontSize: 16,
                }}
              />
            </div>
            <div style={{ padding: '13px 15px', borderTop: '1px solid rgba(15,17,21,.06)' }}>
              <div style={{ color: COLORS.textSecondary, fontSize: 15, marginBottom: 10 }}>Tracks</div>
              <div style={{ display: 'flex', gap: 8 }}>
                {TRACK_KEYS.map(({ key, label }) => {
                  const on = tracks[key]
                  return (
                    <button
                      key={key}
                      onClick={() => toggleTrack(key)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 6,
                        padding: '7px 12px',
                        borderRadius: 9,
                        background: on ? '#0F1115' : '#EDEEF0',
                        color: on ? '#fff' : '#9AA0AC',
                        fontSize: 13,
                        fontWeight: 600,
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

        <div style={{ fontSize: 12.5, color: COLORS.textMuted, lineHeight: 1.45, margin: '-4px 6px 0' }}>
          No targets, sets or weights up front — just pick what this exercise tracks and log it live as
          you train. Each person keeps their own separate history automatically.
        </div>

        {editing && (
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
            }}
          >
            Delete exercise
          </button>
        )}
      </div>

      <Sheet open={confirmDelete} onClose={() => setConfirmDelete(false)} title={`Delete ${editing?.name}?`}>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 16 }}>
          This removes the exercise from your library.
          {usedIn.length > 0 && (
            <>
              {' '}It's used in <b>{usedIn.join(', ')}</b> — it'll be removed from{' '}
              {usedIn.length === 1 ? 'that routine' : 'those routines'} too.
            </>
          )}{' '}
          Past logged sets stay in history.
        </div>
        <button
          onClick={remove}
          style={{ width: '100%', height: 50, borderRadius: 13, background: '#D6336C', color: '#fff', fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}
        >
          Delete exercise
        </button>
        <button onClick={() => setConfirmDelete(false)} style={{ width: '100%', padding: 12, marginTop: 8, fontWeight: 600, color: COLORS.textMuted }}>
          Keep it
        </button>
      </Sheet>
    </div>
  )
}

function SectionLabel({ children }) {
  return (
    <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, margin: '0 6px 8px' }}>
      {children}
    </div>
  )
}
