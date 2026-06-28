import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { personById } from '../store/reducer.js'
import { PERSON_COLORS, COLORS } from '../theme.js'
import { PrimaryButton } from '../components/Button.jsx'
import { Icon } from '../components/Icon.jsx'
import { Segmented } from '../components/Segmented.jsx'

const SWATCHES = ['blue', 'orange', 'purple', 'green', 'pink']

// Edit an existing person — works for the owner ("you") or the partner.
export function ProfileEdit() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { id } = useParams()
  const person = personById(state, id)
  const other = state.people.find((p) => p.id !== id && p.active)

  const [name, setName] = useState(person?.name || '')
  const [color, setColor] = useState(person?.color || 'blue')
  const [unit, setUnit] = useState(person?.unit || 'kg')

  if (!person) {
    return (
      <div style={{ padding: '120px 30px', textAlign: 'center' }}>
        <button onClick={() => nav('/')} style={{ color: COLORS.primary, fontWeight: 700 }}>Back</button>
      </div>
    )
  }

  const initial = (name || person.name).trim()[0]?.toUpperCase() || '?'
  const pal = PERSON_COLORS[color]

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
      <div style={{ padding: '0 22px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={() => nav(-1)} style={{ color: COLORS.textMuted, fontSize: 15 }}>
          Cancel
        </button>
        <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 17 }}>
          {person.isOwner ? 'Edit your profile' : 'Edit profile'}
        </span>
        <button onClick={save} style={{ color: COLORS.primary, fontSize: 15, fontWeight: 700, opacity: name.trim() ? 1 : 0.4 }}>
          Save
        </button>
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', margin: '24px 0 26px' }}>
        <div style={{ position: 'relative' }}>
          <div
            style={{
              width: 80,
              height: 80,
              borderRadius: 24,
              background: pal.accent,
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: "'Archivo', sans-serif",
              fontWeight: 700,
              fontSize: 34,
            }}
          >
            {initial}
          </div>
          {person.isOwner && (
            <div
              style={{
                position: 'absolute',
                left: -6,
                top: -6,
                fontSize: 10,
                fontWeight: 700,
                letterSpacing: '.5px',
                color: '#fff',
                background: '#0F1115',
                padding: '3px 7px',
                borderRadius: 7,
              }}
            >
              YOU
            </div>
          )}
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 22px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <Field label="NAME">
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Name"
            style={{
              width: '100%',
              background: '#fff',
              border: '1px solid rgba(15,17,21,.10)',
              borderRadius: 12,
              padding: '13px 14px',
              fontSize: 16,
              fontWeight: 500,
              outline: 'none',
            }}
          />
        </Field>

        <Field label="COLOR">
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            {SWATCHES.map((key) => {
              const taken = other && key === other.color
              const selected = key === color
              const c = PERSON_COLORS[key]
              return (
                <button
                  key={key}
                  disabled={taken}
                  onClick={() => setColor(key)}
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: 11,
                    background: c.accent,
                    opacity: taken ? 0.4 : 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#fff',
                    boxShadow: selected ? `0 0 0 2px #fff, 0 0 0 3.5px ${c.accent}` : 'none',
                  }}
                >
                  {selected && <Icon name="check" size={13} />}
                  {taken && <span style={{ fontSize: 11, fontWeight: 700 }}>{other?.initials}</span>}
                </button>
              )
            })}
          </div>
          {other && (
            <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 8 }}>
              {other.name}'s color is taken — pick a distinct one.
            </div>
          )}
        </Field>

        <Field label="DEFAULT UNIT">
          <Segmented
            options={[
              { value: 'kg', label: 'kg' },
              { value: 'lb', label: 'lb' },
            ]}
            value={unit}
            onChange={setUnit}
          />
        </Field>
      </div>

      <div style={{ padding: '16px 22px 0' }}>
        <PrimaryButton onClick={save} disabled={!name.trim()}>
          Save
        </PrimaryButton>
      </div>
    </div>
  )
}

function Field({ label, children }) {
  return (
    <div>
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, marginBottom: 8 }}>
        {label}
      </div>
      {children}
    </div>
  )
}
