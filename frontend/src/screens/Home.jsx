import { useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf } from '../lib/selectors.js'
import { Avatar, PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { SectionLabel } from '../components/SectionLabel.jsx'
import { COLORS, FONTS, RADII, BORDER } from '../theme.js'
import { HistoryCard } from './WorkoutHistory.jsx'
import { uid } from '../lib/ids.js'
import { exportState, parseImport } from '../lib/backup.js'

export function Home() {
  const { state, dispatch } = useApp()
  const nav = useNavigate()
  const importRef = useRef(null)

  const onImportFile = (e) => {
    const file = e.target.files && e.target.files[0]
    e.target.value = '' // allow re-importing the same file later
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      try {
        const next = parseImport(String(reader.result))
        if (window.confirm('Replace all current data with this backup? This cannot be undone.')) {
          dispatch({ type: 'HYDRATE', state: next })
          nav('/')
        }
      } catch (err) {
        window.alert(err.message || 'Could not import that file.')
      }
    }
    reader.readAsText(file)
  }

  const createRoutine = () => {
    const newId = uid('t')
    dispatch({
      type: 'SAVE_TEMPLATE',
      payload: { id: newId, name: 'New routine', defaultMode: 'alternate', exercises: [] },
    })
    nav(`/routine/${newId}`)
  }
  const owner = ownerOf(state)
  const partner = partnerOf(state)
  const people = [owner, partner].filter(Boolean)
  const templates = Object.values(state.templates)
  const hasSession = !!state.session
  const recent = [...state.history].sort((a, b) => (b.startTime || 0) - (a.startTime || 0)).slice(0, 3)

  return (
    <div style={{ padding: '54px 0 38px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 20px 10px' }}>
        <div className="meta" style={{ color: COLORS.primaryText }}>Train together</div>
        <div className="display" style={{ fontSize: 40, textTransform: 'uppercase', lineHeight: 0.98, marginTop: 4 }}>
          Workouts
        </div>
        <div style={{ height: 4, background: COLORS.rule, margin: '10px 0 10px' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <PersonPair people={people} size={22} />
          <span className="meta" style={{ color: COLORS.textSecondary }}>
            {people.map((p) => p.name).join(' + ')}
          </span>
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '12px 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {hasSession && (
          <button
            onClick={() => nav('/session')}
            style={{
              textAlign: 'left',
              background: COLORS.darkSurface,
              color: COLORS.onDark,
              borderLeft: `6px solid ${COLORS.primary}`,
              borderRadius: RADII.sm,
              padding: '14px 16px',
            }}
          >
            <div className="meta" style={{ color: COLORS.onDarkMuted }}>In progress</div>
            <div style={{ display: 'flex', alignItems: 'center', marginTop: 6, gap: 10 }}>
              <span className="display" style={{ fontSize: 20, textTransform: 'uppercase', flex: 1 }}>
                {state.session.name}
              </span>
              {/* Paper, not red: red on the Ink card is only 3.2:1. The red
                  left edge already carries the accent. */}
              <span className="meta" style={{ color: COLORS.onDark }}>Resume →</span>
            </div>
          </button>
        )}

        <SectionLabel style={{ marginTop: 2 }}>Routines</SectionLabel>

        {templates.length === 0 && (
          <div style={{ background: COLORS.card, border: `${BORDER}px solid ${COLORS.rule}`, borderRadius: RADII.sm, padding: '18px 16px', textAlign: 'center' }}>
            <div className="display" style={{ fontSize: 17, textTransform: 'uppercase' }}>No routines yet</div>
            <div style={{ fontSize: 13, color: COLORS.textSecondary, marginTop: 6, lineHeight: 1.45 }}>
              Create one below, or bring back the example Push Day.
            </div>
            <button
              onClick={() => dispatch({ type: 'RESTORE_DEMO_ROUTINE' })}
              className="meta"
              style={{ marginTop: 14, color: COLORS.primaryText, borderBottom: `2px solid ${COLORS.primaryText}`, paddingBottom: 2 }}
            >
              Restore example Push Day
            </button>
          </div>
        )}

        {templates.map((tpl) => (
          <RoutineCard
            key={tpl.id}
            tpl={tpl}
            people={people}
            onStart={() => nav(`/start/${tpl.id}`)}
            onEdit={() => nav(`/routine/${tpl.id}`)}
          />
        ))}

        <button onClick={createRoutine} style={dashedAction}>
          <Icon name="plus" size={13} />
          New routine
        </button>

        {recent.length > 0 && (
          <>
            <SectionLabel
              style={{ marginTop: 6 }}
              action={
                state.history.length > recent.length ? (
                  <button onClick={() => nav('/history')} className="meta" style={{ fontSize: 11, color: COLORS.primaryText }}>
                    View all
                  </button>
                ) : null
              }
            >
              Recent workouts
            </SectionLabel>
            {recent.map((s) => (
              <HistoryCard key={s.id} state={state} session={s} onOpen={() => nav(`/history/${s.id}`)} />
            ))}
          </>
        )}

        <SectionLabel style={{ marginTop: 6 }}>Manage</SectionLabel>
        <LinkRow label="Past workouts" onClick={() => nav('/history')} icon={<IconTile name="clock" />} />
        {people.map((p) => (
          <LinkRow
            key={p.id}
            label={`${p.name} · ${p.isOwner ? 'you' : 'partner'}`}
            onClick={() => nav(`/profile/${p.id}`)}
            icon={<Avatar person={p} size={28} />}
          />
        ))}
        {!partner && (
          <LinkRow label="Add a partner" onClick={() => nav('/partner')} icon={<IconTile name="plus" size={13} />} />
        )}
        <LinkRow label="Exercises" onClick={() => nav('/exercises')} icon={<IconTile name="plus" size={13} />} />

        <SectionLabel style={{ marginTop: 6 }}>Data &amp; backup</SectionLabel>
        <LinkRow label="Export backup" onClick={() => exportState(state)} icon={<IconTile name="arrowDown" />} />
        <LinkRow
          label="Import backup"
          onClick={() => importRef.current && importRef.current.click()}
          icon={<IconTile name="arrowUp" />}
        />
        <input
          ref={importRef}
          type="file"
          accept="application/json,.json"
          onChange={onImportFile}
          style={{ display: 'none' }}
        />
        <div style={{ fontSize: 12, color: COLORS.textSecondary, lineHeight: 1.5, margin: '2px 2px 0' }}>
          All your data lives on this device. Export a backup now and then so you never lose your history.
        </div>
      </div>
    </div>
  )
}

function RoutineCard({ tpl, people, onStart, onEdit }) {
  const count = tpl.exercises.length
  return (
    <div style={{ background: COLORS.card, borderRadius: RADII.md, border: `${BORDER}px solid ${COLORS.rule}`, overflow: 'hidden' }}>
      <button onClick={onEdit} style={{ width: '100%', textAlign: 'left', padding: '14px 16px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span className="display" style={{ flex: 1, fontSize: 21, textTransform: 'uppercase' }}>
            {tpl.name}
          </span>
          <PersonPair people={people} size={20} />
        </div>
        <div className="meta" style={{ color: COLORS.textSecondary, marginTop: 6, fontSize: 11 }}>
          {count} exercises · {tpl.defaultMode === 'alternate' ? 'Alternate sets' : tpl.defaultMode}
        </div>
      </button>
      <button
        onClick={onStart}
        style={{
          width: '100%',
          padding: '13px',
          background: COLORS.primary,
          color: COLORS.onAccent,
          fontFamily: FONTS.heading,
          fontWeight: 700,
          fontSize: 15,
          textTransform: 'uppercase',
          letterSpacing: '0.04em',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
        }}
      >
        Start workout <Icon name="arrowRight" size={15} />
      </button>
    </div>
  )
}

function IconTile({ name, size = 14 }) {
  return (
    <span
      style={{
        width: 28,
        height: 28,
        background: COLORS.text,
        color: COLORS.onDark,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <Icon name={name} size={size} />
    </span>
  )
}

function LinkRow({ label, onClick, icon }) {
  return (
    <button
      onClick={onClick}
      style={{
        width: '100%',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        background: COLORS.card,
        border: `1px solid ${COLORS.ruleSoft}`,
        borderRadius: RADII.sm,
        padding: '11px 13px',
        textAlign: 'left',
      }}
    >
      {icon}
      <span style={{ flex: 1, fontWeight: 600, fontSize: 15 }}>{label}</span>
      <span style={{ color: COLORS.textSecondary }}>
        <Icon name="chevronRight" size={9} />
      </span>
    </button>
  )
}

const dashedAction = {
  border: `${BORDER}px dashed ${COLORS.rule}`,
  borderRadius: RADII.sm,
  padding: 14,
  fontFamily: FONTS.heading,
  fontSize: 14,
  fontWeight: 700,
  textTransform: 'uppercase',
  letterSpacing: '0.04em',
  color: COLORS.text,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 8,
}
