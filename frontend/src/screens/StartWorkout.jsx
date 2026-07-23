import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { COLORS } from '../theme.js'
import { Avatar } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { PrimaryButton } from '../components/Button.jsx'

export function StartWorkout() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const { templateId } = useParams()
  const tpl = state.templates[templateId]
  const owner = ownerOf(state)
  const partner = partnerOf(state)

  const [participants, setParticipants] = useState(state.settings.defaultParticipants)
  const [style, setStyle] = useState(state.settings.defaultLoggingStyle)

  if (!tpl) return null

  const start = () => {
    const ids =
      participants === 'owner'
        ? [owner.id]
        : participants === 'partner'
          ? [partner.id]
          : [owner.id, partner.id]
    dispatch({ type: 'START_SESSION', payload: { templateId, participantIds: ids, loggingStyle: style } })
    nav('/session')
  }

  const options = [
    { value: 'owner', label: `${owner.name} only`, people: [owner] },
    { value: 'partner', label: `${partner.name} only`, people: [partner] },
    { value: 'both', label: `${owner.name} + ${partner.name}`, people: [owner, partner] },
  ]

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: COLORS.darkBackdrop }}>
      <div style={{ padding: '74px 24px 0', opacity: 0.3 }}>
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 25, color: '#fff' }}>{tpl.name}</div>
        <div style={{ color: 'rgba(255,255,255,.8)', fontSize: 14, marginTop: 6 }}>
          {tpl.exercises.length} exercises · about 60 min
        </div>
      </div>
      <div style={{ flex: 1 }} onClick={() => nav('/')} />

      <div style={{ background: COLORS.appBg, borderRadius: '28px 28px 0 0', padding: '12px 20px 40px', animation: 'sheet-up .25s cubic-bezier(.2,.8,.2,1)' }}>
        <div style={{ width: 36, height: 5, borderRadius: 3, background: '#D2D4D8', margin: '0 auto 18px' }} />
        <div style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 22, marginBottom: 18, letterSpacing: '-.3px' }}>
          Start {tpl.name}
        </div>

        <Label>PARTICIPANTS</Label>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginBottom: 20 }}>
          {options.map((o) => {
            const selected = participants === o.value
            return (
              <button
                key={o.value}
                onClick={() => setParticipants(o.value)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 11,
                  padding: '12px 14px',
                  background: '#fff',
                  borderRadius: 12,
                  border: selected ? '1.5px solid #0F1115' : '1px solid rgba(15,17,21,.07)',
                  boxShadow: selected ? '0 4px 14px rgba(15,17,21,.07)' : 'none',
                  textAlign: 'left',
                }}
              >
                <div style={{ display: 'flex' }}>
                  {o.people.map((p, i) => (
                    <Avatar key={p.id} person={p} size={30} radius={9} style={i > 0 ? { marginLeft: -8, border: '2px solid #fff' } : undefined} />
                  ))}
                </div>
                <span style={{ flex: 1, fontWeight: selected ? 700 : 600, fontSize: 15 }}>{o.label}</span>
                {selected ? (
                  <span style={{ width: 22, height: 22, borderRadius: '50%', background: '#0F1115', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name="check" size={12} />
                  </span>
                ) : (
                  <span style={{ width: 20, height: 20, borderRadius: '50%', border: '1.5px solid #D2D4D8' }} />
                )}
              </button>
            )
          })}
        </div>

        <Label>LOGGING STYLE</Label>
        <div style={{ marginBottom: 16 }}>
          <Segmented
            variant="cards"
            options={[
              { value: 'alternate', label: 'Alternate' },
              { value: 'turns', label: 'Turns' },
              { value: 'independent', label: 'Independent' },
            ]}
            value={style}
            onChange={setStyle}
          />
        </div>

        <div style={{ fontSize: 12, color: COLORS.textMuted, lineHeight: 1.45, marginBottom: 18 }}>
          Changing participants here only affects this session — your routine stays the same.
        </div>

        <PrimaryButton onClick={start} style={{ height: 52, fontSize: 17 }} shadow="0 4px 16px rgba(43,102,224,.28)">
          Start workout
        </PrimaryButton>
      </div>
    </div>
  )
}

function Label({ children }) {
  return (
    <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, marginBottom: 10 }}>
      {children}
    </div>
  )
}
