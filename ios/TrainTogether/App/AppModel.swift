import Foundation
import Network
import SwiftUI
import TrainTogetherCore
import TrainTogetherKit
import UIKit

enum AppTab: Hashable { case workout, history, settings }

/// What the full-screen workout flow shows. One cover switches between the
/// live workout and its summary, so finishing never stacks two presentations.
enum WorkoutCover: Hashable {
    case live(sessionId: String)
    case summary(sessionId: String)
}

enum WorkoutRoute: Hashable { case routine(String) }
enum HistoryRoute: Hashable {
    case workout(String)
    /// An exercise's progress; `session` pre-selects that workout's point.
    case exercise(String, session: String? = nil)
}

/// What the History tab lists.
enum HistoryMode: Hashable { case workouts, exercises }
enum SettingsRoute: Hashable { case person(String), addPartner, exercises, exercise(String?), sync, data }

/// A UIKit background task that's ended exactly once.
@MainActor
private final class BackgroundTask {
    var id = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// The post-log confirmation (6 s, undoable).
struct SnackbarState: Identifiable, Equatable {
    let id = UUID()
    let cardId: String
    let personId: String
    let message: AttributedString
    let undoSetId: String?
}

/// The app's state container: owns the database, the engine and sync, and
/// mirrors the observed data for the screens. Screens mutate data only
/// through `perform`, which surfaces failures as the error banner.
@MainActor @Observable
final class AppModel {
    let store: WorkoutStore
    let sync: SyncEngine
    let syncSettings: SyncSettingsStore
    let device: DeviceSettings
    let restAlerts = RestAlerts()
    let liveActivity = LiveActivityController()

    private(set) var snapshot: AppSnapshot = .empty
    private(set) var loaded = false
    private(set) var syncSnapshot = SyncSnapshot(status: .notConfigured, pending: 0)

    var selectedTab: AppTab = .workout
    var workoutPath: [WorkoutRoute] = []
    var historyPath: [HistoryRoute] = []
    var historyMode: HistoryMode = .workouts
    var settingsPath: [SettingsRoute] = []
    var workoutCover: WorkoutCover?
    var snackbar: SnackbarState?
    var errorMessage: String?
    /// Bumps when a rest timer runs out while the app is open (haptic trigger).
    private(set) var readyTick = 0

    private var tasks: [Task<Void, Never>] = []
    private var readyWatch: Task<Void, Never>?
    private var snackbarTimer: Task<Void, Never>?
    private let pathMonitor = NWPathMonitor()

    var catalog: CatalogSnapshot { snapshot.catalog }
    var active: ActiveSessionSnapshot? { snapshot.active }
    var engine: WorkoutEngine { store.engine }

    init(database: AppDatabase? = nil) {
        let database = database ?? Self.openDatabase()
        store = WorkoutStore(database: database)
        let settings = SyncSettingsStore()
        syncSettings = settings
        device = DeviceSettings()
        sync = SyncEngine(database: database, configuration: { settings.configuration() })
    }

    private static func openDatabase() -> AppDatabase {
        let url = URL.applicationSupportDirectory.appending(path: "TrainTogether/train-together.sqlite")
        #if DEBUG
        // UI tests start from a clean phone.
        if ProcessInfo.processInfo.environment["TT_RESET"] == "1" {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            try? SyncSettingsStore().clear()
        }
        #endif
        do {
            return try AppDatabase.onDisk(at: url)
        } catch {
            // Without its database the app can't do anything useful.
            fatalError("Could not open the database: \(error)")
        }
    }

    // MARK: Lifecycle

    func start() {
        guard tasks.isEmpty else { return }
        restAlerts.install()
        tasks.append(Task { [weak self] in
            guard let stream = self?.store.observeApp() else { return }
            do {
                for try await snapshot in stream { self?.apply(snapshot) }
            } catch {
                self?.errorMessage = "COULD NOT READ YOUR DATA — \(error.localizedDescription)"
            }
        })
        tasks.append(Task { [weak self] in
            guard let stream = self?.store.observePendingChanges() else { return }
            do {
                for try await pending in stream where pending > 0 {
                    await self?.sync.schedule()
                }
            } catch {}
        })
        tasks.append(Task { [weak self] in
            guard let updates = self?.sync.updates else { return }
            for await update in updates { self?.syncSnapshot = update }
        })
        tasks.append(Task { [sync] in
            await sync.start()
            await sync.syncNow()
        })
        pathMonitor.pathUpdateHandler = { [sync] path in
            guard path.status == .satisfied else { return }
            Task { await sync.syncNow() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "sync.network"))
    }

    func sceneBecameActive() {
        Task { await sync.syncNow() }
        liveActivity.sync(snapshot: snapshot, enabled: device.liveActivityEnabled)
    }

    /// Flush pending changes before iOS suspends the app.
    func sceneEnteredBackground() {
        let application = UIApplication.shared
        let task = BackgroundTask()
        task.id = application.beginBackgroundTask(withName: "sync") { task.end() }
        Task {
            await sync.syncNow()
            task.end()
        }
    }

    private func apply(_ snapshot: AppSnapshot) {
        let previous = self.snapshot
        self.snapshot = snapshot
        loaded = true
        if let cover = workoutCover, case .live(let id) = cover, snapshot.active?.session.id != id {
            // The workout ended elsewhere (e.g. restored from the server).
            workoutCover = nil
        }
        if previous.active?.timers != snapshot.active?.timers || previous.active?.session.id != snapshot.active?.session.id {
            restAlerts.sync(snapshot: snapshot, enabled: device.restAlertsEnabled)
            watchForReady()
        }
        liveActivity.sync(snapshot: snapshot, enabled: device.liveActivityEnabled)
    }

    // MARK: Actions

    /// Runs an engine mutation; a failure shows the error banner, phrased as
    /// "LOGGING THE SET FAILED — …" (§28). Returns whether it succeeded.
    @discardableResult
    func perform(_ label: String, _ action: (WorkoutEngine) throws -> Void) -> Bool {
        do {
            try action(engine)
            return true
        } catch {
            errorMessage = "\(label) FAILED — \(error.localizedDescription)"
            return false
        }
    }

    func showSnackbar(_ state: SnackbarState) {
        snackbar = state
        snackbarTimer?.cancel()
        snackbarTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, self?.snackbar?.id == state.id else { return }
            self?.snackbar = nil
        }
    }

    func dismissSnackbar() {
        snackbar = nil
        snackbarTimer?.cancel()
    }

    /// Opens the workout that's in progress.
    func resumeWorkout() {
        guard let active else { return }
        workoutCover = .live(sessionId: active.session.id)
    }

    /// Finishing switches the open cover to the summary.
    func finishWorkout(_ sessionId: String) {
        guard perform("FINISHING THE WORKOUT", { try $0.finishSession(id: sessionId) }) else { return }
        dismissSnackbar()
        workoutCover = .summary(sessionId: sessionId)
        Task { await sync.syncNow() }
    }

    func discardWorkout() {
        guard perform("DISCARDING THE WORKOUT", { try $0.discardActiveSession() }) else { return }
        dismissSnackbar()
        workoutCover = nil
        Task { await sync.syncNow() }
    }

    func showWorkoutInHistory(_ sessionId: String) {
        workoutCover = nil
        selectedTab = .history
        historyMode = .workouts
        historyPath = [.workout(sessionId)]
    }

    /// Opens a person's profile (e.g. to fill in sex and bodyweight for DOTS).
    func editPerson(_ personId: String) {
        selectedTab = .settings
        settingsPath = [.person(personId)]
    }

    // MARK: Rest-ready feedback

    /// Sleeps until the next rest timer ends, then fires the haptic and the
    /// VoiceOver announcement (§22, §29) — the notification covers the phone
    /// being locked.
    private func watchForReady() {
        readyWatch?.cancel()
        guard let active = snapshot.active else { return }
        let now = Date().epochMilliseconds
        guard let next = active.timers.values.filter({ $0.endsAt > now }).min(by: { $0.endsAt < $1.endsAt }) else { return }
        let name = catalog.person(next.personId)?.name ?? ""
        readyWatch = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(next.endsAt - now))
            guard !Task.isCancelled, let self else { return }
            self.readyTick += 1
            AccessibilityNotification.Announcement("\(name) — ready").post()
            self.watchForReady()
        }
    }
}
