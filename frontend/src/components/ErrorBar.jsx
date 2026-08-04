import { COLORS } from '../theme.js'

// A failed action used to be invisible (console only), so screens just kept
// showing their empty state — e.g. "No active workout." after a start that never
// landed. This surfaces the real HTTP failure instead. Styled like Snackbar
// (same dark surface) with a red accent so it reads as an error, not a
// confirmation. Unlike Snackbar it does not auto-dismiss: a lost mutation is
// worth an explicit acknowledgement.
export function ErrorBar({ error, onDismiss }) {
  return (
    <div
      role="alert"
      style={{
        // Anchored to the top: every primary CTA in this app (Start workout,
        // Finish, Log set) sits at the bottom, and covering the button that
        // triggered the failure would block the retry.
        position: 'absolute',
        left: 12,
        right: 12,
        top: 46,
        zIndex: 70,
        background: COLORS.darkSurface,
        border: '1px solid rgba(226,86,86,.45)',
        borderRadius: 12,
        padding: '12px 14px',
        display: 'flex',
        alignItems: 'flex-start',
        gap: 10,
        boxShadow: '0 8px 22px rgba(0,0,0,.28)',
        animation: 'snackbar-in .2s ease',
      }}
    >
      <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#E25656', marginTop: 5 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 700, color: '#fff' }}>{labelFor(error.action)} failed</div>
        <div
          style={{
            fontSize: 11.5,
            marginTop: 3,
            color: 'rgba(255,255,255,.62)',
            lineHeight: 1.4,
            wordBreak: 'break-word',
          }}
        >
          {error.message}
        </div>
      </div>
      <button onClick={onDismiss} style={{ fontSize: 13, fontWeight: 700, color: '#86AEF7' }}>
        Dismiss
      </button>
    </div>
  )
}

const ACTION_LABELS = {
  START_SESSION: 'Starting the workout',
  FINISH_SESSION: 'Finishing the workout',
  DELETE_WORKOUT: 'Deleting the workout',
  LOG_SET: 'Logging the set',
  UNDO_LAST: 'Undoing the set',
  HYDRATE: 'Importing the backup',
  SAVE_TEMPLATE: 'Saving the routine',
  CREATE_EXERCISE: 'Saving the exercise',
}

function labelFor(action) {
  return ACTION_LABELS[action] || action
}
