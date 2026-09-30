import Foundation
import Testing
@testable import TrainTogetherCore
@testable import TrainTogetherKit

@Suite struct Home {
    /// Weeks start on Monday; Wednesday 30 Sep 2026, noon UTC, is "now".
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }()

    func ms(_ day: Int, month: Int = 9, hour: Int = 12) -> Int64 {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!.epochMilliseconds
    }

    var now: Int64 { ms(30) }

    /// Routines with one exercise each, and no history.
    func world(_ routines: [String]) throws -> World {
        let world = try World(seeded: false)
        try world.database.writer.write { db in
            for name in routines {
                try WorkoutTemplate(id: "t_\(name)", name: name).insert(db)
                try TemplateExercise(id: "tex_\(name)", templateId: "t_\(name)", exerciseId: "ex", assignment: .both, orderIndex: 0).insert(db)
            }
        }
        return world
    }

    func workout(_ world: World, _ id: String, routine: String?, at start: Int64, status: SessionStatus = .finished) throws {
        try world.database.writer.write { db in
            try WorkoutSession(
                id: id, templateId: routine.map { "t_\($0)" }, name: id, startTime: start,
                endTime: status == .finished ? start + 3_600_000 : nil, loggingStyle: .alternate, status: status
            ).insert(db)
        }
    }

    func home(_ world: World) throws -> HomeSnapshot {
        try world.store.home(now: Date(epochMilliseconds: now), calendar: calendar)
    }

    @Test func aRoutineNeverDoneIsNextThenTheOneDoneLongestAgo() throws {
        let world = try world(["Push", "Legs", "Arms"])
        try workout(world, "w1", routine: "Push", at: ms(25))
        try workout(world, "w2", routine: "Legs", at: ms(20))
        #expect(try home(world).nextUp == "t_Arms")

        try workout(world, "w3", routine: "Arms", at: ms(28))
        let home = try home(world)
        #expect(home.nextUp == "t_Legs")
        #expect(home.lastDone["t_Push"] == ms(25))
    }

    @Test func routinesWithoutExercisesAreNotSuggested() throws {
        let world = try world(["Push"])
        try world.database.writer.write { db in try WorkoutTemplate(id: "t_Aaa", name: "Aaa").insert(db) }
        try workout(world, "w1", routine: "Push", at: ms(25))
        #expect(try home(world).nextUp == "t_Push")
        #expect(try home(try World(seeded: false)).nextUp == nil)
    }

    @Test func onlyFinishedWorkoutsCount() throws {
        let world = try world(["Push"])
        try workout(world, "w1", routine: "Push", at: ms(30, hour: 9), status: .active)
        let home = try home(world)
        #expect(home.lastDone.isEmpty)
        #expect(home.trained[2] == false)
        #expect(home.workoutsThisWeek == 0)
    }

    @Test func theWeekStripCountsThisWeeksDays() throws {
        let world = try world(["Push"])
        try workout(world, "sun", routine: "Push", at: ms(27)) // last week
        try workout(world, "mon", routine: nil, at: ms(28))
        try workout(world, "wed1", routine: "Push", at: ms(30, hour: 7))
        try workout(world, "wed2", routine: nil, at: ms(30, hour: 10))
        try workout(world, "gone", routine: "Deleted", at: ms(29)) // its routine is gone
        let home = try home(world)
        #expect(home.trained == [true, true, true, false, false, false, false])
        #expect(home.workoutsThisWeek == 4)
        #expect(home.today == 2)
        #expect(home.weekDays.first == ms(28, hour: 0))
        #expect(home.nextUp == "t_Push")
    }

    @Test func daysAgoReadsLikeSpeech() {
        let locale = Locale(identifier: "en_US")
        #expect(Format.daysAgo(ms(30, hour: 8), now: now, calendar: calendar) == "Today")
        #expect(Format.daysAgo(ms(29, hour: 23), now: now, calendar: calendar) == "Yesterday")
        #expect(Format.daysAgo(ms(24), now: now, calendar: calendar) == "6 days ago")
        #expect(Format.daysAgo(ms(16), now: now, calendar: calendar, locale: locale) == Format.dayMonth(ms(16), locale: locale))
    }
}
