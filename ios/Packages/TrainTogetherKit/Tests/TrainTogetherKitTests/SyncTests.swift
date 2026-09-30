import Foundation
import GRDB
import Testing
@testable import TrainTogetherCore
@testable import TrainTogetherKit

@Suite struct FixtureContract {
    @Test func everyFixtureRecordDecodes() throws {
        let changes = try Fixture.changes()
        #expect(changes.count == 52)
        for change in changes {
            let type = try #require(SyncedTypes.type(named: change.entity), "unknown entity \(change.entity)")
            let data = try #require(change.data)
            _ = try decode(type, data)
        }
    }

    private func decode<R: SyncEntity & FetchableRecord & PersistableRecord>(_ type: R.Type, _ data: JSONValue) throws -> R {
        try data.decoded(as: R.self)
    }

    @Test func restoringTheFixtureLeavesAnEmptyOutbox() throws {
        let world = try World()
        #expect(try world.outbox().isEmpty)
        let counts = try world.store.recordCounts()
        #expect(counts["set_entry"] == 24)
        #expect(counts["person_exercise_profile"] == 8)
        #expect(counts["template_exercise"] == 5)
        #expect(try world.snapshot().catalog.person("p_alex")?.personColor == .steel)
    }

    @Test func payloadsWithoutVariantDecodeAsNormal() throws {
        let json = #"{"id":"s","sessionId":"x","exerciseId":"e","personId":"p","setIndex":0,"setType":"working"}"#
        let set = try JSONDecoder().decode(SetEntry.self, from: Data(json.utf8))
        #expect(set.variant == .normal)
        let odd = try JSONDecoder().decode(
            SessionExercise.self,
            from: Data(#"{"id":"se","sessionId":"x","exerciseId":"e","loggingMode":"sideways","orderIndex":0}"#.utf8)
        )
        #expect(odd.loggingMode == .alternate)
        #expect(odd.variant == .normal)
    }
}

@Suite struct OutboxTriggers {
    @Test func everySyncedTableHasThreeTriggers() throws {
        let world = try World(seeded: false)
        let names = try world.database.writer.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'trigger'")
        }
        for table in SyncedTypes.tableNames {
            for op in ["insert", "update", "delete"] {
                #expect(names.contains("sync_\(table)_\(op)"), "missing sync_\(table)_\(op)")
            }
        }
        #expect(!names.contains { $0.contains("rest_timer") })
    }

    @Test func writesEnqueueAndNoOpUpdatesDoNot() throws {
        let world = try World()
        try world.engine.updatePerson(id: "p_maria", name: "Maria")
        #expect(try world.outbox().isEmpty)
        try world.engine.updatePerson(id: "p_maria", name: "Marie")
        #expect(try world.outbox().map(\.recordId) == ["p_maria"])
    }

    @Test func loggingASetQueuesExactlyTheChangedRows() throws {
        let world = try World()
        let card = try world.startPushDay().cards[0]
        try world.clearOutbox()
        let setID = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        let queued = Set(try world.outbox().map { "\($0.entity)/\($0.recordId)" })
        #expect(queued == [
            "set_entry/\(setID)",
            "session_exercise/\(card.id)",
            "session_exercise_person/\(SessionExercisePerson.id(sessionExerciseId: card.id, personId: "p_alex"))",
        ])
    }

    @Test func deletingAWorkoutQueuesTombstonesForItsWholeGraph() throws {
        let world = try World()
        try world.clearOutbox()
        let detailSets = try world.count(SetEntry.self)
        try world.engine.deleteSession(id: "sess_prev")
        let entries = try world.outbox()
        #expect(entries.filter { $0.entity == "set_entry" }.count == detailSets)
        #expect(entries.contains { $0.entity == "workout_session" && $0.recordId == "sess_prev" })
        #expect(entries.filter { $0.entity == "session_participant" }.count == 2)
        let payloads = try world.database.writer.read { db in
            try entries.map { try SyncState.payload(db, entity: $0.entity, id: $0.recordId) }
        }
        #expect(payloads.allSatisfy { $0 == nil })
    }

    @Test func revChangesOnEveryWrite() throws {
        let world = try World()
        try world.engine.updatePerson(id: "p_maria", name: "A")
        let first = try #require(try world.outbox().first?.rev)
        try world.engine.updatePerson(id: "p_maria", name: "B")
        let second = try #require(try world.outbox().first?.rev)
        #expect(second != first)
    }
}

@Suite struct SyncEngineTests {
    func makeEngine(_ world: World, _ server: FakeServer, configured: Bool = true) -> SyncEngine {
        let config = server.configuration
        let clock = world.clock
        return SyncEngine(
            database: world.database, transport: server, debounce: .milliseconds(1), now: { clock.now },
            configuration: { configured ? config : nil }
        )
    }

    @Test func restoreReplacesLocalDataAndLinks() async throws {
        let world = try World(seeded: false)
        try world.engine.createOwner(name: "Stray", color: .red, unit: .kg)
        let server = FakeServer()
        server.load(try Fixture.changes())
        let sync = makeEngine(world, server)

        let report = try await sync.restore()
        #expect(report == RestoreReport(inserted: 52, orphansDropped: 0, undecodable: 0))
        let catalog = try world.snapshot().catalog
        #expect(catalog.owner?.id == "p_alex")
        #expect(catalog.people.count == 2)
        #expect(try world.outbox().isEmpty)
        #expect(await sync.current.status == .synced(at: world.clock.now))
        #expect(try await sync.connect() == .linked)
    }

    @Test func restoreDropsOrphansAndDetachesSetsFromMissingCards() async throws {
        let world = try World(seeded: false)
        let server = FakeServer()
        var changes = try Fixture.changes()
        let extra: [(String, String, JSONValue)] = [
            ("session_exercise_person", "sep_ghost_p_alex", .object([
                "id": .string("sep_ghost_p_alex"), "sessionExerciseId": .string("ghost"), "personId": .string("p_alex"),
                "status": .string("pending"), "orderIndex": .int(0),
            ])),
            ("set_entry", "loose", .object([
                "id": .string("loose"), "sessionId": .string("sess_prev"), "sessionExerciseId": .string("ghost"),
                "exerciseId": .string("ex_bench"), "personId": .string("p_alex"), "setIndex": .int(9),
                "setType": .string("working"), "variant": .string("normal"),
            ])),
            ("set_entry", "garbage", .object(["id": .string("garbage")])),
            ("mystery", "m1", .object(["id": .string("m1")])),
        ]
        for (i, item) in extra.enumerated() {
            changes.append(PulledChange(entity: item.0, id: item.1, updatedAt: 1, deleted: false, data: item.2, seq: Int64(100 + i)))
        }
        server.load(changes)
        let report = try await makeEngine(world, server).restore()
        #expect(report.inserted == 53)
        #expect(report.orphansDropped == 1)
        #expect(report.undecodable == 1)
        let loose = try await world.database.writer.read { db in try SetEntry.fetchOne(db, key: "loose") }
        #expect(loose?.sessionExerciseId == nil)
    }

    @Test func connectingAFreshPhoneToAnEmptyServerUploadsEverything() async throws {
        let world = try World(seeded: false)
        try world.engine.createOwner(name: "Anna", color: .red, unit: .kg)
        try world.engine.restoreDemoRoutine()
        let server = FakeServer()
        let sync = makeEngine(world, server)

        #expect(try await sync.connect() == .linked)
        #expect(try world.outbox().isEmpty)
        let counts = try world.store.recordCounts()
        #expect(server.liveRecords.count == counts.values.reduce(0, +))
        #expect(server.record("template", "t_push")?.data != nil)
    }

    @Test func aFreshPhoneMayNotMergeIntoAServerWithData() async throws {
        let world = try World(seeded: false)
        try world.engine.createOwner(name: "Anna", color: .red, unit: .kg)
        let server = FakeServer()
        server.load(try Fixture.changes())
        let sync = makeEngine(world, server)
        #expect(try await sync.connect() == .serverHasData(records: 52))
        #expect(server.pushCount == 0)
        await sync.syncNow()
        #expect(server.pushCount == 0)
        #expect(await sync.current.status == .notLinked)
    }

    @Test func pushesChangesAndTombstones() async throws {
        let (world, server, sync) = try await linkedWorld()
        let card = try world.startPushDay().cards[0]
        let setID = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        await sync.syncNow()
        #expect(try world.outbox().isEmpty)
        let pushed = try #require(server.record("set_entry", setID))
        #expect(pushed.data?.objectValue?["weight"] == .int(80))

        try world.engine.undoSet(id: setID)
        await sync.syncNow()
        #expect(server.record("set_entry", setID)?.deleted == true)
        #expect(await sync.current.pending == 0)
    }

    @Test func anEditDuringAPushIsNotLost() async throws {
        let (world, server, sync) = try await linkedWorld()
        try world.engine.updatePerson(id: "p_maria", name: "Marie")
        let engine = world.engine
        server.onPush = {
            server.onPush = nil
            try? engine.updatePerson(id: "p_maria", name: "Mary")
        }
        await sync.syncNow()
        // The mid-push edit re-queued the row, and the same sync pass (or the
        // next) uploads it.
        if try !world.outbox().isEmpty { await sync.syncNow() }
        #expect(try world.outbox().isEmpty)
        #expect(server.record("person", "p_maria")?.data?.objectValue?["name"] == .string("Mary"))
    }

    @Test func staleChangesAreRetriedWithANewerStamp() async throws {
        let (world, server, sync) = try await linkedWorld()
        let future = world.clock.now + 10_000_000
        server.setStamp("person", "p_maria", future)
        try world.engine.updatePerson(id: "p_maria", name: "Marie")
        await sync.syncNow()
        #expect(server.record("person", "p_maria")?.data?.objectValue?["name"] == .string("Marie"))
        #expect(try #require(server.record("person", "p_maria")).updatedAt > future)
        #expect(try world.outbox().isEmpty)
    }

    @Test func aServerThatLostItsDataGetsEverythingAgain() async throws {
        let (world, server, sync) = try await linkedWorld()
        server.reset()
        await sync.syncNow()
        #expect(server.liveRecords.count == 52)
        #expect(try world.outbox().isEmpty)

        // Same store id but an older change counter (database restored from a
        // backup) is detected too.
        server.reset(keepStoreId: true)
        await sync.syncNow()
        #expect(server.liveRecords.count == 52)
    }

    @Test func tokenAndCloudflareFailuresAreReported() async throws {
        let (world, server, sync) = try await linkedWorld()
        try world.engine.updatePerson(id: "p_maria", name: "Marie")

        server.forcedResponse = (401, "application/json", #"{"error":"TOKEN REJECTED"}"#)
        await sync.syncNow()
        #expect(await sync.current.status == .failed(.tokenRejected))

        server.forcedResponse = (200, "text/html", "<html>Cloudflare Access</html>")
        await sync.syncNow()
        #expect(await sync.current.status == .failed(.notSyncServer(status: 200)))
        #expect(try world.outbox().count == 1)
    }

    @Test func unconfiguredSyncDoesNothing() async throws {
        let world = try World()
        let server = FakeServer()
        let sync = makeEngine(world, server, configured: false)
        await sync.syncNow()
        #expect(await sync.current.status == .notConfigured)
        await #expect(throws: SyncError.missingConfiguration) { try await sync.connect() }
    }

    @Test func stampsNeverGoBackwards() throws {
        let world = try World(seeded: false)
        let stamps = try world.database.writer.write { db in
            let a = try SyncState.reserveStamps(db, count: 3, now: 1_000)
            let b = try SyncState.reserveStamps(db, count: 2, now: 500) // clock jumped back
            return a + b
        }
        #expect(stamps == [1_000, 1_001, 1_002, 1_003, 1_004])
    }

    /// A seeded phone already linked to a server holding the same data.
    private func linkedWorld() async throws -> (World, FakeServer, SyncEngine) {
        let world = try World(seeded: false)
        let server = FakeServer()
        server.load(try Fixture.changes())
        let sync = makeEngine(world, server)
        _ = try await sync.restore()
        return (world, server, sync)
    }
}

extension JSONValue {
    var objectValue: [String: JSONValue]? {
        if case .object(let object) = self { return object }
        return nil
    }
}
