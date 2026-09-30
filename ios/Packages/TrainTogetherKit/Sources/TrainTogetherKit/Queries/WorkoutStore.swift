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
                    onError: { continuation.finish(throwing: $0) },
                    onChange: { continuation.yield($0) }
                )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }
}
