import { BORDER, COLORS, FONTS, RADII } from '../theme.js'

// A failed action used to be invisible (console only), so screens just kept
// showing their empty state — e.g. "No active workout." after a start that never
// landed. This surfaces the real HTTP failure instead. Direct, uppercase wording
// per guide §28 ("SET COULD NOT BE SAVED"), never "something went wrong". Unlike
// Snackbar it does not auto-dismiss: a lost mutation is worth an explicit
// acknowledgement.
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
        border: `${BORDER}px solid ${COLORS.primary}`,
        borderRadius: RADII.sm,
        padding: '12px 14px',
        display: 'flex',
        alignItems: 'flex-start',
        gap: 12,
        animation: 'snackbar-in var(--motion-default) var(--ease-default)',
      }}
    >
      <span style={{ width: 6, alignSelf: 'stretch', background: COLORS.primary, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="meta"
          style={{ fontSize: 13, color: COLORS.onDark, fontWeight: 700 }}
        >
          {labelFor(error.action)} failed
        </div>
        <div
          style={{
            fontSize: 12,
            marginTop: 4,
            color: COLORS.onDarkMuted,
            lineHeight: 1.4,
            wordBreak: 'break-word',
          }}
        >
          {error.message}
        </div>
      </div>
      <button
        onClick={onDismiss}
        style={{
          fontFamily: FONTS.heading,
          fontSize: 13,
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: '0.04em',
          color: COLORS.onDark,
          borderBottom: `2px solid ${COLORS.primary}`,
          paddingBottom: 1,
        }}
      >
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
