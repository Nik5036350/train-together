import { useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../store/AppContext.jsx'
import { ownerOf, partnerOf, participantsOf } from '../lib/selectors.js'
import { Avatar, PersonPair } from '../components/Avatar.jsx'
import { Icon } from '../components/Icon.jsx'
import { COLORS } from '../theme.js'
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
    <div style={{ padding: '58px 0 38px', display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '0 22px 6px' }}>
        <div style={{ fontSize: 13, color: COLORS.textMuted, fontWeight: 600 }}>Couple Mode</div>
        <div
          style={{
            fontFamily: "'Archivo', sans-serif",
            fontWeight: 700,
            fontSize: 28,
            letterSpacing: '-.5px',
            marginTop: 2,
          }}
        >
          Workouts
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 11 }}>
          <PersonPair people={people} size={24} />
          <span style={{ fontSize: 14, color: COLORS.textSecondary, fontWeight: 500 }}>
            {people.map((p) => p.name).join(' + ')}
          </span>
        </div>
      </div>

      <div className="scroll-area" style={{ flex: 1, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {hasSession && (
          <button
            onClick={() => nav('/session')}
            style={{
              textAlign: 'left',
              background: '#16191F',
              color: '#fff',
              borderRadius: 16,
              padding: 16,
            }}
          >
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: 'rgba(255,255,255,.5)' }}>
              IN PROGRESS
            </div>
            <div style={{ display: 'flex', alignItems: 'center', marginTop: 8, gap: 10 }}>
              <span style={{ fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 18, flex: 1 }}>
                {state.session.name}
              </span>
              <span style={{ fontSize: 13, fontWeight: 700, color: '#86AEF7' }}>Resume →</span>
            </div>
          </button>
        )}

        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, margin: '2px 4px 0' }}>
          ROUTINES
        </div>

        {templates.length === 0 && (
          <div style={{ background: '#fff', border: '1px solid rgba(15,17,21,.05)', borderRadius: 14, padding: '18px 16px', textAlign: 'center' }}>
            <div style={{ fontWeight: 700, fontSize: 15 }}>No routines yet</div>
            <div style={{ fontSize: 13, color: COLORS.textMuted, marginTop: 4, lineHeight: 1.4 }}>
              Create one below, or bring back the example Push Day.
            </div>
            <button
              onClick={() => dispatch({ type: 'RESTORE_DEMO_ROUTINE' })}
              style={{ marginTop: 12, color: COLORS.primary, fontWeight: 700, fontSize: 14 }}
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

        <button
          onClick={createRoutine}
          style={{
            border: '1.5px dashed rgba(15,17,21,.15)',
            borderRadius: 12,
            padding: 13,
            fontSize: 14,
            fontWeight: 600,
            color: COLORS.textSecondary,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 7,
          }}
        >
          <Icon name="plus" size={13} />
          New routine
        </button>

        {recent.length > 0 && (
          <>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '6px 4px 0' }}>
              <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted }}>
                RECENT WORKOUTS
              </span>
              {state.history.length > recent.length && (
                <button onClick={() => nav('/history')} style={{ fontSize: 12, fontWeight: 700, color: COLORS.primary }}>
                  View all
                </button>
              )}
            </div>
            {recent.map((s) => (
              <HistoryCard key={s.id} state={state} session={s} onOpen={() => nav(`/history/${s.id}`)} />
            ))}
          </>
        )}

        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, margin: '6px 4px 0' }}>
          MANAGE
        </div>
        <LinkRow
          label="Past workouts"
          onClick={() => nav('/history')}
          icon={
            <span style={{ width: 26, height: 26, borderRadius: 8, background: '#EDEEF0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#5B616E' }}>
              <Icon name="clock" size={14} />
            </span>
          }
        />
        {people.map((p) => (
          <LinkRow
            key={p.id}
            label={`${p.name} · ${p.isOwner ? 'you' : 'partner'}`}
            onClick={() => nav(`/profile/${p.id}`)}
            icon={<Avatar person={p} size={26} />}
          />
        ))}
        {!partner && (
          <LinkRow
            label="Add a partner"
            onClick={() => nav('/partner')}
            icon={
              <span style={{ width: 26, height: 26, borderRadius: 8, background: '#EDEEF0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#5B616E' }}>
                <Icon name="plus" size={13} />
              </span>
            }
          />
        )}
        <LinkRow
          label="Exercises"
          onClick={() => nav('/exercises')}
          icon={
            <span style={{ width: 26, height: 26, borderRadius: 8, background: '#EDEEF0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#5B616E' }}>
              <Icon name="plus" size={13} />
            </span>
          }
        />

        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.6px', color: COLORS.textMuted, margin: '6px 4px 0' }}>
          DATA &amp; BACKUP
        </div>
        <LinkRow
          label="Export backup"
          onClick={() => exportState(state)}
          icon={
            <span style={{ width: 26, height: 26, borderRadius: 8, background: '#EDEEF0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#5B616E' }}>
              <Icon name="arrowDown" size={14} />
            </span>
          }
        />
        <LinkRow
          label="Import backup"
          onClick={() => importRef.current && importRef.current.click()}
          icon={
            <span style={{ width: 26, height: 26, borderRadius: 8, background: '#EDEEF0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#5B616E' }}>
              <Icon name="arrowUp" size={14} />
            </span>
          }
        />
        <input
          ref={importRef}
          type="file"
          accept="application/json,.json"
          onChange={onImportFile}
          style={{ display: 'none' }}
        />
        <div style={{ fontSize: 11.5, color: COLORS.textMuted, lineHeight: 1.45, margin: '2px 4px 0' }}>
          All your data lives on this device. Export a backup now and then so you never lose your history.
        </div>
      </div>
    </div>
  )
}

function RoutineCard({ tpl, people, onStart, onEdit }) {
  const count = tpl.exercises.length
  return (
    <div style={{ background: '#fff', borderRadius: 16, border: '1px solid rgba(15,17,21,.05)', overflow: 'hidden' }}>
      <button onClick={onEdit} style={{ width: '100%', textAlign: 'left', padding: '15px 16px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ flex: 1, fontFamily: "'Archivo', sans-serif", fontWeight: 700, fontSize: 18 }}>
            {tpl.name}
          </span>
          <PersonPair people={people} size={22} />
        </div>
        <div style={{ fontSize: 13, color: COLORS.textMuted, marginTop: 4 }}>
          {count} exercises · {tpl.defaultMode === 'alternate' ? 'Alternate sets' : tpl.defaultMode}
        </div>
      </button>
      <button
        onClick={onStart}
        style={{
          width: '100%',
          padding: '13px',
          background: COLORS.primary,
          color: '#fff',
          fontFamily: "'Archivo', sans-serif",
          fontWeight: 700,
          fontSize: 15,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 7,
        }}
      >
        Start workout <Icon name="arrowRight" size={15} />
      </button>
    </div>
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
        background: '#fff',
        border: '1px solid rgba(15,17,21,.05)',
        borderRadius: 14,
        padding: '12px 14px',
        textAlign: 'left',
      }}
    >
      {icon}
      <span style={{ flex: 1, fontWeight: 600, fontSize: 15 }}>{label}</span>
      <span style={{ color: '#C2C6CD' }}>
        <Icon name="chevronRight" size={8} />
      </span>
    </button>
  )
}
