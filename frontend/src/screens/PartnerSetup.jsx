import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { PERSON_COLORS, COLORS } from '../theme.js'
import { PrimaryButton } from '../components/Button.jsx'
import { Icon } from '../components/Icon.jsx'
import { Segmented } from '../components/Segmented.jsx'

const SWATCHES = ['orange', 'purple', 'green', 'pink', 'blue']

export function PartnerSetup() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const owner = ownerOf(state)
  const existing = partnerOf(state)

  const [name, setName] = useState(existing?.name || '')
  const [color, setColor] = useState(existing?.color || 'orange')
  const [unit, setUnit] = useState(existing?.unit || 'kg')

  const initial = (name || 'M').trim()[0]?.toUpperCase() || 'M'
  const pal = PERSON_COLORS[color]

  const save = () => {
    if (!name.trim()) return
    dispatch({ type: 'SAVE_PARTNER', payload: { name: name.trim(), color, unit, initials: initial } })
    nav('/')
  }

  return (
    <div style={{ padding: '64px 0 30px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '4px 24px 0' }}>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 26, lineHeight: 1.1, letterSpacing: '-.5px' }}>
          Add a training partner
        </div>
        <div style={{ fontSize: 14, color: COLORS.textSecondary, marginTop: 8, lineHeight: 1.4, maxWidth: 300 }}>
          Record both people in one workout. Each history stays completely separate.
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', margin: '30px 0 26px' }}>
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
          <div
            style={{
              position: 'absolute',
              right: -5,
              bottom: -5,
              width: 30,
              height: 30,
              borderRadius: '50%',
              background: '#fff',
              border: '1px solid rgba(15,17,21,.08)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 2px 6px rgba(0,0,0,.08)',
              color: COLORS.textSecondary,
            }}
          >
            <Icon name="pencil" size={14} />
          </div>
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '0 22px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <Field label="NAME">
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Partner name"
            autoFocus
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
              const taken = key === owner?.color
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
                    position: 'relative',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#fff',
                    boxShadow: selected ? `0 0 0 2px #fff, 0 0 0 3.5px ${c.accent}` : 'none',
                  }}
                >
                  {selected && <Icon name="check" size={13} />}
                  {taken && <span style={{ fontSize: 11, fontWeight: 700 }}>{owner?.initials}</span>}
                </button>
              )
            })}
          </div>
          <div style={{ fontSize: 12, color: COLORS.textMuted, marginTop: 8 }}>
            {owner?.name}'s color is taken — pick a distinct one.
          </div>
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

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '13px 14px',
            background: '#fff',
            borderRadius: 12,
            border: '1px solid rgba(15,17,21,.07)',
          }}
        >
          <span style={{ fontSize: 14, color: COLORS.textSecondary }}>Optional details · bodyweight, age</span>
          <span style={{ color: '#C2C6CD' }}>
            <Icon name="chevronRight" size={8} />
          </span>
        </div>
      </div>

      <div style={{ padding: '16px 22px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <PrimaryButton onClick={save} disabled={!name.trim()}>
          Save partner
        </PrimaryButton>
        <button onClick={() => nav('/')} style={{ textAlign: 'center', fontSize: 14, fontWeight: 600, color: COLORS.textMuted, padding: 8 }}>
          Skip for now
        </button>
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
