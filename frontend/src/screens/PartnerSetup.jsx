import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { PERSON_COLORS, PERSON_COLOR_KEYS, resolveColorKey, COLORS, FONTS, RADII, BORDER } from '../theme.js'
import { PrimaryButton } from '../components/Button.jsx'
import { Icon } from '../components/Icon.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'

export function PartnerSetup() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const owner = ownerOf(state)
  const existing = partnerOf(state)

  // The owner's stored key may still be a legacy one ("blue"), so resolve it
  // before deciding which identity is already spoken for.
  const ownerKey = owner ? resolveColorKey(owner.color) : null

  const [name, setName] = useState(existing?.name || '')
  const [color, setColor] = useState(
    existing ? resolveColorKey(existing.color) : PERSON_COLOR_KEYS.find((k) => k !== ownerKey),
  )
  const [unit, setUnit] = useState(existing?.unit || 'kg')

  const initial = (name || 'M').trim()[0]?.toUpperCase() || 'M'
  const pal = PERSON_COLORS[color]

  const save = () => {
    if (!name.trim()) return
    dispatch({ type: 'SAVE_PARTNER', payload: { name: name.trim(), color, unit, initials: initial } })
    nav('/')
  }

  return (
    <div style={{ padding: '60px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '4px 22px 0' }}>
        <div className="display" style={{ fontSize: 32, textTransform: 'uppercase', lineHeight: 1 }}>
          Add a training partner
        </div>
        <div style={{ height: 3, background: COLORS.rule, margin: '10px 0 10px' }} />
        <div style={{ fontSize: 14, color: COLORS.textSecondary, lineHeight: 1.5, maxWidth: 320 }}>
          Record both people in one workout. Each history stays completely separate.
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', margin: '26px 0 24px' }}>
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
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 22px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <SectionLabel style={{ marginBottom: 10 }}>Name</SectionLabel>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Partner name"
            aria-label="Partner name"
            autoFocus
            style={textField}
          />
        </div>

        <div>
          <SectionLabel style={{ marginBottom: 10 }}>Color</SectionLabel>
          <ColorPicker value={color} onChange={setColor} takenKey={ownerKey} takenBy={owner} />
          {owner && (
            <div style={{ fontSize: 12, color: COLORS.textSecondary, marginTop: 10 }}>
              {owner.name}'s color is taken — pick a distinct one.
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

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '13px 14px',
            background: COLORS.card,
            borderRadius: RADII.sm,
            border: `1px solid ${COLORS.ruleSoft}`,
          }}
        >
          <span style={{ fontSize: 14, color: COLORS.textSecondary }}>Optional details · bodyweight, age</span>
          <span style={{ color: COLORS.textSecondary }}>
            <Icon name="chevronRight" size={9} />
          </span>
        </div>
      </div>

      <div style={{ padding: '16px 22px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <PrimaryButton onClick={save} disabled={!name.trim()}>
          Save partner
        </PrimaryButton>
        <button onClick={() => nav('/')} className="meta" style={{ color: COLORS.textSecondary, padding: 10 }}>
          Skip for now
        </button>
      </div>
    </div>
  )
}

// Shared identity picker. Swatches are square blocks in the brand palette; the
// one already used by the other person is disabled and labelled with their
// initials, so the constraint is readable without relying on color.
export function ColorPicker({ value, onChange, takenKey, takenBy }) {
  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
      {PERSON_COLOR_KEYS.map((key) => {
        const taken = key === takenKey
        const selected = key === value
        const c = PERSON_COLORS[key]
        return (
          <button
            key={key}
            disabled={taken}
            onClick={() => onChange(key)}
            aria-label={key}
            aria-pressed={selected}
            style={{
              width: 40,
              height: 40,
              borderRadius: RADII.sm,
              background: c.accent,
              opacity: taken ? 0.45 : 1,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: c.onAccent,
              border: `${BORDER}px solid ${selected ? COLORS.rule : 'transparent'}`,
              outline: selected ? `${BORDER}px solid ${COLORS.appBg}` : 'none',
              outlineOffset: -4,
            }}
          >
            {selected && <Icon name="check" size={14} />}
            {taken && (
              <span style={{ fontFamily: FONTS.heading, fontSize: 13, fontWeight: 800 }}>
                {takenBy?.initials}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

export const textField = {
  width: '100%',
  background: COLORS.card,
  border: `${BORDER}px solid ${COLORS.rule}`,
  borderRadius: RADII.sm,
  padding: '13px 14px',
  fontSize: 16,
  fontWeight: 500,
  color: COLORS.text,
  outline: 'none',
}
