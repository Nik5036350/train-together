import Foundation
import GRDB
@testable import TrainTogetherCore
@testable import TrainTogetherKit

/// The server importer's output for the legacy seed — the sync contract shared
/// with backend/src/tests.rs (`legacy_import_matches_golden_fixture`).
enum Fixture {
    static let url: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // TrainTogetherKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // TrainTogetherKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // repo root
        .appending(path: "backend/tests/fixtures/seed-records.json")

    static func changes() throws -> [PulledChange] {
        try JSONDecoder().decode([PulledChange].self, from: Data(contentsOf: url))
    }
}

/// A clock tests can move.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var ms: Int64

    init(_ start: Int64 = 1_790_000_000_000) { ms = start }

    var now: Int64 { lock.withLock { ms } }

    func advance(seconds: Double) {
        lock.withLock { ms += Int64(seconds * 1000) }
    }
}

/// Deterministic ids: "id1", "id2", …
final class IDSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0

    func next() -> String {
        lock.withLock {
            n += 1
            return "id\(n)"
        }
    }
}

/// A database seeded like the legacy app: Alex (owner) and Maria, 8 exercises,
/// "Push Day" and one finished workout ("Mon", 24 sets).
struct World {
    let database: AppDatabase
    let store: WorkoutStore
    let engine: WorkoutEngine
    let clock: TestClock

    init(seeded: Bool = true) throws {
        database = try AppDatabase.inMemory()
        clock = TestClock()
        let ids = IDSequence()
        let clock = clock
        engine = WorkoutEngine(database: database, now: { clock.now }, newID: { ids.next() })
        store = WorkoutStore(database: database, engine: engine)
        if seeded {
            let changes = try Fixture.changes()
            _ = try database.writer.write { db in try Restorer.apply(changes, db) }
        }
    }

    func snapshot() throws -> AppSnapshot { try store.appSnapshot() }

    func active() throws -> ActiveSessionSnapshot {
        guard let active = try snapshot().active else { throw TestFailure("no active session") }
        return active
    }

    /// Starts Push Day for both people.
    @discardableResult
    func startPushDay(_ style: LoggingMode = .alternate, people: [String] = ["p_alex", "p_maria"]) throws -> ActiveSessionSnapshot {
        try engine.startSession(templateId: "t_push", participantIds: people, loggingStyle: style)
        return try active()
    }

    func outbox() throws -> [OutboxEntry] {
        try database.writer.read { db in try OutboxEntry.order(Column("rev")).fetchAll(db) }
    }

    func clearOutbox() throws {
        _ = try database.writer.write { db in try OutboxEntry.deleteAll(db) }
    }

    func count<R: TableRecord>(_ type: R.Type) throws -> Int {
        try database.writer.read { db in try R.fetchCount(db) }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - Fake sync server

/// An in-memory implementation of the server's /api/v2 sync API with the same
/// semantics as backend/src/sync.rs: last-writer-wins on the client stamp, a
/// monotonic change counter, a store id, and tombstones.
final class FakeServer: HTTPTransport, @unchecked Sendable {
    struct Record {
        var entity: String
        var id: String
        var data: JSONValue?
        var deleted: Bool
        var updatedAt: Int64
        var seq: Int64
    }

    private let lock = NSLock()
    private var records: [String: Record] = [:]
    private var seq: Int64 = 0
    private(set) var storeId = UUID().uuidString
    private(set) var pushCount = 0
    let token: String

    /// Called while handling a push, before the response is sent.
    var onPush: (@Sendable () -> Void)?
    /// When set, every request answers with this status and body instead.
    var forcedResponse: (status: Int, contentType: String, body: String)?

    init(token: String = "test-token") { self.token = token }

    var configuration: SyncConfiguration {
        SyncConfiguration(baseURL: URL(string: "https://gym.example")!, token: token)
    }

    func load(_ changes: [PulledChange]) {
        lock.withLock {
            for c in changes {
                seq += 1
                records[key(c.entity, c.id)] = Record(
                    entity: c.entity, id: c.id, data: c.data, deleted: c.deleted, updatedAt: c.updatedAt, seq: seq
                )
            }
        }
    }

    /// Simulates `import-legacy?replace=true` or a lost database.
    func reset(keepStoreId: Bool = false) {
        lock.withLock {
            records = [:]
            if !keepStoreId { storeId = UUID().uuidString }
            if keepStoreId { seq = 0 }
        }
    }

    func record(_ entity: String, _ id: String) -> Record? {
        lock.withLock { records[key(entity, id)] }
    }

    var liveRecords: [Record] {
        lock.withLock { records.values.filter { !$0.deleted } }
    }

    func setStamp(_ entity: String, _ id: String, _ updatedAt: Int64) {
        lock.withLock { records[key(entity, id)]?.updatedAt = updatedAt }
    }

    private func key(_ entity: String, _ id: String) -> String { "\(entity)/\(id)" }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if let forced = forcedResponse {
            return respond(request, forced.status, Data(forced.body.utf8), contentType: forced.contentType)
        }
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)" else {
            return respond(request, 401, #"{"error":"TOKEN REJECTED"}"#)
        }
        let path = request.url!.path()
        switch (request.httpMethod ?? "GET", path) {
        case ("GET", "/api/v2/sync/status"):
            let body: [String: Any] = lock.withLock {
                let live = records.values.filter { !$0.deleted }
                let counts = Dictionary(grouping: live, by: \.entity).mapValues(\.count)
                return ["storeId": storeId, "serverSeq": seq, "records": live.count, "countsByEntity": counts]
            }
            return respond(request, 200, body)

        case ("POST", "/api/v2/sync/push"):
            struct Push: Decodable {
                struct Change: Decodable { var entity: String; var id: String; var updatedAt: Int64; var deleted: Bool; var data: JSONValue? }
                var changes: [Change]
            }
            let push = try JSONDecoder().decode(Push.self, from: request.httpBody ?? Data())
            onPush?()
            let body: [String: Any] = lock.withLock {
                pushCount += 1
                var stale: [[String: Any]] = []
                for c in push.changes {
                    if let existing = records[key(c.entity, c.id)], existing.updatedAt > c.updatedAt {
                        stale.append(["entity": c.entity, "id": c.id, "updatedAt": existing.updatedAt])
                        continue
                    }
                    seq += 1
                    records[key(c.entity, c.id)] = Record(
                        entity: c.entity, id: c.id, data: c.deleted ? nil : c.data, deleted: c.deleted,
                        updatedAt: c.updatedAt, seq: seq
                    )
                }
                return ["storeId": storeId, "serverSeq": seq, "accepted": push.changes.count - stale.count, "stale": stale]
            }
            return respond(request, 200, body)

        case ("GET", "/api/v2/sync/pull"):
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let since = Int64(items.first { $0.name == "since" }?.value ?? "0") ?? 0
            let limit = Int(items.first { $0.name == "limit" }?.value ?? "500") ?? 500
            let body: Data = try lock.withLock {
                let page = records.values.filter { $0.seq > since }.sorted { $0.seq < $1.seq }
                let slice = Array(page.prefix(limit))
                let changes = slice.map {
                    PulledChangeOut(entity: $0.entity, id: $0.id, updatedAt: $0.updatedAt, deleted: $0.deleted, data: $0.data, seq: $0.seq)
                }
                return try JSONEncoder().encode(PullOut(
                    storeId: storeId, changes: changes, nextSince: slice.last?.seq ?? since, hasMore: page.count > limit
                ))
            }
            return respond(request, 200, body, contentType: "application/json")

        default:
            return respond(request, 404, #"{"error":"NOT FOUND"}"#)
        }
    }

    private struct PulledChangeOut: Encodable {
        var entity: String; var id: String; var updatedAt: Int64; var deleted: Bool; var data: JSONValue?; var seq: Int64
    }

    private struct PullOut: Encodable {
        var storeId: String; var changes: [PulledChangeOut]; var nextSince: Int64; var hasMore: Bool
    }

    private func respond(_ request: URLRequest, _ status: Int, _ json: [String: Any]) -> (Data, HTTPURLResponse) {
        respond(request, status, try! JSONSerialization.data(withJSONObject: json), contentType: "application/json")
    }

    private func respond(_ request: URLRequest, _ status: Int, _ json: String) -> (Data, HTTPURLResponse) {
        respond(request, status, Data(json.utf8), contentType: "application/json")
    }

    private func respond(_ request: URLRequest, _ status: Int, _ body: Data, contentType: String) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        )!
        return (body, response)
    }
}
