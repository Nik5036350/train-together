import { Routes, Route, useLocation, Navigate } from 'react-router-dom'
import { DeviceShell } from './components/DeviceShell.jsx'
import { ErrorBar } from './components/ErrorBar.jsx'
import { useApp } from './store/AppContext.jsx'
import { Home } from './screens/Home.jsx'
import { PartnerSetup } from './screens/PartnerSetup.jsx'
import { ProfileEdit } from './screens/ProfileEdit.jsx'
import { ExerciseCreate } from './screens/ExerciseCreate.jsx'
import { ExerciseLibrary } from './screens/ExerciseLibrary.jsx'
import { RoutineBuilder } from './screens/RoutineBuilder.jsx'
import { StartWorkout } from './screens/StartWorkout.jsx'
import { LiveOverview } from './screens/LiveOverview.jsx'
import { LoggingCard } from './screens/LoggingCard.jsx'
import { SessionSummary } from './screens/SessionSummary.jsx'
import { WorkoutHistory } from './screens/WorkoutHistory.jsx'
import { WorkoutDetail } from './screens/WorkoutDetail.jsx'

export function App() {
  const location = useLocation()
  const { actionError, dismissError } = useApp()
  // The start-workout sheet sits on a dark backdrop, so the status bar glyphs
  // need to be white there.
  const dark = location.pathname.startsWith('/start')

  return (
    <DeviceShell dark={dark}>
      {actionError && <ErrorBar error={actionError} onDismiss={dismissError} />}
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/partner" element={<PartnerSetup />} />
        <Route path="/profile/:id" element={<ProfileEdit />} />
        <Route path="/exercises" element={<ExerciseLibrary />} />
        <Route path="/exercise/new" element={<ExerciseCreate />} />
        <Route path="/exercise/:id/edit" element={<ExerciseCreate />} />
        <Route path="/routine/:id" element={<RoutineBuilder />} />
        <Route path="/start/:templateId" element={<StartWorkout />} />
        <Route path="/session" element={<LiveOverview />} />
        <Route path="/session/exercise/:id" element={<LoggingCard />} />
        <Route path="/summary" element={<SessionSummary />} />
        <Route path="/history" element={<WorkoutHistory />} />
        <Route path="/history/:id" element={<WorkoutDetail />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </DeviceShell>
  )
}
