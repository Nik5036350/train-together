import { useEffect, useState } from 'react'
import { StatusBar } from './StatusBar.jsx'
import { COLORS } from '../theme.js'

// Renders the app inside an iOS device bezel (dynamic island, status bar, home
// indicator) on desktop, and full-bleed on small screens. The `dark` prop
// flips the status-bar glyphs for dark screens (e.g. the start-workout sheet).
//
// Children receive the scrollable content area below the status bar.
export function DeviceShell({ children, dark = false }) {
  const isMobile = useIsMobile()
  // When installed to the home screen, iOS draws the real status bar and home
  // indicator, so we hide our simulated chrome and inset content by the device
  // safe areas instead. In the desktop bezel / mobile browser we keep the fakes.
  const standalone = useIsStandalone()

  const content = (
    <>
      {/* dynamic island */}
      <div
        style={{
          position: 'absolute',
          top: 11,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 126,
          height: 37,
          borderRadius: 24,
          background: '#000',
          zIndex: 50,
          display: isMobile ? 'none' : 'block',
        }}
      />
      {/* status bar (simulated — hidden when the OS provides a real one) */}
      {!standalone && (
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, zIndex: 40 }}>
          <StatusBar dark={dark} />
        </div>
      )}
      {/* app content (the screen routes scroll within this) */}
      <div
        className="scroll-area"
        style={{
          position: 'absolute',
          top: standalone ? 'env(safe-area-inset-top)' : 0,
          bottom: standalone ? 'env(safe-area-inset-bottom)' : 0,
          left: standalone ? 'env(safe-area-inset-left)' : 0,
          right: standalone ? 'env(safe-area-inset-right)' : 0,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {children}
      </div>
      {/* home indicator (simulated — hidden when the OS provides a real one) */}
      {!standalone && (
        <div
          style={{
            position: 'absolute',
            bottom: 0,
            left: 0,
            right: 0,
            zIndex: 60,
            height: 24,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'flex-end',
            paddingBottom: 8,
            pointerEvents: 'none',
          }}
        >
          <div
            style={{
              width: 139,
              height: 5,
              borderRadius: 100,
              background: dark ? 'rgba(241,230,208,0.7)' : 'rgba(24,24,22,0.28)',
            }}
          />
        </div>
      )}
    </>
  )

  if (isMobile) {
    return (
      <div
        style={{
          position: 'fixed',
          inset: 0,
          background: dark ? COLORS.darkSurface : COLORS.appBg,
          overflow: 'hidden',
        }}
      >
        {content}
      </div>
    )
  }

  return (
    <div
      className="grain"
      style={{
        position: 'relative',
        minHeight: '100vh',
        width: '100%',
        background: COLORS.appBg,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '32px 0',
        overflow: 'hidden',
      }}
    >
      {/* Constructivist backdrop: two opposed diagonals rather than a gradient. */}
      <div
        aria-hidden="true"
        style={{
          position: 'absolute',
          inset: 0,
          pointerEvents: 'none',
          background: `linear-gradient(114deg, ${COLORS.primary} 0 11%, transparent 11.2%),
                       linear-gradient(296deg, ${COLORS.text} 0 9%, transparent 9.2%)`,
        }}
      />
      <div
        style={{
          position: 'relative',
          width: 402,
          height: 874,
          borderRadius: 40,
          overflow: 'hidden',
          background: dark ? COLORS.darkSurface : COLORS.appBg,
          boxShadow: `0 0 0 10px ${COLORS.text}`,
        }}
      >
        {content}
      </div>
    </div>
  )
}

function useIsMobile() {
  const [mobile, setMobile] = useState(
    () => typeof window !== 'undefined' && window.innerWidth < 480,
  )
  useEffect(() => {
    const onResize = () => setMobile(window.innerWidth < 480)
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])
  return mobile
}

// True when launched from the home screen (installed PWA), where iOS supplies
// its own status bar and home indicator. Covers both the standard display-mode
// media query and the iOS-specific navigator.standalone flag.
function useIsStandalone() {
  const [standalone] = useState(() => {
    if (typeof window === 'undefined') return false
    const mql = window.matchMedia && window.matchMedia('(display-mode: standalone)')
    return (mql && mql.matches) || window.navigator.standalone === true
  })
  return standalone
}
