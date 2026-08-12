// Inline SVG icon set. Bold, geometric and mechanical (guide §8): thick strokes
// of consistent weight, square caps, built from circles and rectangles with few
// internal details. All icons inherit `currentColor` and accept a `size` prop.

// Shared stroke treatment — one line weight across the whole family.
const S = {
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'square',
  strokeLinejoin: 'miter',
  fill: 'none',
}

const paths = {
  check: <path d="M2 6.6l3 3 6-6.6" {...S} strokeWidth="2" />,
  checkBig: <path d="M4.5 11.2l4.5 4.5 8.5-9.5" {...S} strokeWidth="2.6" />,
  pencil: (
    <>
      <path d="M9.6 2.2l2.2 2.2-7 7H2.6V9.2l7-7z" {...S} strokeWidth="1.7" />
      <path d="M8 3.8l2.2 2.2" {...S} strokeWidth="1.7" />
    </>
  ),
  chevronRight: <path d="M1.6 1.2l5 5.8-5 5.8" {...S} />,
  chevronLeft: <path d="M7.2 1.2l-5 6.8 5 6.8" {...S} />,
  chevronDown: <path d="M1.2 1.6l4.3 4 4.3-4" {...S} />,
  clock: (
    <>
      <circle cx="7" cy="7" r="5.4" {...S} strokeWidth="1.8" />
      <path d="M7 3.6V7h3" {...S} strokeWidth="1.8" />
    </>
  ),
  plus: <path d="M7 1.4v11.2M1.4 7h11.2" {...S} strokeWidth="2.2" />,
  // Repeat set — a closed circular motion with a square arrowhead.
  repeat: (
    <>
      <path d="M14.6 8.5a6.1 6.1 0 1 1-1.8-4.3" {...S} strokeWidth="2" />
      <path d="M14.8 1.4v3.6h-3.6" {...S} strokeWidth="2" />
    </>
  ),
  // Switch person — two opposed arrows, the handoff gesture.
  swap: (
    <>
      <path d="M1.5 3.8h10M8.6 1.2l2.9 2.6-2.9 2.6" {...S} strokeWidth="1.9" />
      <path d="M13.5 9.2h-10M6.4 6.6L3.5 9.2l2.9 2.6" {...S} strokeWidth="1.9" />
    </>
  ),
  // Skip — a solid play block against a stop bar.
  skip: (
    <>
      <path d="M2.6 2.4L9 7l-6.4 4.6V2.4z" fill="currentColor" />
      <path d="M11.4 2.4v9.2" {...S} strokeWidth="2" />
    </>
  ),
  // Logging mode — two rails with a block set on each.
  mode: (
    <>
      <path d="M1.5 4.5h12M1.5 9.5h12" {...S} strokeWidth="1.8" />
      <rect x="3" y="2.6" width="3.8" height="3.8" fill="currentColor" />
      <rect x="8.2" y="7.6" width="3.8" height="3.8" fill="currentColor" />
    </>
  ),
  arrowRight: <path d="M1.4 7h11M8.4 3l4 4-4 4" {...S} strokeWidth="2" />,
  arrowDown: <path d="M7 1.4v10.4M2.8 7.6L7 11.8l4.2-4.2" {...S} strokeWidth="2" />,
  arrowUp: <path d="M7 12.6V2.2M2.8 6.4L7 2.2l4.2 4.2" {...S} strokeWidth="2" />,
  // History / progress — stepped bars rather than a smooth curve.
  trend: (
    <>
      <rect x="0.6" y="7" width="3" height="4.4" fill="currentColor" />
      <rect x="5.5" y="4" width="3" height="7.4" fill="currentColor" />
      <rect x="10.4" y="0.8" width="3" height="10.6" fill="currentColor" />
    </>
  ),
  dots: (
    <>
      <rect x="0" y="0" width="3.6" height="3.6" fill="currentColor" />
      <rect x="7.2" y="0" width="3.6" height="3.6" fill="currentColor" />
      <rect x="14.4" y="0" width="3.6" height="3.6" fill="currentColor" />
    </>
  ),
  grip: (
    <>
      <rect x="1.6" y="1.4" width="2.4" height="2.4" fill="currentColor" />
      <rect x="6" y="1.4" width="2.4" height="2.4" fill="currentColor" />
      <rect x="1.6" y="5.8" width="2.4" height="2.4" fill="currentColor" />
      <rect x="6" y="5.8" width="2.4" height="2.4" fill="currentColor" />
      <rect x="1.6" y="10.2" width="2.4" height="2.4" fill="currentColor" />
      <rect x="6" y="10.2" width="2.4" height="2.4" fill="currentColor" />
    </>
  ),
}

const viewBoxes = {
  check: '0 0 13 13',
  checkBig: '0 0 22 22',
  pencil: '0 0 14 14',
  chevronRight: '0 0 8 14',
  chevronLeft: '0 0 9 16',
  chevronDown: '0 0 11 7',
  clock: '0 0 14 14',
  plus: '0 0 14 14',
  repeat: '0 0 17 17',
  swap: '0 0 15 13',
  skip: '0 0 14 14',
  mode: '0 0 15 14',
  arrowRight: '0 0 15 14',
  arrowDown: '0 0 14 14',
  arrowUp: '0 0 14 14',
  trend: '0 0 14 12',
  dots: '0 0 18 4',
  grip: '0 0 10 14',
}

export function Icon({ name, size = 14, style, className }) {
  const vb = viewBoxes[name] || '0 0 14 14'
  return (
    <span className={`ico ${className || ''}`} style={style}>
      <svg width={size} height={size * heightRatio(vb)} viewBox={vb} fill="none">
        {paths[name]}
      </svg>
    </span>
  )
}

function heightRatio(viewBox) {
  const parts = viewBox.split(' ').map(Number)
  const w = parts[2] || 1
  const h = parts[3] || 1
  return h / w
}
