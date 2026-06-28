// Inline SVG icon set, traced from the Claude Design mockups so strokes/paths
// match. All icons inherit `currentColor` and accept a `size` prop.

const paths = {
  check: (
    <path
      d="M2 7l3 3 6-7"
      stroke="currentColor"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
    />
  ),
  checkBig: (
    <path
      d="M5 11.5l4 4 8-9"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
    />
  ),
  pencil: (
    <path
      d="M9.3 2.4l2.3 2.3L5 11.3 2.4 11.6l.3-2.6L9.3 2.4z"
      stroke="currentColor"
      strokeWidth="1.3"
      strokeLinejoin="round"
      fill="none"
    />
  ),
  chevronRight: (
    <path
      d="M1 1l6 6-6 6"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
    />
  ),
  chevronLeft: (
    <path
      d="M7.5 1l-6 7 6 7"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
    />
  ),
  chevronDown: (
    <path
      d="M1 1l4.5 4.5L10 1"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      fill="none"
    />
  ),
  clock: (
    <>
      <circle cx="7" cy="7" r="5.6" stroke="currentColor" strokeWidth="1.4" fill="none" />
      <path
        d="M7 4v3.2l2 1.3"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
    </>
  ),
  plus: (
    <path d="M7 1.5v11M1.5 7h11" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
  ),
  repeat: (
    <>
      <path d="M14.5 5A6.2 6.2 0 1 0 15.5 8.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" fill="none" />
      <path d="M14.5 1.8V5.2H11" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </>
  ),
  swap: (
    <>
      <path d="M2 4h9M8.5 1.5L11 4 8.5 6.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <path d="M13 9H4M6.5 6.5L4 9l2.5 2.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </>
  ),
  skip: (
    <>
      <path d="M3 3l5 4-5 4V3z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" fill="none" />
      <path d="M11.5 3v8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </>
  ),
  mode: (
    <>
      <path d="M2 4.5h11M2 9.5h11" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
      <circle cx="5" cy="4.5" r="2" fill="#fff" stroke="currentColor" strokeWidth="1.4" />
      <circle cx="10" cy="9.5" r="2" fill="#fff" stroke="currentColor" strokeWidth="1.4" />
    </>
  ),
  arrowRight: (
    <path d="M2 7h10M8 3l4 4-4 4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none" />
  ),
  arrowDown: (
    <path d="M7 1.5v10M3 7.5l4 4 4-4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
  ),
  arrowUp: (
    <path d="M7 12.5v-10M3 6.5l4-4 4 4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
  ),
  trend: (
    <>
      <path d="M1 9l4-4 3 3 5-6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <path d="M13 2v4h-4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </>
  ),
  dots: (
    <>
      <circle cx="2" cy="2" r="1.7" fill="currentColor" />
      <circle cx="9" cy="2" r="1.7" fill="currentColor" />
      <circle cx="16" cy="2" r="1.7" fill="currentColor" />
    </>
  ),
  grip: (
    <>
      <circle cx="3" cy="2.5" r="1.1" fill="currentColor" />
      <circle cx="7" cy="2.5" r="1.1" fill="currentColor" />
      <circle cx="3" cy="7" r="1.1" fill="currentColor" />
      <circle cx="7" cy="7" r="1.1" fill="currentColor" />
      <circle cx="3" cy="11.5" r="1.1" fill="currentColor" />
      <circle cx="7" cy="11.5" r="1.1" fill="currentColor" />
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
      <svg width={size} height={size * (heightRatio(vb))} viewBox={vb} fill="none">
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
