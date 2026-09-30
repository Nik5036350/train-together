import Foundation
import GRDB
import TrainTogetherCore

/// The app's entry point into the data: the engine for writes, observations
/// and reads for the screens. Keeps GRDB types out of the app target.
public final class WorkoutStore: Sendable {
    public let database: AppDatabase
    public let engine: WorkoutEngine

    public init(database: AppDatabase, engine: WorkoutEngine? = nil) {
        self.database = database
        self.engine = engine ?? WorkoutEngine(database: database)
    }

    // MARK: Observations (values are delivered on the main queue)

    public func observeApp() -> AsyncThrowingStream<AppSnapshot, any Error> {
        observe { db in
            AppSnapshot(catalog: try Queries.catalog(db), active: try Queries.activeSession(db))
        }
    }

    public func observeHistory() -> AsyncThrowingStream<[HistoryItem], any Error> {
        observe(Queries.history)
    }

    public func observeWorkout(id: String) -> AsyncThrowingStream<WorkoutDetail?, any Error> {
        observe { db in try Queries.workoutDetail(db, id: id) }
    }

    public func observePendingChanges() -> AsyncThrowingStream<Int, any Error> {
        observe(Queries.pendingChanges)
    }

    /// Exercise summaries and the training overview. `now` and `calendar`
    /// fix "last 30 days" and week boundaries; re-subscribe when the day
    /// changes.
    public func observeAnalytics(now: Date = .now, calendar: Calendar = .current) -> AsyncThrowingStream<AnalyticsSnapshot, any Error> {
        let ms = now.epochMilliseconds
        return observe { db in try Queries.analytics(db, now: ms, calendar: calendar) }
    }

    /// This week's training days and the routine up next. Like analytics,
    /// `now` fixes the week; re-subscribe when the day changes.
    public func observeHome(now: Date = .now, calendar: Calendar = .current) -> AsyncThrowingStream<HomeSnapshot, any Error> {
        let ms = now.epochMilliseconds
        return observe { db in try Queries.home(db, now: ms, calendar: calendar) }
    }

    public func home(now: Date = .now, calendar: Calendar = .current) throws -> HomeSnapshot {
        try database.reader.read { db in try Queries.home(db, now: now.epochMilliseconds, calendar: calendar) }
    }

    public func observeExerciseProgress(exerciseId: String) -> AsyncThrowingStream<ExerciseProgress?, any Error> {
        observe { db in try Queries.exerciseProgress(db, exerciseId: exerciseId) }
    }

    public func analytics(now: Date = .now, calendar: Calendar = .current) throws -> AnalyticsSnapshot {
        try database.reader.read { db in try Queries.analytics(db, now: now.epochMilliseconds, calendar: calendar) }
    }

    public func exerciseProgress(exerciseId: String) throws -> ExerciseProgress? {
        try database.reader.read { db in try Queries.exerciseProgress(db, exerciseId: exerciseId) }
    }

    // MARK: One-shot reads

    public func appSnapshot() throws -> AppSnapshot {
        try database.reader.read { db in
            AppSnapshot(catalog: try Queries.catalog(db), active: try Queries.activeSession(db))
        }
    }

    public func workoutDetail(id: String) throws -> WorkoutDetail? {
        try database.reader.read { db in try Queries.workoutDetail(db, id: id) }
    }

    public func history() throws -> [HistoryItem] {
        try database.reader.read(Queries.history)
    }

    public func recordCounts() throws -> [String: Int] {
        try database.reader.read(Queries.recordCounts)
    }

    public func pendingChanges() throws -> Int {
        try database.reader.read(Queries.pendingChanges)
    }

    private func observe<T: Equatable & Sendable>(
        _ fetch: @escaping @Sendable (Database) throws -> T
    ) -> AsyncThrowingStream<T, any Error> {
        let reader = database.reader
        return AsyncThrowingStream { continuation in
            let cancellable = ValueObservation
                .tracking(fetch)
                .removeDuplicates()
                .start(
                    in: reader,
                    scheduling: .async(onQueue: .main),
                    onError: { continuation.finish(throwing: $0) },
                    onChange: { continuation.yield($0) }
                )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }
}
