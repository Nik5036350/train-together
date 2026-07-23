// Seed data so the app opens already looking like the design mockups and the
// PRD's example couple workout (Appendix §17). Owner = Alex (blue),
// Partner = Maria (orange). All ids are stable strings for easy referencing.

export const SEED_VERSION = 3

// ---- People -----------------------------------------------------------------
const alex = {
  id: 'p_alex',
  name: 'Alex',
  initials: 'A',
  color: 'blue',
  unit: 'kg',
  isOwner: true,
  active: true,
}
const maria = {
  id: 'p_maria',
  name: 'Maria',
  initials: 'M',
  color: 'orange',
  unit: 'kg',
  isOwner: false,
  active: true,
}

// ---- Exercise definitions (shared across both people) ------------------------
const exercises = {
  ex_bench: {
    id: 'ex_bench',
    name: 'Bench Press',
    category: 'Chest',
    equipment: 'Barbell',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 120,
  },
  ex_incline: {
    id: 'ex_incline',
    name: 'Incline DB Press',
    category: 'Chest',
    equipment: 'Dumbbell',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 120,
  },
  ex_cablefly: {
    id: 'ex_cablefly',
    name: 'Cable Fly',
    category: 'Chest',
    equipment: 'Cable Machine',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 90,
  },
  ex_dip: {
    id: 'ex_dip',
    name: 'Weighted Dip',
    category: 'Triceps',
    equipment: 'Bodyweight',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 120,
  },
  ex_pushdown: {
    id: 'ex_pushdown',
    name: 'Triceps Pushdown',
    category: 'Triceps',
    equipment: 'Cable Machine',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 90,
  },
  // Extra library exercises used for add / substitute flows.
  ex_machinechest: {
    id: 'ex_machinechest',
    name: 'Machine Chest Press',
    category: 'Chest',
    equipment: 'Machine',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 90,
  },
  ex_facepull: {
    id: 'ex_facepull',
    name: 'Face Pull',
    category: 'Shoulders',
    equipment: 'Cable Machine',
    tracks: { weight: true, reps: true, duration: false },
    defaultRestSeconds: 60,
  },
  ex_plank: {
    id: 'ex_plank',
    name: 'Plank',
    category: 'Core',
    equipment: 'Bodyweight',
    tracks: { weight: false, reps: false, duration: true },
    defaultRestSeconds: 60,
  },
}

// ---- Per-person exercise profiles (rest, machine setup) ----------------------
// Keyed by `${personId}__${exerciseId}`.
const personExerciseProfiles = {
  p_alex__ex_bench: { restSeconds: 150, machineSetup: '', cues: '' },
  p_maria__ex_bench: { restSeconds: 120, machineSetup: '', cues: '' },
  p_alex__ex_incline: { restSeconds: 120, machineSetup: '', cues: '' },
  p_maria__ex_incline: { restSeconds: 90, machineSetup: '', cues: '' },
  p_maria__ex_cablefly: { restSeconds: 90, machineSetup: '', cues: '' },
  p_alex__ex_dip: { restSeconds: 150, machineSetup: '', cues: '' },
  p_alex__ex_pushdown: { restSeconds: 90, machineSetup: '', cues: '' },
  p_maria__ex_pushdown: { restSeconds: 90, machineSetup: 'Rope attachment', cues: '' },
}

// ---- Template: Push Day ------------------------------------------------------
const templates = {
  t_push: {
    id: 't_push',
    name: 'Push Day',
    defaultMode: 'alternate',
    exercises: [
      { exerciseId: 'ex_bench', assignment: 'both', order: 0 },
      { exerciseId: 'ex_incline', assignment: 'both', order: 1 },
      { exerciseId: 'ex_cablefly', assignment: 'partner', order: 2 },
      { exerciseId: 'ex_dip', assignment: 'owner', order: 3 },
      { exerciseId: 'ex_pushdown', assignment: 'both', order: 4 },
    ],
  },
}

// ---- History: the previous Push Day, used for "last time" snippets -----------
// (numbers taken from PRD Appendix §17.1)
function lastSet(exerciseId, personId, weight, reps, idx) {
  return {
    id: `h1_${exerciseId}_${personId}_${idx}`,
    exerciseId,
    personId,
    setIndex: idx,
    weight,
    reps,
    duration: null,
    setType: 'working',
  }
}

const history = [
  {
    id: 'sess_prev',
    templateId: 't_push',
    name: 'Push Day',
    startTime: Date.parse('2026-06-23T18:00:00'),
    endTime: Date.parse('2026-06-23T19:12:00'),
    label: 'Mon',
    participantIds: ['p_alex', 'p_maria'],
    sets: [
      lastSet('ex_bench', 'p_alex', 80, 8, 0),
      lastSet('ex_bench', 'p_alex', 80, 7, 1),
      lastSet('ex_bench', 'p_alex', 77.5, 8, 2),
      lastSet('ex_bench', 'p_maria', 35, 10, 0),
      lastSet('ex_bench', 'p_maria', 35, 9, 1),
      lastSet('ex_bench', 'p_maria', 35, 8, 2),
      lastSet('ex_incline', 'p_alex', 30, 9, 0),
      lastSet('ex_incline', 'p_alex', 30, 8, 1),
      lastSet('ex_incline', 'p_alex', 28, 10, 2),
      lastSet('ex_incline', 'p_maria', 14, 12, 0),
      lastSet('ex_incline', 'p_maria', 14, 11, 1),
      lastSet('ex_incline', 'p_maria', 14, 10, 2),
      lastSet('ex_cablefly', 'p_maria', 12.5, 15, 0),
      lastSet('ex_cablefly', 'p_maria', 12.5, 13, 1),
      lastSet('ex_cablefly', 'p_maria', 12.5, 12, 2),
      lastSet('ex_dip', 'p_alex', 15, 8, 0),
      lastSet('ex_dip', 'p_alex', 15, 7, 1),
      lastSet('ex_dip', 'p_alex', 10, 8, 2),
      lastSet('ex_pushdown', 'p_alex', 40, 12, 0),
      lastSet('ex_pushdown', 'p_alex', 40, 10, 1),
      lastSet('ex_pushdown', 'p_alex', 37.5, 11, 2),
      lastSet('ex_pushdown', 'p_maria', 22.5, 12, 0),
      lastSet('ex_pushdown', 'p_maria', 22.5, 11, 1),
      lastSet('ex_pushdown', 'p_maria', 22.5, 10, 2),
    ],
  },
]

export function makeInitialState() {
  return {
    version: SEED_VERSION,
    onboarded: true, // partner already exists in the seed
    people: [alex, maria],
    settings: {
      coupleModeEnabled: true,
      defaultParticipants: 'both', // 'owner' | 'partner' | 'both'
      defaultLoggingStyle: 'alternate', // 'alternate' | 'turns' | 'independent'
      allowCopyPartnerValues: true,
      showPartnerHistory: true,
    },
    exercises,
    personExerciseProfiles,
    templates,
    history,
    session: null, // active WorkoutSession, created on START_SESSION
    lastSummary: null, // most recently finished session, shown on the summary screen
    snackbar: null, // { id, personId, text, undoable }
  }
}
