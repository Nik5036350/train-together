import { useState } from 'react'
import { Sheet } from './Sheet.jsx'
import { ValueInput } from './Stepper.jsx'
import { Avatar } from './Avatar.jsx'
import { Icon } from './Icon.jsx'
import { PrimaryButton, GhostButton, DangerButton } from './Button.jsx'
import { personPalette, COLORS, FONTS } from '../theme.js'

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
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '0 0 6px' }}>
        <Avatar person={person} size={28} />
        <span
          className="display"
          style={{ fontSize: 18, textTransform: 'uppercase', color: pal.text }}
        >
          {person?.name}
        </span>
        <span
          className="num"
          style={{ fontFamily: FONTS.heading, fontWeight: 700, fontSize: 15, marginLeft: 'auto' }}
        >
          SET {String(set.setIndex + 1).padStart(2, '0')}
        </span>
      </div>
      <div style={{ fontSize: 13, color: COLORS.textSecondary, marginBottom: 16 }}>{exercise?.name}</div>

      <div style={{ display: 'flex', gap: 10 }}>
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

      <PrimaryButton
        onClick={() => onSave({ weight: numOrNull(vals.weight), reps: numOrNull(vals.reps), duration: numOrNull(vals.duration) })}
        style={{ marginTop: 16 }}
      >
        Save changes
      </PrimaryButton>

      {otherPerson && (
        <GhostButton onClick={() => onReassign(otherPerson.id)} style={{ marginTop: 8 }}>
          <Icon name="swap" size={15} />
          Move to {otherPerson.name}
        </GhostButton>
      )}

      <DangerButton onClick={onDelete} style={{ marginTop: 8 }}>
        Delete set
      </DangerButton>
    </>
  )
}

function numOrNull(v) {
  if (v === '' || v == null) return null
  return Number(v)
}
