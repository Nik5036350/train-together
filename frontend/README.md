# Train Together

A strength-workout logger built for **two people training on one phone** — one shared
session, two completely separate histories. Implements the original "Couples Recording Mode" PRD
and the Constructivist style guide in `styleguide/`.

The two participants are identified by Revolution Red and Steel Blue (see
`styleguide/train-together-style-guide.md` §4.2).

## Run

```bash
cd web
npm install
npm run dev      # open the printed localhost URL
```

`npm run build` produces a production bundle in `dist/`.

On a desktop browser the app renders inside an iOS device frame; on a phone-width
viewport it goes full-screen.

## What's implemented

- **Setup** — partner profile, exercise creation (shared details + per-person rest/setup),
  routine builder with per-exercise assignment (Owner / Partner / Both).
- **Live session** — start sheet (participants + logging style), live overview with
  per-person set counts and rest-timer state, skip / substitute markers, add-exercise.
- **Logging card (the core)** — dual-row logging with three modes:
  - **Alternate** — both rows live, active row passes after each log.
  - **Turns** — one row at a time; the other collapses to a waiting state.
  - **Independent** — never switches automatically.
  - Per-person "Log for …", Repeat, per-person rest timers (Resting → Ready → Overdue),
    undo snackbar, notes, skip, substitute.
- **Summary** — shared metrics + separate per-person totals (sets, volume).
- **Persistence** — the whole store is saved to `localStorage`, so an in-progress
  session (and its active row / inputs) survives a reload.

## Architecture

```
src/
  theme.js            design tokens (colors, fonts) from the mockups
  store/              Context + reducer + seed + localStorage
  lib/                selectors, formatters, timer hook
  components/         DeviceShell (iOS frame) + shared UI
  screens/            the 8 screens
```

## App icon

Every icon, favicon and iOS launch image in `public/` is generated from the single
source at `assets/icon-source.png`. Don't hand-edit them:

```bash
python3 scripts/generate-icons.py           # regenerate (needs Pillow)
python3 scripts/generate-icons.py --check    # validate the source, write nothing
```

To swap the icon, replace `assets/icon-source.png` and re-run. The source must be a
square, opaque, **full-bleed** PNG — artwork running edge to edge, with no margin
and no rounded corners of its own. `--check` enforces exactly that, because iOS
applies its own squircle mask to home-screen icons and pre-rounded artwork shows a
ring nested inside it.

From there the script emits:

- the home-screen and manifest icons, plus favicons, as opaque paletted PNGs;
- the Android `maskable` variants. Android crops these to at worst a circle of 40%
  radius, and the pictogram reaches 43.1%, so the field is widened by mirroring its
  own border outward — padding with a flat colour would leave a visible ring, since
  the artwork is textured and unevenly lit;
- one launch image per iPhone viewport, as JPEG. iOS does *not* mask these, so their
  corners are pre-rounded; they are fully opaque, and the artwork's paper grain is
  incompressible noise that costs about twice as much as PNG.

Launch images are excluded from the service worker precache (`vite.config.js`):
every device matches exactly one by media query, so precaching all 11 would cost
each install over a megabyte for nothing.

Data follows the PRD entity model: shared `ExerciseDefinition`s, per-person
`PersonExerciseProfile`s, a `WorkoutTemplate` with assignments, and a live `session`
where **every set record belongs to exactly one person** (invariant DI-01).

The app seeds itself with Alex + Maria, a "Push Day" routine, and last week's history
so it opens looking like the design on first launch. Reset to that seed any time by
clearing site data / `localStorage`.
