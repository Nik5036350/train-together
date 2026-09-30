import Foundation
import GRDB
import TrainTogetherCore

public enum SyncStatus: Equatable, Sendable {
    /// No server URL or token yet.
    case notConfigured
    /// Configured, but this phone hasn't connected to (or restored from) the
    /// server yet.
    case notLinked
    case syncing
    case synced(at: Int64)
    case offline
    case failed(SyncError)
    /// The server lost our records (replaced or restored from an older copy);
    /// everything is being uploaded again.
    case serverReset
}

public struct SyncSnapshot: Equatable, Sendable {
    public var status: SyncStatus
    /// Local changes not yet on the server.
    public var pending: Int

    public init(status: SyncStatus, pending: Int) {
        self.status = status
        self.pending = pending
    }
}

public enum ConnectOutcome: Equatable, Sendable {
    case linked
    /// The server already holds data and this phone never synced with it:
    /// the user must restore (replacing the phone's data) or cancel, never
    /// merge two datasets.
    case serverHasData(records: Int)
}

/// Pushes local changes to the server and restores from it. The phone is the
/// only writer, so sync is one-way in normal operation: queued changes go up,
/// stamped with a monotonic clock; a full pull only happens on restore.
public actor SyncEngine {
    public nonisolated let updates: AsyncStream<SyncSnapshot>
    private let continuation: AsyncStream<SyncSnapshot>.Continuation
    private let database: AppDatabase
    private let transport: any HTTPTransport
    private let configuration: @Sendable () -> SyncConfiguration?
    private let now: @Sendable () -> Int64
    private let debounce: Duration

    private var snapshot = SyncSnapshot(status: .notConfigured, pending: 0)
    private var currentPass: Task<Void, Never>?
    private var wantsAnotherPass = false
    private var paused = false
    private var scheduled: Task<Void, Never>?
    private var failures = 0

    static let batchSize = 500
    static let pullPageSize = 1000
    static let backoff: [Duration] = [.seconds(5), .seconds(30), .seconds(120), .seconds(600)]

    public init(
        database: AppDatabase,
        transport: any HTTPTransport = URLSessionTransport(),
        debounce: Duration = .seconds(2),
        now: @escaping @Sendable () -> Int64 = { Date().epochMilliseconds },
        configuration: @escaping @Sendable () -> SyncConfiguration?
    ) {
        (updates, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.database = database
        self.transport = transport
        self.debounce = debounce
        self.now = now
        self.configuration = configuration
    }

    public var current: SyncSnapshot { snapshot }

    /// Publishes the initial state; call once at launch.
    public func start() async {
        await publish(configuration() == nil ? .notConfigured : (try? await isLinked()) == true ? snapshot.status : .notLinked)
    }

    // MARK: Triggers

    /// Pushes shortly after local changes, coalescing bursts.
    public func schedule() {
        guard !paused else { return }
        scheduled?.cancel()
        let delay = debounce
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.syncNow(resetBackoff: false)
        }
    }

    /// Syncs now: on finish/discard, app activation, network return, "Sync
    /// now". Resets the retry backoff unless it's the retry itself.
    public func syncNow(resetBackoff: Bool = true) async {
        if paused { return }
        if resetBackoff { failures = 0 }
        if let pass = currentPass {
            wantsAnotherPass = true
            await pass.value
            return
        }
        let pass = Task { await self.runPasses() }
        currentPass = pass
        await pass.value
        currentPass = nil
    }

    // MARK: Linking

    /// Connects to the configured server. A phone that never synced may only
    /// link to an empty server; its outbox then holds everything to upload.
    public func connect() async throws -> ConnectOutcome {
        let client = try makeClient()
        let status = try await client.status()
        if try await isLinked() {
            await syncNow()
            return .linked
        }
        if status.records > 0 { return .serverHasData(records: status.records) }
        try await database.writer.write { db in
            try SyncState.set(db, SyncState.storeID, status.storeId)
            try SyncState.set(db, SyncState.lastServerSeq, String(status.serverSeq))
        }
        await syncNow()
        return .linked
    }

    /// The server's store id and record counts (Settings → Data).
    public func serverStatus() async throws -> ServerStatus {
        try await makeClient().status()
    }

    /// Whether this phone is linked to a server store.
    public func linked() async -> Bool {
        (try? await isLinked()) ?? false
    }

    /// Forgets the server link, e.g. when the server URL changes.
    public func unlink() async throws {
        try await database.writer.write { db in
            try SyncState.set(db, SyncState.storeID, nil)
            try SyncState.set(db, SyncState.lastServerSeq, nil)
        }
        await publish(configuration() == nil ? .notConfigured : .notLinked)
    }

    /// Queues every record and uploads it all again.
    public func reuploadAll() async throws {
        try await database.writer.write(SyncState.requeueAll)
        await syncNow()
    }

    /// Replaces the phone's data with the server's. Pauses pushing first, so
    /// a push started before the restore can't upload stale local rows after
    /// it.
    public func restore() async throws -> RestoreReport {
        let client = try makeClient()
        paused = true
        scheduled?.cancel()
        defer { paused = false }
        if let pass = currentPass { await pass.value }

        await publish(.syncing)
        do {
            let status = try await client.status()
            var changes: [PulledChange] = []
            var since: Int64 = 0
            while true {
                let page = try await client.pull(since: since, limit: Self.pullPageSize)
                changes += page.changes
                since = page.nextSince
                if !page.hasMore { break }
            }
            let serverSeq = max(status.serverSeq, since)
            let newestStamp = changes.map(\.updatedAt).max() ?? 0
            let pulled = changes
            let report = try await database.writer.write { db in
                let report = try Restorer.apply(pulled, db)
                try SyncState.set(db, SyncState.storeID, status.storeId)
                try SyncState.set(db, SyncState.lastServerSeq, String(serverSeq))
                try SyncState.raiseStamp(db, atLeast: newestStamp)
                return report
            }
            failures = 0
            await publish(.synced(at: now()))
            return report
        } catch let error as SyncError {
            await publish(error == .offline ? .offline : .failed(error))
            throw error
        }
    }

    // MARK: Passes

    private func runPasses() async {
        repeat {
            wantsAnotherPass = false
            await performPass()
        } while wantsAnotherPass && !paused
    }

    private func performPass() async {
        guard let config = configuration() else { return await publish(.notConfigured) }
        guard (try? await isLinked()) == true else { return await publish(.notLinked) }
        await publish(.syncing)
        let client = SyncClient(configuration: config, transport: transport)
        do {
            let status = try await client.status()
            try await reconcile(storeId: status.storeId, serverSeq: status.serverSeq)
            try await pushAll(client)
            failures = 0
            await publish(.synced(at: now()))
        } catch let error as SyncError {
            await publish(error == .offline ? .offline : .failed(error))
            if error.isTransient { scheduleRetry() }
        } catch {
            await publish(.failed(.unexpectedResponse(String(describing: error))))
            scheduleRetry()
        }
    }

    /// Detects a server that lost our data — a new store id, or a change
    /// counter behind what we last saw — and queues everything again.
    private func reconcile(storeId: String, serverSeq: Int64) async throws {
        let reset = try await database.writer.write { db -> Bool in
            let known = try SyncState.get(db, SyncState.storeID)
            let lastSeq = try SyncState.int(db, SyncState.lastServerSeq) ?? 0
            let reset = known != nil && (known != storeId || serverSeq < lastSeq)
            if reset { try SyncState.requeueAll(db) }
            try SyncState.set(db, SyncState.storeID, storeId)
            if reset || serverSeq > lastSeq {
                try SyncState.set(db, SyncState.lastServerSeq, String(serverSeq))
            }
            return reset
        }
        if reset { await publish(.serverReset) }
    }

    private func pushAll(_ client: SyncClient) async throws {
        // Bounded so a misbehaving server can't spin us forever.
        for _ in 0..<1_000 {
            // Rev and row are read together: a row edited mid-push gets a new
            // rev, so its outbox entry survives and the edit goes up next time.
            let batch = try await database.writer.read { db in
                try OutboxEntry.order(Column("rev")).limit(Self.batchSize).fetchAll(db).map { entry in
                    (entry, try SyncState.payload(db, entity: entry.entity, id: entry.recordId))
                }
            }
            if batch.isEmpty { return }
            let wallClock = now()
            let stamps = try await database.writer.write { db in
                try SyncState.reserveStamps(db, count: batch.count, now: wallClock)
            }
            let changes = zip(batch, stamps).map { item, stamp in
                OutgoingChange(
                    entity: item.0.entity, id: item.0.recordId, updatedAt: stamp,
                    deleted: item.1 == nil, data: item.1
                )
            }
            let response = try await client.push(changes)

            let storeChanged = try await database.writer.write { db -> Bool in
                let known = try SyncState.get(db, SyncState.storeID)
                if let known, known != response.storeId {
                    try SyncState.requeueAll(db)
                    try SyncState.set(db, SyncState.storeID, response.storeId)
                    try SyncState.set(db, SyncState.lastServerSeq, String(response.serverSeq))
                    return true
                }
                // Stale changes lost to a newer server stamp keep their outbox
                // entry; raising our clock above the server's makes the retry win.
                let stale = Set(response.stale.map { "\($0.entity)/\($0.id)" })
                for (entry, _) in batch where !stale.contains("\(entry.entity)/\(entry.recordId)") {
                    try db.execute(
                        sql: "DELETE FROM sync_outbox WHERE entity = ? AND recordId = ? AND rev = ?",
                        arguments: [entry.entity, entry.recordId, entry.rev]
                    )
                }
                if let newest = response.stale.map(\.updatedAt).max() {
                    try SyncState.raiseStamp(db, atLeast: newest)
                }
                try SyncState.set(db, SyncState.lastServerSeq, String(response.serverSeq))
                return false
            }
            if storeChanged { await publish(.serverReset) }
        }
    }

    private func scheduleRetry() {
        let delay = Self.backoff[min(failures, Self.backoff.count - 1)]
        failures += 1
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.syncNow(resetBackoff: false)
        }
    }

    // MARK: Helpers

    private func makeClient() throws -> SyncClient {
        guard let config = configuration() else { throw SyncError.missingConfiguration }
        return SyncClient(configuration: config, transport: transport)
    }

    private func isLinked() async throws -> Bool {
        try await database.writer.read { db in try SyncState.get(db, SyncState.storeID) != nil }
    }

    private func publish(_ status: SyncStatus) async {
        let pending = (try? await database.writer.read(Queries.pendingChanges)) ?? snapshot.pending
        snapshot = SyncSnapshot(status: status, pending: pending)
        continuation.yield(snapshot)
    }
}
