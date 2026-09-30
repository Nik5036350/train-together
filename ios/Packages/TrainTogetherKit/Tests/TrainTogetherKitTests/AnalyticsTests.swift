import Foundation
import GRDB
import Testing
@testable import TrainTogetherCore
@testable import TrainTogetherKit

@Suite struct StrengthFormulas {
    @Test func oneRepMaxUsesEpleyForMenAndBrzyckiForWomen() {
        #expect(abs(OneRepMax.estimate(weight: 100, reps: 5, sex: .male)! - 116.667) < 0.01)
        #expect(abs(OneRepMax.estimate(weight: 100, reps: 5, sex: nil)! - 116.667) < 0.01)
        #expect(abs(OneRepMax.estimate(weight: 100, reps: 5, sex: .female)! - 112.5) < 0.01)
        #expect(OneRepMax.estimate(weight: 153, reps: 1, sex: .male) == 153)
        #expect(OneRepMax.estimate(weight: 60, reps: 11, sex: .male) == nil)
        #expect(OneRepMax.estimate(weight: 0, reps: 5, sex: .male) == nil)
        #expect(OneRepMax.estimate(weight: 100, reps: 0, sex: .male) == nil)
        #expect(OneRepMax.estimate(weight: nil, reps: 5, sex: .female) == nil)
    }

    @Test func dotsMatchesPublishedValues() {
        #expect(abs(DOTS.score(liftKg: 600, bodyweightKg: 90, sex: .male) - 387.96) < 0.01)
        #expect(abs(DOTS.score(liftKg: 600, bodyweightKg: 80, sex: .male) - 413.73) < 0.01)
        #expect(abs(DOTS.score(liftKg: 320, bodyweightKg: 60, sex: .female) - 354.73) < 0.01)
        // Bodyweight is clamped to the formula's range.
        #expect(DOTS.score(liftKg: 300, bodyweightKg: 250, sex: .male) == DOTS.score(liftKg: 300, bodyweightKg: 210, sex: .male))
        #expect(DOTS.score(liftKg: 300, bodyweightKg: 170, sex: .female) == DOTS.score(liftKg: 300, bodyweightKg: 150, sex: .female))
    }

    @Test func dotsConvertsPoundsAndNeedsAProfile() {
        let lb = 1 / DOTS.poundsToKilograms
        let person = Person(id: "p", name: "P", initials: "P", color: "red", unit: .lb, isOwner: true,
                            sex: .male, bodyweight: 90 * lb)
        #expect(abs(DOTS.score(lift: 600 * lb, person: person)! - 387.96) < 0.01)
        var unset = person
        unset.sex = nil
        #expect(DOTS.score(lift: 600, person: unset) == nil)
    }
}

@Suite struct SessionMetrics {
    let alex = Person(id: "a", name: "Alex", initials: "A", color: "steel", unit: .kg, isOwner: true, sex: .male, bodyweight: 90)

    func set(_ session: String, _ date: Int64, _ weight: Double?, _ reps: Int?, duration: Int? = nil, person: String = "a") -> AnalyticsSet {
        AnalyticsSet(exerciseId: "dl", personId: person, sessionId: session, variant: .normal, date: date,
                     weight: weight, reps: reps, duration: duration)
    }

    @Test func warmUpsDoNotMoveTheTopSet() {
        let sets = [
            set("s1", 100, 20, 10), set("s1", 100, 60, 5), set("s1", 100, 100, 3), set("s1", 100, 100, 5),
            set("s1", 100, 140, 1), set("s1", 100, 20, 25),
        ]
        let point = Analytics.sessionPoints(sets, person: alex)[0]
        #expect(point.topWeight == 140)
        #expect(point.topWeightReps == 1)
        #expect(point.bestE1RM == 140) // 100×5 → 116.7 < 140×1
        #expect(point.bestReps == 25)
        #expect(point.setCount == 6)
        let expectedVolume: Double = 200 + 300 + 300 + 500 + 140 + 500 // Σ weight × reps
        #expect(point.volume == expectedVolume)
        #expect(abs(point.dots! - DOTS.score(liftKg: 140, bodyweightKg: 90, sex: .male)) < 0.0001)
    }

    @Test func topSetTiesGoToMoreReps() {
        let point = Analytics.sessionPoints([set("s", 1, 100, 3), set("s", 1, 100, 5)], person: alex)[0]
        #expect(point.topWeightReps == 5)
    }

    @Test func unmeasuredMetricsAreNilNotZero() {
        let plank = Analytics.sessionPoints([set("s", 1, nil, nil, duration: 60), set("s", 1, nil, nil, duration: 75)], person: alex)[0]
        #expect(plank.topWeight == nil)
        #expect(plank.volume == nil)
        #expect(plank.bestE1RM == nil)
        #expect(plank.value(.bestReps, tracksReps: false) == 75)
        // Only sets over 10 reps: no e1RM, so no DOTS either.
        let highReps = Analytics.sessionPoints([set("s", 1, 40, 15)], person: alex)[0]
        #expect(highReps.bestE1RM == nil)
        #expect(highReps.dots == nil)
        #expect(highReps.topWeight == 40)
    }

    @Test func pointsAreInDateOrderPerPerson() {
        let sets = [set("late", 300, 100, 1), set("early", 100, 90, 1), set("mid", 200, 95, 1), set("x", 150, 200, 1, person: "b")]
        #expect(Analytics.sessionPoints(sets, person: alex).map(\.sessionId) == ["early", "mid", "late"])
    }

    @Test func recordsBeatEveryEarlierSessionAndTiesDoNot() {
        let points = Analytics.sessionPoints([
            set("s1", 1, 100, 1), set("s2", 2, 100, 1), set("s3", 3, 105, 1), set("s4", 4, 104, 1), set("s5", 5, 105.005, 1),
        ], person: alex)
        #expect(Analytics.recordSessions(points, metric: .topSet) == ["s3"])
    }

    @Test func recordEventsForWeightedAndUnweightedExercises() {
        let weighted = Exercise(id: "dl", name: "Deadlift")
        let points = Analytics.sessionPoints([
            set("s1", 1, 100, 5), set("s2", 2, 100, 8), set("s3", 3, 110, 1),
        ], person: alex)
        let events = Analytics.recordEvents(points, exercise: weighted)
        // s2: same top weight but a better e1RM; s3: heavier top set.
        #expect(events.map(\.point.sessionId) == ["s2", "s3"])
        #expect(events.map(\.kind) == [.e1rm, .topSet])

        let pullUps = Exercise(id: "pu", name: "Pull-up", tracksWeight: false, tracksReps: true)
        let repPoints = Analytics.sessionPoints([set("s1", 1, nil, 8), set("s2", 2, nil, 10)], person: alex)
        #expect(Analytics.recordEvents(repPoints, exercise: pullUps).map(\.kind) == [.reps])
    }

    @Test func weekStartFollowsTheCalendar() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Sunday 2026-08-30 23:30 UTC belongs to the week starting Monday 2026-08-24.
        let sundayNight = Date(timeIntervalSince1970: 1_788_132_600).epochMilliseconds
        let monday = Date(timeIntervalSince1970: 1_787_529_600).epochMilliseconds
        #expect(Analytics.weekStart(sundayNight, calendar: calendar) == monday)
        #expect(Analytics.weekStart(monday, calendar: calendar) == monday)
    }
}

@Suite struct AnalyticsQueryTests {
    /// Runs a Push Day for both people `days` after the fixture clock, logging
    /// the given bench sets, and finishes it.
    @discardableResult
    func benchSession(_ world: World, days: Double, alex: [(Double, Int)], maria: [(Double, Int)] = []) throws -> String {
        world.clock.advance(seconds: days * 86_400)
        let active = try world.startPushDay(.independent)
        let bench = active.cards[0].id
        for (w, r) in alex {
            try world.engine.logSet(sessionExerciseId: bench, personId: "p_alex", values: SetValues(weight: w, reps: r))
        }
        for (w, r) in maria {
            try world.engine.logSet(sessionExerciseId: bench, personId: "p_maria", values: SetValues(weight: w, reps: r))
        }
        try world.engine.finishSession(id: active.session.id)
        return active.session.id
    }

    @Test func progressSeriesAndLedger() throws {
        let world = try World()
        let first = try benchSession(world, days: 1, alex: [(60, 10), (85, 3)], maria: [(37.5, 8)])
        let second = try benchSession(world, days: 7, alex: [(90, 1)])
        let progress = try #require(try world.store.exerciseProgress(exerciseId: "ex_bench"))
        #expect(progress.variants == [.normal])
        let alex = progress.series(variant: .normal, personId: "p_alex")
        #expect(alex.map(\.sessionId) == ["sess_prev", first, second])
        #expect(alex.map(\.topWeight) == [80, 85, 90])
        #expect(Analytics.recordSessions(alex, metric: .topSet) == [first, second])
        #expect(progress.sessions.map(\.sessionId) == [second, first, "sess_prev"])
        #expect(progress.sessions[0].byPerson["p_maria"] == nil)
        #expect(progress.series(variant: .normal, personId: "p_maria").count == 2)
    }

    @Test func settingSexChangesTheEstimateAndDOTS() throws {
        let world = try World()
        try benchSession(world, days: 1, alex: [(100, 5)])
        let before = try #require(try world.store.exerciseProgress(exerciseId: "ex_bench"))
        #expect(before.series(variant: .normal, personId: "p_alex").last?.dots == nil)
        let epley = try #require(before.series(variant: .normal, personId: "p_alex").last?.bestE1RM)

        try world.engine.updatePerson(id: "p_alex", body: BodyProfile(sex: .female, bodyweight: 70))
        let after = try #require(try world.store.exerciseProgress(exerciseId: "ex_bench"))
        let point = try #require(after.series(variant: .normal, personId: "p_alex").last)
        #expect(abs(epley - 116.667) < 0.01)
        #expect(abs(point.bestE1RM! - 112.5) < 0.01)
        #expect(abs(point.dots! - DOTS.score(liftKg: 112.5, bodyweightKg: 70, sex: .female)) < 0.0001)
    }

    @Test func summariesHideRemovedExercisesButTotalsKeepThem() throws {
        let world = try World()
        try benchSession(world, days: 1, alex: [(85, 3)])
        try world.engine.deleteExercise(id: "ex_cablefly")
        let snapshot = try world.store.analytics(now: Date(epochMilliseconds: world.clock.now))
        let ids = snapshot.exercises.map(\.exercise.id)
        #expect(!ids.contains("ex_cablefly"))
        #expect(ids.first == "ex_bench") // most recently trained
        let bench = try #require(snapshot.exercises.first)
        #expect(bench.sessionCount == 2)
        #expect(bench.bestTopWeight["p_alex"] == 85)
        #expect(bench.sparkline["p_alex"] == [80, 85])
        #expect(bench.recordLastTime)

        // The totals still include every finished workout, like History.
        let history = try world.store.history()
        let monthAgo = world.clock.now - 30 * 86_400_000
        #expect(snapshot.overview.workouts30 == history.filter { $0.session.startTime >= monthAgo }.count)
        #expect(snapshot.overview.sets30 == history.filter { $0.session.startTime >= monthAgo }.reduce(0) { $0 + $1.setCount })
        #expect(snapshot.overview.lastWorkout == history.first?.session.startTime)
        #expect(snapshot.overview.weeks.count == 12)
        #expect(snapshot.overview.weeks.map(\.workouts).reduce(0, +) >= 1)
        #expect(snapshot.overview.recentRecords.first?.point.exerciseId == "ex_bench")
    }

    @Test func weeklyBucketsCountWorkoutsAndVolume() throws {
        let world = try World()
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        try benchSession(world, days: 1, alex: [(100, 5)], maria: [(40, 10)])
        try benchSession(world, days: 1, alex: [(100, 5)])
        let snapshot = try world.store.analytics(now: Date(epochMilliseconds: world.clock.now), calendar: calendar)
        let weeks = snapshot.overview.weeks
        #expect(weeks == weeks.sorted { $0.start < $1.start })
        let total = weeks.reduce(0) { $0 + $1.workouts }
        #expect(total == 2) // the June fixture workout is older than 12 weeks
        let alexVolume = weeks.reduce(0) { $0 + ($1.volumeByPerson["p_alex"] ?? 0) }
        #expect(alexVolume == 1000)
        #expect(weeks.reduce(0) { $0 + ($1.volumeByPerson["p_maria"] ?? 0) } == 400)
    }
}

@Suite struct ProfileSchemaMigration {
    @Test func v2KeepsExistingDataAndTheOutbox() throws {
        let queue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(queue, upTo: "v1")
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO person (id, name, initials, color, unit, isOwner, active) VALUES ('p1', 'Anna', 'A', 'red', 'kg', 1, 1);
                INSERT INTO workout_session (id, templateId, name, startTime, loggingStyle, status) VALUES ('w1', NULL, 'Legs', 1000, 'alternate', 'finished');
                INSERT INTO set_entry (id, sessionId, exerciseId, personId, setIndex, weight, reps, setType, variant) VALUES ('s1', 'w1', 'sq', 'p1', 0, 80, 5, 'working', 'normal');
                DELETE FROM sync_outbox;
                INSERT INTO sync_outbox (entity, recordId, rev) VALUES ('set_entry', 's1', 7);
                """)
        }
        let database = try AppDatabase(queue)
        let (person, outbox) = try queue.read { db in
            (try Person.fetchOne(db, key: "p1"), try OutboxEntry.fetchAll(db))
        }
        #expect(person?.name == "Anna")
        #expect(person?.sex == nil)
        #expect(person?.bodyweight == nil)
        #expect(outbox == [OutboxEntry(entity: "set_entry", recordId: "s1", rev: 7)])
        #expect(try queue.read { db in try SetEntry.fetchCount(db) } == 1)

        let engine = WorkoutEngine(database: database)
        try engine.updatePerson(id: "p1", name: "Anna")
        #expect(try queue.read { db in try OutboxEntry.fetchCount(db) } == 1) // no-op update
        try engine.updatePerson(id: "p1", body: BodyProfile(sex: .female, bodyweight: 62.5))
        let queued = try queue.read { db in try OutboxEntry.fetchAll(db).map(\.entity) }
        #expect(queued.contains("person"))
        #expect(try queue.read { db in try Person.fetchOne(db, key: "p1") }?.bodyweight == 62.5)
    }

    @Test func personPayloadsDecodeTolerantly() throws {
        let legacy = #"{"id":"p","name":"A","initials":"A","color":"red","unit":"kg","isOwner":true,"active":true}"#
        let decoded = try JSONDecoder().decode(Person.self, from: Data(legacy.utf8))
        #expect(decoded.sex == nil && decoded.bodyweight == nil)
        let odd = #"{"id":"p","name":"A","initials":"A","color":"red","unit":"kg","isOwner":true,"active":true,"sex":"other","bodyweight":"x"}"#
        let tolerant = try JSONDecoder().decode(Person.self, from: Data(odd.utf8))
        #expect(tolerant.sex == nil && tolerant.bodyweight == nil)
        let full = #"{"id":"p","name":"A","initials":"A","color":"red","unit":"kg","isOwner":true,"active":true,"sex":"female","bodyweight":61.5}"#
        let person = try JSONDecoder().decode(Person.self, from: Data(full.utf8))
        #expect(person.sex == .female && person.bodyweight == 61.5)
        // Round trip: unset fields are simply absent.
        let encoded = try JSONEncoder().encode(decoded)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("sex"))
    }
}
