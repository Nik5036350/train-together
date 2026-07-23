// Bottom-sheet modal with a dimmed backdrop and grabber. Used for skip,
// substitute, add-exercise, change-mode, and finish confirmations.
export function Sheet({ open, onClose, title, children }) {
  if (!open) return null
  return (
    <div
      onClick={onClose}
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 80,
        background: 'rgba(15,17,21,.45)',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
        animation: 'fade-in .15s ease',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: '#F4F5F7',
          borderRadius: '28px 28px 0 0',
          padding: '12px 20px 36px',
          animation: 'sheet-up .22s cubic-bezier(.2,.8,.2,1)',
          maxHeight: '88%',
          overflow: 'auto',
        }}
        className="scroll-area"
      >
        <div
          style={{
            width: 36,
            height: 5,
            borderRadius: 3,
            background: '#D2D4D8',
            margin: '0 auto 18px',
          }}
        />
        {title && (
          <div
            style={{
              fontFamily: "'Archivo', sans-serif",
              fontWeight: 700,
              fontSize: 22,
              marginBottom: 16,
              letterSpacing: '-.3px',
            }}
          >
            {title}
          </div>
        )}
        {children}
      </div>
    </div>
  )
}
