import { useState } from 'react'
import { Sheet } from './Sheet.jsx'
import { ValueInput } from './Stepper.jsx'
import { Avatar } from './Avatar.jsx'
import { Icon } from './Icon.jsx'
import { personPalette, COLORS } from '../theme.js'

// Self-contained "Edit set" bottom sheet, shared by the live logging card and
// the past-workout detail screen. The caller resolves the set + people and
// supplies the dispatch callbacks (which differ for active vs. history sets).
export function EditSetSheet({ open, onClose, set, exercise, person, otherPerson, onSave, onReassign, onDelete }) {
  return (
    <Sheet open={open} onClose={onClose} title="Edit set">
      {set && (
        <EditSetForm
          key={set.id}
          set={set}
          exercise={exercise}
          person={person}
          otherPerson={otherPerson}
          onSave={onSave}
          onReassign={onReassign}
          onDelete={onDelete}
        />
      )}
    </Sheet>
  )
}

function EditSetForm({ set, exercise, person, otherPerson, onSave, onReassign, onDelete }) {
  const tracks = exercise?.tracks || {}
  const pal = personPalette(person)
  const [vals, setVals] = useState({
    weight: set.weight ?? '',
    reps: set.reps ?? '',
    duration: set.duration ?? '',
  })
  const field = (f, v) => setVals((s) => ({ ...s, [f]: v }))

  return (
    <>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, margin: '0 2px 14px' }}>
        <Avatar person={person} size={26} radius={8} />
        <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 16 }}>{person?.name}</span>
        <span style={{ fontSize: 13, color: COLORS.textMuted, fontWeight: 500 }}>
          {exercise?.name} · Set {set.setIndex + 1}
        </span>
      </div>

      <div style={{ display: 'flex', gap: 9 }}>
        {tracks.weight && (
          <ValueInput label={person?.unit || 'kg'} value={vals.weight} onChange={(v) => field('weight', v)} step={2.5} accent={pal.accent} accentBorder />
        )}
        {tracks.reps && (
          <ValueInput label="reps" value={vals.reps} onChange={(v) => field('reps', v)} step={1} accent={pal.accent} accentBorder />
        )}
        {tracks.duration && (
          <ValueInput label="sec" value={vals.duration} onChange={(v) => field('duration', v)} step={5} accent={pal.accent} accentBorder />
        )}
      </div>

      <button
        onClick={() => onSave({ weight: numOrNull(vals.weight), reps: numOrNull(vals.reps), duration: numOrNull(vals.duration) })}
        style={primaryBtn}
      >
        Save changes
      </button>

      {otherPerson && (
        <button
          onClick={() => onReassign(otherPerson.id)}
          style={{ width: '100%', height: 46, marginTop: 8, borderRadius: 12, background: '#fff', border: '1px solid rgba(15,17,21,.12)', fontWeight: 700, fontSize: 14, color: COLORS.textSecondary, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7 }}
        >
          <Icon name="swap" size={15} />
          Move to {otherPerson.name}
        </button>
      )}

      <button
        onClick={onDelete}
        style={{ width: '100%', height: 46, marginTop: 8, borderRadius: 12, background: '#fff', border: '1px solid rgba(214,51,108,.25)', color: '#D6336C', fontWeight: 700, fontSize: 14 }}
      >
        Delete set
      </button>
    </>
  )
}

const primaryBtn = {
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

function numOrNull(v) {
  if (v === '' || v == null) return null
  return Number(v)
}
