import { useState } from 'react'
import { BORDER, COLORS, FONTS, RADII } from '../theme.js'

// Press state is tracked in JS rather than CSS :active because every button in
// this app is styled inline, and inline declarations win over stylesheet rules.
function usePressed() {
  const [pressed, setPressed] = useState(false)
  return [
    pressed,
    {
      onPointerDown: () => setPressed(true),
      onPointerUp: () => setPressed(false),
      onPointerLeave: () => setPressed(false),
      onPointerCancel: () => setPressed(false),
    },
  ]
}

const baseLabel = {
  fontFamily: FONTS.heading,
  fontWeight: 700,
  textTransform: 'uppercase',
  letterSpacing: '0.04em',
}

// The dominant next action (guide §10.1): Revolution Red fill, Paper label,
// condensed bold, no shadow. `color` overrides the fill with a person's identity
// color when the action belongs to one of them.
export function PrimaryButton({
  children,
  onClick,
  color = COLORS.primary,
  pressColor = COLORS.primaryPress,
  style,
  disabled,
}) {
  const [pressed, handlers] = usePressed()
  const fill = disabled ? COLORS.disabled : pressed ? pressColor : color
  return (
    <button
      {...handlers}
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
      style={{
        ...baseLabel,
        minHeight: 48,
        width: '100%',
        borderRadius: RADII.md,
        background: fill,
        border: `${BORDER}px solid ${fill}`,
        color: COLORS.onAccent,
        fontSize: 16,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        cursor: disabled ? 'default' : 'pointer',
        ...style,
      }}
    >
      {children}
    </button>
  )
}

// Secondary action (guide §10.2): Canvas background, 2px Ink border, Ink text.
export function GhostButton({ children, onClick, style, disabled }) {
  const [pressed, handlers] = usePressed()
  return (
    <button
      {...handlers}
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
      style={{
        ...baseLabel,
        minHeight: 48,
        width: '100%',
        borderRadius: RADII.md,
        background: pressed ? COLORS.appBg : COLORS.card,
        border: `${BORDER}px solid ${disabled ? COLORS.disabled : COLORS.rule}`,
        color: disabled ? COLORS.disabled : COLORS.text,
        fontSize: 15,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        ...style,
      }}
    >
      {children}
    </button>
  )
}

// Destructive action (guide §10.4). Deliberately not a solid red fill — red is
// the primary-action color here, so destructive gets an outlined treatment and
// leans on explicit wording instead.
export function DangerButton({ children, onClick, style, disabled }) {
  const [pressed, handlers] = usePressed()
  return (
    <button
      {...handlers}
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
      style={{
        ...baseLabel,
        minHeight: 48,
        width: '100%',
        borderRadius: RADII.md,
        background: pressed ? COLORS.primary : COLORS.card,
        border: `${BORDER}px solid ${COLORS.primary}`,
        color: pressed ? COLORS.onAccent : COLORS.primaryText,
        fontSize: 15,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        ...style,
      }}
    >
      {children}
    </button>
  )
}
