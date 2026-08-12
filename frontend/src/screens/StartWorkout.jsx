import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { COLORS, RADII, BORDER } from '../theme.js'
import { Avatar } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { Segmented } from '../components/Segmented.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
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
  const [starting, setStarting] = useState(false)

  if (!tpl) return null

  // Navigate only once the backend has actually created the session. Going to
  // /session optimistically showed "No active workout." for the whole round-trip
  // — and forever if the request failed. The in-flight guard also matters
  // because each tap is a fresh POST and the backend discards the previously
  // active session, so a double-tap would destroy the session the first created.
  const start = async () => {
    if (starting) return
    const ids =
      participants === 'owner'
        ? [owner.id]
        : participants === 'partner'
          ? [partner.id]
          : [owner.id, partner.id]
    setStarting(true)
    const ok = await dispatch({
      type: 'START_SESSION',
      payload: { templateId, participantIds: ids, loggingStyle: style },
    })
    setStarting(false)
    if (ok) nav('/session')
  }

  const options = [
    { value: 'owner', label: `${owner.name} only`, people: [owner] },
    { value: 'partner', label: `${partner.name} only`, people: [partner] },
    { value: 'both', label: `${owner.name} + ${partner.name}`, people: [owner, partner] },
  ]

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: COLORS.darkBackdrop }}>
      <div style={{ padding: '74px 24px 0', opacity: 0.4 }}>
        <div className="display" style={{ fontSize: 28, textTransform: 'uppercase', color: COLORS.onDark }}>
          {tpl.name}
        </div>
        <div className="meta" style={{ color: COLORS.onDarkMuted, marginTop: 8 }}>
          {tpl.exercises.length} exercises · about 60 min
        </div>
      </div>
      <div style={{ flex: 1 }} onClick={() => nav('/')} />

      <div
        style={{
          background: COLORS.appBg,
          borderTop: `${BORDER}px solid ${COLORS.rule}`,
          borderRadius: `${RADII.lg}px ${RADII.lg}px 0 0`,
          padding: '12px 20px 40px',
          animation: 'sheet-up var(--motion-slow) var(--ease-default)',
        }}
      >
        <div style={{ width: 40, height: 4, background: COLORS.rule, margin: '0 auto 18px' }} />
        <div className="display" style={{ fontSize: 26, textTransform: 'uppercase', marginBottom: 6 }}>
          Start {tpl.name}
        </div>
        <div style={{ height: 3, background: COLORS.rule, marginBottom: 18 }} />

        <SectionLabel style={{ marginBottom: 12 }}>Participants</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 22 }}>
          {options.map((o) => {
            const selected = participants === o.value
            return (
              <button
                key={o.value}
                onClick={() => setParticipants(o.value)}
                aria-pressed={selected}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  padding: '11px 13px',
                  background: COLORS.card,
                  borderRadius: RADII.sm,
                  border: `${selected ? BORDER : 1}px solid ${selected ? COLORS.rule : COLORS.ruleSoft}`,
                  textAlign: 'left',
                }}
              >
                <div style={{ display: 'flex', gap: BORDER }}>
                  {o.people.map((p) => (
                    <Avatar key={p.id} person={p} size={30} />
                  ))}
                </div>
                <span
                  className="display"
                  style={{ flex: 1, fontSize: 16, textTransform: 'uppercase', color: selected ? COLORS.text : COLORS.textSecondary }}
                >
                  {o.label}
                </span>
                {selected ? (
                  <span
                    style={{
                      width: 22,
                      height: 22,
                      background: COLORS.text,
                      color: COLORS.onDark,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                    }}
                  >
                    <Icon name="check" size={12} />
                  </span>
                ) : (
                  <span style={{ width: 22, height: 22, border: `${BORDER}px solid ${COLORS.disabled}`, flexShrink: 0 }} />
                )}
              </button>
            )
          })}
        </div>

        <SectionLabel style={{ marginBottom: 12 }}>Logging style</SectionLabel>
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

        <div style={{ fontSize: 13, color: COLORS.textSecondary, lineHeight: 1.5, marginBottom: 18 }}>
          Changing participants here only affects this session — your routine stays the same.
        </div>

        <PrimaryButton onClick={start} disabled={starting} style={{ minHeight: 54, fontSize: 17 }}>
          {starting ? 'Starting…' : 'Start workout'}
        </PrimaryButton>
      </div>
    </div>
  )
}
