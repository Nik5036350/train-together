import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { PERSON_COLORS, resolveColorKey, COLORS, FONTS, RADII } from '../theme.js'
import { PrimaryButton } from '../components/Button.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
import { ColorPicker, textField } from './PartnerSetup.jsx'

// Edit an existing person — works for the owner ("you") or the partner.
export function ProfileEdit() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { id } = useParams()
  const person = personById(state, id)
  const other = state.people.find((p) => p.id !== id && p.active)

  const [name, setName] = useState(person?.name || '')
  const [color, setColor] = useState(resolveColorKey(person?.color))
  const [unit, setUnit] = useState(person?.unit || 'kg')

  if (!person) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <button
          onClick={() => nav('/')}
          className="meta"
          style={{ color: COLORS.primaryText, borderBottom: `2px solid ${COLORS.primaryText}`, paddingBottom: 2 }}
        >
          Back
        </button>
      </div>
    )
  }

  const initial = (name || person.name).trim()[0]?.toUpperCase() || '?'
  const pal = PERSON_COLORS[color]
  // The other person may still hold a legacy key, so compare resolved keys.
  const otherKey = other ? resolveColorKey(other.color) : null

  const save = () => {
    if (!name.trim()) return
    dispatch({
      type: 'UPDATE_PERSON',
      payload: { personId: id, patch: { name: name.trim(), color, unit, initials: initial } },
    })
    nav(-1)
  }

  return (
    <div style={{ padding: '54px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 22px 4px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav(-1)} className="meta" style={{ color: COLORS.textSecondary }}>
            Cancel
          </button>
          <span className="meta">{person.isOwner ? 'Edit your profile' : 'Edit profile'}</span>
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

      <div style={{ display: 'flex', justifyContent: 'center', margin: '26px 0 24px' }}>
        <div style={{ position: 'relative' }}>
          <div
            style={{
              width: 84,
              height: 84,
              borderRadius: RADII.md,
              background: pal.accent,
              color: pal.onAccent,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: FONTS.heading,
              fontWeight: 800,
              fontSize: 40,
            }}
          >
            {initial}
          </div>
          {person.isOwner && (
            <div
              className="meta"
              style={{
                position: 'absolute',
                left: -6,
                top: -6,
                fontSize: 10,
                color: COLORS.onDark,
                background: COLORS.text,
                padding: '3px 7px',
              }}
            >
              You
            </div>
          )}
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 22px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <SectionLabel style={{ marginBottom: 10 }}>Name</SectionLabel>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Name"
            aria-label="Name"
            style={textField}
          />
        </div>

        <div>
          <SectionLabel style={{ marginBottom: 10 }}>Color</SectionLabel>
          <ColorPicker value={color} onChange={setColor} takenKey={otherKey} takenBy={other} />
          {other && (
            <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 10 }}>
              {other.name}'s color is taken — pick a distinct one.
            </div>
          )}
        </div>

        <div>
          <SectionLabel style={{ marginBottom: 10 }}>Default unit</SectionLabel>
          <Segmented
            options={[
              { value: 'kg', label: 'kg' },
              { value: 'lb', label: 'lb' },
            ]}
            value={unit}
            onChange={setUnit}
          />
        </div>
      </div>

      <div style={{ padding: '16px 22px 0' }}>
        <PrimaryButton onClick={save} disabled={!name.trim()}>
          Save
        </PrimaryButton>
      </div>
    </div>
  )
}
