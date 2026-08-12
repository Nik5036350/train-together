# Train Together — Visual Style Guide

**Version:** 1.0  
**Direction:** Modern Constructivist / Soviet-era graphic influence translated into a contemporary workout app  
**Product:** Train Together — strength-training logger for two people sharing one phone

---

## 1. Brand idea

**Two people. One phone. One workout. Separate progress.**

The visual system should communicate:

- two people acting independently inside one shared session;
- physical strength, rhythm, progress, repetition, and discipline;
- clarity under effort: the interface must stay readable when users are tired, moving, sweating, or passing the phone back and forth;
- a bold, utilitarian character without becoming decorative or nostalgic;
- a visual identity inspired by Constructivist geometry, training manuals, industrial signage, and printed sports graphics.

The historical influence should appear through **composition, geometry, typography, contrast, and color** — not through political symbols or literal propaganda references.

### North-star principle

> **Two people. One apparatus. Clear state. Zero ornament without purpose.**

---

## 2. Brand personality

The product should feel:

- **Strong**
- **Direct**
- **Functional**
- **Disciplined**
- **Human**
- **Graphic**
- **Physical**
- **Confident**
- **Shared, not romanticized**
- **Distinctive without sacrificing usability**

Avoid making the product feel:

- militaristic;
- aggressive;
- authoritarian;
- retro for retro's sake;
- overly decorative;
- cartoonish;
- glossy;
- soft-SaaS;
- gamified in a childish way.

---

## 3. Core visual language

The visual system is built from four ingredients:

1. **Rectangles** — structure, data, sets, buttons, panels.
2. **Circles** — people, timers, states, focus.
3. **Diagonals** — movement, switching, progression, tension.
4. **Bold rules / bars** — separation, rhythm, hierarchy.

The default visual treatment is:

- flat;
- high contrast;
- limited palette;
- asymmetric where useful;
- visually dense only where information density requires it;
- no unnecessary gradients;
- minimal shadow usage;
- subtle print-like surface texture on brand and marketing surfaces.

---

# 4. Color system

## 4.1 Primary palette

| Token | Name | Hex | Primary use |
|---|---|---:|---|
| `--red-500` | Revolution Red | `#C92C1C` | Primary action, Person A, brand accent |
| `--red-700` | Signal Red Dark | `#8F1E16` | Pressed state, dark red blocks |
| `--ink` | Ink | `#181816` | Primary text, dark surfaces, icons |
| `--paper` | Paper | `#F1E6D0` | Main warm background |
| `--canvas` | Canvas | `#FAF5EA` | Cards, inputs, elevated light surfaces |
| `--concrete` | Concrete | `#A69D8D` | Secondary text, inactive UI |
| `--steel` | Steel Blue | `#3F6070` | Person B, resting state |
| `--mustard` | Mustard | `#C48A28` | Warning, attention, optional highlights |
| `--field-green` | Field Green | `#52634B` | Ready, completed, positive state |

## 4.2 Two-person identity

The app must make it immediately obvious which person a control, timer, set, or exercise belongs to.

### Person A
**Revolution Red — `#C92C1C`**

### Person B
**Steel Blue — `#3F6070`**

Do not blend Person A and Person B into gradients.

Prefer:

```text
RED | BLUE
```

rather than:

```text
RED → PURPLE → BLUE
```

The two identities should feel equal but distinct.

## 4.3 Status colors

| State | Color |
|---|---|
| Resting | Steel Blue `#3F6070` |
| Ready | Field Green `#52634B` |
| Overdue | Revolution Red `#C92C1C` |
| Warning | Mustard `#C48A28` |
| Disabled | Concrete `#A69D8D` |
| Destructive | Ink `#181816` with explicit destructive label |

Do not rely on color alone. Pair each status color with text, iconography, or pattern.

## 4.4 Recommended color balance

For normal product screens:

- 55–70% Paper / Canvas
- 15–25% Ink
- 5–15% Person identity color
- 5–10% state / accent color

Red is stronger when it is not everywhere.

## 4.5 Dark mode direction

If dark mode is added:

- base: Ink `#181816`;
- raised surface: approximately `#242421`;
- primary text: Paper `#F1E6D0`;
- secondary text: muted warm gray;
- keep Revolution Red and Steel Blue recognizable but avoid increasing saturation.

Do not simply invert the light theme.

---

# 5. Typography

Typography is one of the primary carriers of the visual identity.

## 5.1 Display / headings

Recommended:

- **Roboto Condensed ExtraBold**
- fallback: **IBM Plex Sans Condensed Bold**

Use for:

- timers;
- workout totals;
- large numbers;
- exercise section headers;
- labels that need poster-like authority.

## 5.2 Body / UI text

Recommended:

- **Inter**
- fallback: **IBM Plex Sans**

Use for:

- form labels;
- body text;
- settings;
- explanatory copy;
- history details;
- secondary metadata.

## 5.3 Suggested type scale

| Role | Size | Weight | Notes |
|---|---:|---:|---|
| Display XL | 64–72px | 800 | Hero metrics, summaries |
| Display | 48px | 800 | Timers, active weight |
| Section | 22–28px | 700 | Uppercase selectively |
| Title | 18–20px | 700 | Exercise/card title |
| Body | 16px | 450–500 | Main UI copy |
| Label | 14px | 600 | Buttons, controls |
| Meta | 12–13px | 600 | Uppercase + tracking |

## 5.4 Typographic rules

Use uppercase for:

- major state labels;
- section headers;
- CTA labels;
- workout mode labels;
- compact utility labels.

Examples:

- `YOUR TURN`
- `REST 00:42`
- `SET LOGGED`
- `WORKOUT COMPLETE`
- `SWITCH TO MAX`

Avoid uppercase for long explanatory text.

Do not use more than two font families in the product.

---

# 6. Spacing system

Use a 4px base unit.

```text
4   8   12   16   24   32   48   64
```

Recommended tokens:

```css
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-6: 24px;
--space-8: 32px;
--space-12: 48px;
--space-16: 64px;
```

Rules:

- avoid overly airy SaaS layouts;
- keep workout logging compact but not cramped;
- use stronger spacing between semantic groups than between individual data rows;
- align numbers to consistent baselines.

---

# 7. Shape language

The system is built on simple geometry.

## 7.1 Corner radii

```css
--radius-sm: 6px;
--radius-md: 8px;
--radius-lg: 12px;
```

Use rounded corners sparingly.

Avoid excessive pill-shaped UI.

## 7.2 Borders

Recommended:

```css
--border-width: 2px;
```

Use clear borders instead of soft shadows.

## 7.3 Shadows

Default product UI: **none**.

Optional very light elevation can be used for:

- dialogs;
- temporary overlays;
- draggable sheets.

Marketing and brand mockups may use more dramatic depth, but the actual product should remain flatter.

---

# 8. Iconography

Icons should feel custom, bold, geometric, and mechanical.

## 8.1 Construction

Use:

- thick strokes;
- consistent line weight;
- square or minimally rounded caps;
- circles and rectangles;
- minimal curves;
- few internal details;
- strong silhouettes.

Avoid:

- thin outline icon packs;
- generic rounded SaaS icons;
- 3D icons;
- emoji;
- soft gradient pictograms.

## 8.2 Required icon family

The product should eventually have a coherent family for:

- Log set
- Repeat set
- Undo
- Edit
- Reassign
- Switch person
- Skip
- Substitute exercise
- Rest timer
- Ready
- Overdue
- Weight
- Reps
- History
- Workout
- Add exercise
- Delete
- Export
- Import
- Complete workout

---

# 9. App icon

The app icon should use the selected concept:

- two simplified people;
- one shared barbell;
- bold white pictogram;
- Revolution Red background;
- no text;
- no unnecessary detail.

## 9.1 iOS asset rule

For the iOS source asset:

- export as **1024×1024 px**;
- use a **square canvas**;
- do **not** bake rounded corners into the exported asset;
- do **not** include a white outer border;
- keep the artwork inside a safe optical margin;
- allow iOS to apply its own app-icon mask.

The same source should remain recognizable at very small sizes.

---

# 10. Buttons

## 10.1 Primary button

Use for the dominant next action.

Example:

```text
┌──────────────────────────┐
│         LOG SET          │
└──────────────────────────┘
```

Style:

- Revolution Red background;
- Paper/Canvas text;
- condensed bold label;
- no shadow;
- 6–8px radius;
- full-width on logging screens when appropriate.

## 10.2 Secondary button

Example:

```text
┌──────────────────────────┐
│       EDIT WEIGHT        │
└──────────────────────────┘
```

Style:

- Canvas background;
- 2px Ink border;
- Ink text.

## 10.3 Tertiary button

Text or low-emphasis bordered action.

Use for:

- Skip rest
- Cancel
- View details
- Secondary corrections

## 10.4 Destructive actions

Do not make every destructive action red.

Prefer:

- Ink surface or strong Ink border;
- explicit wording;
- confirmation for irreversible actions.

Example:

```text
DELETE WORKOUT
```

not merely a trash icon.

---

# 11. Inputs

Inputs should look like functional equipment labels.

Use:

- Canvas background;
- 2px Ink border;
- 6px radius;
- clear label above field;
- strong focus ring using the active person's color when person-specific.

Example:

```text
WEIGHT
┌─────────────┐
│ 42.5        │ kg
└─────────────┘
```

Use segmented controls for:

- kg / lb;
- mode selection;
- person assignment;
- alternate / turns / independent.

---

# 12. Workout cards

Avoid floating white cards with soft shadows.

Prefer flat blocks separated by rules.

Example:

```text
BENCH PRESS
────────────────────────────────

ANNA                         42.5 KG
● SET 03                     8 REPS
REST                         00:37

────────────────────────────────

MAX                            70 KG
● SET 02                    10 REPS
READY
```

Cards should emphasize:

1. active person;
2. current weight and reps;
3. set number;
4. rest state;
5. next available action.

---

# 13. Active-person treatment

The active-person indicator is a key brand behavior.

Use a large vertical identity band.

Example:

```text
████ ANNA
████
████ 42.5 KG × 8
████
```

When the turn changes, the identity band may move to the opposite side:

```text
                         ████ MAX
                         ████
                 70 KG × 10 ████
                         ████
```

This visually reinforces the real-world interaction: **passing the phone back and forth**.

The active-person treatment should be visible from arm's length.

---

# 14. Rest timer

The timer is a signature element.

## 14.1 Form

Use:

- thick circular progress ring;
- clear central time;
- minimal radial marks;
- high-contrast state label;
- no glossy effects.

Example:

```text
      00:42
      RESTING
```

## 14.2 States

### Resting
Steel Blue.

### Ready
Field Green.

### Overdue
Revolution Red.

When the timer reaches ready, use a crisp visual state change rather than a soft glow.

---

# 15. Set representation

Use large ordinal numbers instead of tiny checkboxes.

Example:

```text
01 ━━━━━━━ 60 KG × 10
02 ━━━━━━━ 65 KG × 08
03 ━━━━━━━ 65 KG × 07
```

Rules:

- set number should be prominent;
- completed sets use clear structural confirmation;
- corrected/edited sets may use a small edit marker;
- reassigned sets should visibly reflect the new person color;
- skipped sets should remain visible with reason.

---

# 16. Logging modes

The three workout modes should share the same structural language but have distinct indicators.

## Alternate

Visual idea:

```text
A → B → A → B
```

Use opposing red/steel arrows or alternating blocks.

## Turns

Visual idea:

```text
ACTIVE | RESTING
```

One person receives strong emphasis; the other receives a live timer.

## Independent

Visual idea:

```text
A ↕    B ↕
```

Both columns remain equally active.

Mode changes should be visible but not visually disruptive.

---

# 17. Navigation

Use 3–5 primary destinations maximum.

Suggested:

- Workout
- History
- Stats
- Settings

Use the current section as a bold graphic state rather than a tiny tint change.

Bottom navigation should remain simpler than the main workout content.

---

# 18. Texture

Use subtle warm paper grain.

Recommended opacity:

```text
2–4%
```

Use more strongly on:

- onboarding;
- splash screen;
- workout summary;
- empty states;
- marketing pages;
- illustrations.

Use less or none behind:

- dense workout logs;
- forms;
- settings;
- tables;
- fine numerical data.

Texture must never compromise legibility.

---

# 19. Illustration style

Illustrations should use:

- geometric people;
- silhouettes;
- strong diagonals;
- large color blocks;
- limited palette;
- abstract gym equipment;
- minimal facial/detail information;
- poster-like composition.

Avoid:

- realistic character illustration;
- glossy 3D;
- stock fitness imagery;
- emoji;
- anime;
- cartoon rendering.

Possible compositions:

- two figures pulling opposite diagonals around a shared barbell;
- one person active, one resting;
- mirrored movement;
- two routes converging on one goal;
- a circular timer intersected by a diagonal bar;
- stacked geometric weights.

---

# 20. Photography treatment

Photography is optional.

When used:

- desaturate heavily;
- favor industrial gyms, plates, bars, hands, racks, chalk, steel;
- crop tightly;
- avoid lifestyle-smile stock imagery;
- overlay large geometric red/steel shapes;
- use diagonal crops;
- preserve texture and contrast.

Marketing photography may be treated almost like printed halftone material.

---

# 21. Motion

Motion should feel mechanical, purposeful, and decisive.

Preferred:

- slide;
- wipe;
- snap;
- rotate;
- short scale;
- linear progress.

Avoid:

- spring bounce;
- jelly motion;
- liquid morphing;
- excessive parallax;
- decorative looping motion.

Recommended duration:

```text
120–180ms
```

Default easing:

```css
ease-out
```

Example brand interaction:

When the active person changes, the identity band slides from one side to the other.

---

# 22. Haptics

Use haptics sparingly.

Good use cases:

- successful set log;
- active-person handoff;
- rest timer ready;
- undo success;
- destructive confirmation.

Avoid haptic feedback for every tap.

---

# 23. Copy style

Copy should be short, functional, and confident.

Prefer:

- `YOUR TURN`
- `READY`
- `REST 00:42`
- `SET LOGGED`
- `REPEAT SET`
- `SWITCH TO MAX`
- `WORKOUT COMPLETE`
- `3 SETS REMAIN`
- `SKIP EXERCISE`
- `UNDO`

Avoid:

> Max is now ready to perform their next set.

Prefer:

> `MAX — YOUR TURN`

The UI should communicate like a training instrument, not a conversational assistant.

---

# 24. Numeric language

Numbers are a central visual asset.

Use prominent numerals for:

- weight;
- reps;
- set count;
- timer;
- total volume;
- workout duration.

Example:

```text
03
SET

42.5
KG

08
REPS
```

Use tabular numerals where available.

---

# 25. Summary screen

The post-workout summary should combine shared and personal metrics.

Recommended hierarchy:

```text
WORKOUT COMPLETE

01:07:45
TOTAL TIME

18
TOTAL SETS

────────────────────────

ANNA
8,450 KG
9 SETS

MAX
9,210 KG
9 SETS
```

Use red and steel person blocks, large numbers, and simple rules.

Avoid celebratory confetti.

A bold geometric star, line, or diagonal may be used as a restrained completion motif.

---

# 26. History

History should feel closer to a training ledger than a social feed.

Use:

- date;
- routine name;
- participants;
- duration;
- total sets;
- volume;
- clear delete affordance.

Avoid social engagement patterns such as likes, reactions, badges, or streak pressure unless intentionally added later.

---

# 27. Empty states

Empty states may carry more illustration than normal product screens.

Example:

```text
NO WORKOUTS YET

START YOUR FIRST SESSION.
YOUR HISTORY WILL APPEAR HERE.
```

Pair with a minimal geometric lifting illustration.

---

# 28. Error states

Error messages must remain direct.

Prefer:

```text
SET COULD NOT BE SAVED
TRY AGAIN
```

Avoid vague copy like:

> Something went wrong.

Where possible, preserve entered data after errors.

---

# 29. Accessibility

Historical visual influence must never override usability.

Requirements:

- meet WCAG contrast expectations;
- never use color as the only state indicator;
- maintain minimum touch targets;
- support Dynamic Type / text scaling;
- ensure timers and status changes are announced to assistive technology;
- respect reduced motion settings;
- avoid flashing transitions;
- allow users to identify participants by name as well as color;
- ensure red/green status differences are also labeled in text.

---

# 30. Responsive behavior

The core product is optimized for one phone shared by two people.

Priority order on small screens:

1. active person;
2. exercise;
3. weight/reps;
4. rest state;
5. log action;
6. correction actions;
7. history details.

Do not squeeze two dense columns onto narrow screens if stacked composition is clearer.

On larger widths, the two-person composition may become side-by-side.

---

# 31. PWA / web usage

The same brand system should work for:

- installed PWA;
- browser;
- desktop browser history/settings;
- landing page;
- repository README;
- social preview cards.

Marketing surfaces may use:

- more diagonals;
- larger typography;
- heavier texture;
- stronger asymmetry;
- oversized numbers.

Product screens should remain calmer.

---

# 32. Marketing composition

Suggested headline structures:

```text
02 PEOPLE
01 PHONE
01 WORKOUT
```

```text
TRAIN
TOGETHER

LOG
SEPARATELY
```

```text
YOUR SET.
THEIR REST.
ONE SCREEN.
```

```text
PASS THE PHONE.
KEEP THE SESSION.
```

Use enormous condensed text, asymmetrical blocks, diagonals, and two-person color identity.

---

# 33. Do / Don't

## Do

- use large, readable numerals;
- use red and steel consistently for the two people;
- use bold rules and strong geometry;
- keep actions obvious;
- keep correction workflows close to the logging screen;
- use asymmetric layouts where they communicate handoff or movement;
- use texture lightly;
- use typography as a graphic element;
- keep the product calmer than the marketing.

## Don't

- overuse red;
- use political symbols;
- use literal historical propaganda graphics;
- use rounded pastel SaaS styling;
- add gradients everywhere;
- use decorative texture behind dense data;
- rely on icons without labels for critical actions;
- use excessive pills;
- use confetti;
- gamify every behavior;
- make Person A / Person B dependent only on color.

---

# 34. CSS design tokens

```css
:root {
  /* Brand */
  --red-500: #C92C1C;
  --red-700: #8F1E16;

  --ink: #181816;
  --paper: #F1E6D0;
  --canvas: #FAF5EA;
  --concrete: #A69D8D;

  --steel: #3F6070;
  --mustard: #C48A28;
  --field-green: #52634B;

  /* Semantic */
  --person-a: var(--red-500);
  --person-b: var(--steel);
  --state-resting: var(--steel);
  --state-ready: var(--field-green);
  --state-overdue: var(--red-500);
  --state-warning: var(--mustard);

  /* Geometry */
  --radius-sm: 6px;
  --radius-md: 8px;
  --radius-lg: 12px;

  --border-width: 2px;

  /* Spacing */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --space-8: 32px;
  --space-12: 48px;
  --space-16: 64px;

  /* Motion */
  --motion-fast: 120ms;
  --motion-default: 160ms;
  --motion-slow: 180ms;
  --ease-default: ease-out;
}
```

---

# 35. Example component tokens

```css
.button-primary {
  background: var(--red-500);
  color: var(--paper);
  border: var(--border-width) solid var(--red-500);
  border-radius: var(--radius-md);
  min-height: 48px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.button-primary:active {
  background: var(--red-700);
  border-color: var(--red-700);
}

.button-secondary {
  background: var(--canvas);
  color: var(--ink);
  border: var(--border-width) solid var(--ink);
  border-radius: var(--radius-md);
}

.card {
  background: var(--canvas);
  color: var(--ink);
  border: var(--border-width) solid var(--ink);
  border-radius: var(--radius-md);
  box-shadow: none;
}

.person-a {
  --person-color: var(--person-a);
}

.person-b {
  --person-color: var(--person-b);
}
```

---

# 36. Screen-specific visual priorities

## Routine builder

Prioritize:

- exercise order;
- defaults;
- person assignment;
- logging mode;
- unit display.

Keep visual treatment mostly neutral.

## Active workout

This is the strongest product-expression screen.

Prioritize:

- active person;
- exercise;
- current set;
- weight;
- reps;
- timer;
- correction controls.

Use person colors most strongly here.

## Workout summary

Increase graphic expression.

Use:

- larger numerals;
- person-color blocks;
- completion motif;
- bold divider rules.

## History

Reduce visual drama.

Use a ledger-like list.

## Settings

Use the least decorative version of the system.

---

# 37. Visual QA checklist

Before shipping a screen, ask:

- Is it obvious whose data I am looking at?
- Is the active person obvious from arm's length?
- Is the next action obvious?
- Can a user log a set with one hand?
- Can a mistaken set be corrected quickly?
- Are timer states understandable without color?
- Are numbers visually prioritized?
- Is there unnecessary decoration?
- Does the screen still feel like the same product without texture?
- Is the Constructivist influence expressed through structure rather than costume?
- Does the screen remain readable while moving between sets?

---

# 38. Final design principle

The app should not look like a historical poster placed inside a phone.

It should look like a **modern workout instrument designed with the same confidence, economy, geometry, and visual discipline associated with Constructivist graphic design**.

The identity succeeds when users can recognize the product from:

- the red + steel pairing;
- large condensed numbers;
- strong rules;
- clear geometric pictograms;
- active-person bands;
- circular rest timers;
- asymmetric handoff composition;
- warm paper-like neutrals.

**Two people. One apparatus. Clear state. Zero ornament without purpose.**
