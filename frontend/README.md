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

The script crops the source badge to a full-bleed, opaque square, because iOS
applies its own squircle mask to home-screen icons — shipping the artwork with its
drawn corners intact produces a white ring inside that mask. It also emits the
80%-safe-zone maskable variants for Android and one launch image per iPhone
viewport. To swap the icon, replace `assets/icon-source.png` and re-run.

Data follows the PRD entity model: shared `ExerciseDefinition`s, per-person
`PersonExerciseProfile`s, a `WorkoutTemplate` with assignments, and a live `session`
where **every set record belongs to exactly one person** (invariant DI-01).

The app seeds itself with Alex + Maria, a "Push Day" routine, and last week's history
so it opens looking like the design on first launch. Reset to that seed any time by
clearing site data / `localStorage`.
