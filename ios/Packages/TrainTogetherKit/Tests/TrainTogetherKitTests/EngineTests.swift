import Foundation
import Testing
@testable import TrainTogetherCore
@testable import TrainTogetherKit

// Ports of backend/src/tests.rs, run against the on-device engine, plus the
// paths the backend never covered.

@Suite struct SeedAndLifecycle {
    @Test func restoredSeedHasTheLegacyShape() throws {
        let world = try World()
        let snap = try world.snapshot()
        #expect(snap.catalog.people.count == 2)
        #expect(snap.catalog.exercises.count == 8)
        #expect(snap.catalog.routine("t_push")?.template.name == "Push Day")
        #expect(snap.catalog.routine("t_push")?.exercises.map(\.exerciseId) ==
                ["ex_bench", "ex_incline", "ex_cablefly", "ex_dip", "ex_pushdown"])
        #expect(snap.active == nil)
        let history = try world.store.history()
        #expect(history.count == 1)
        #expect(history[0].setCount == 24)
        #expect(history[0].personIds == ["p_alex", "p_maria"])
        #expect(snap.catalog.owner?.id == "p_alex")
        #expect(snap.catalog.partner?.id == "p_maria")
    }

    @Test func finishingMovesTheWorkoutToHistory() throws {
        let world = try World()
        let active = try world.startPushDay()
        world.clock.advance(seconds: 3600)
        try world.engine.finishSession(id: active.session.id)
        #expect(try world.snapshot().active == nil)
        let history = try world.store.history()
        #expect(history.count == 2)
        #expect(history[0].session.id == active.session.id)
        #expect(history[0].session.status == .finished)
        #expect(history[0].durationMs == 3_600_000)
        #expect(throws: EngineError.self) { try world.engine.finishSession(id: active.session.id) }
    }

    @Test func deletingAFinishedWorkoutRemovesItsWholeGraph() throws {
        let world = try World()
        let active = try world.startPushDay()
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.finishSession(id: active.session.id)
        try world.engine.deleteSession(id: active.session.id)
        #expect(try world.store.history().count == 1)
        #expect(try world.count(SetEntry.self) == 24)
        #expect(try world.count(SessionExercise.self) == 0)
        #expect(try world.count(SessionExercisePerson.self) == 0)
        #expect(try world.count(SessionParticipant.self) == 2)
        #expect(try world.count(Exercise.self) == 8)
        #expect(try world.count(WorkoutTemplate.self) == 1)
    }

    @Test func deletingTheActiveWorkoutIsRefused() throws {
        let world = try World()
        let active = try world.startPushDay()
        #expect(throws: EngineError.self) { try world.engine.deleteSession(id: active.session.id) }
        #expect(try world.snapshot().active != nil)
    }

    @Test func deletingAnUnknownWorkoutIsNotFound() throws {
        let world = try World()
        let error = #expect(throws: EngineError.self) { try world.engine.deleteSession(id: "nope") }
        #expect(error?.kind == .notFound)
    }

    @Test func startingWhileAWorkoutIsActiveNeedsResumeOrDiscard() throws {
        let world = try World()
        try world.startPushDay()
        let error = #expect(throws: EngineError.self) {
            try world.engine.startSession(templateId: "t_push", participantIds: ["p_alex"])
        }
        #expect(error?.kind == .activeSessionExists)
        try world.engine.discardActiveSession()
        #expect(try world.snapshot().active == nil)
        #expect(try world.count(SessionExercise.self) == 0)
        try world.engine.startSession(templateId: "t_push", participantIds: ["p_alex"])
        #expect(try world.snapshot().active != nil)
    }

    @Test func routineModeIsTheDefaultStyle() throws {
        let world = try World()
        try world.engine.updateTemplate(id: "t_push", defaultMode: .turns)
        try world.engine.startSession(templateId: "t_push", participantIds: ["p_alex", "p_maria"])
        let active = try world.active()
        #expect(active.session.loggingStyle == .turns)
        #expect(active.cards.allSatisfy { $0.exercise.loggingMode == .turns })
    }

    @Test func quickStartHasNoCardsAndUsesTheDefaultStyle() throws {
        let world = try World()
        try world.engine.updateSettings(defaultLoggingStyle: .independent)
        try world.engine.startSession(templateId: nil, participantIds: ["p_alex", "p_maria"])
        let active = try world.active()
        #expect(active.session.name == "Quick workout")
        #expect(active.session.templateId == nil)
        #expect(active.session.loggingStyle == .independent)
        #expect(active.cards.isEmpty)
        let cardID = try #require(try world.engine.addSessionExercise(sessionId: active.session.id, exerciseId: "ex_plank"))
        let card = try #require(try world.active().card(cardID))
        #expect(card.exercise.addedDuringSession)
        #expect(card.exercise.loggingMode == .independent)
        #expect(card.people.map(\.personId) == ["p_alex", "p_maria"])
    }
}

@Suite struct Logging {
    @Test func loggingSwitchesTheActiveRowAndIncrementsSetIndex() throws {
        let world = try World()
        let card = try world.startPushDay(.alternate).cards[0]
        #expect(card.exercise.activePersonId == "p_alex")

        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        var active = try world.active()
        #expect(active.card(card.id)?.exercise.activePersonId == "p_maria")
        #expect(active.card(card.id)?.row(for: "p_alex")?.status == .logged)
        #expect(active.sets(cardId: card.id, personId: "p_alex").map(\.setIndex) == [0])
        #expect(active.timers["p_alex"]?.durationSeconds == 150)

        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 7))
        active = try world.active()
        #expect(active.sets(cardId: card.id, personId: "p_alex").map(\.setIndex) == [0, 1])
    }

    @Test func turnsPassesTheTurnAndIndependentKeepsIt() throws {
        let world = try World()
        let card = try world.startPushDay(.turns).cards[0]
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        #expect(try world.active().card(card.id)?.exercise.activePersonId == "p_maria")

        try world.engine.setLoggingMode(sessionExerciseId: card.id, mode: .independent)
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_maria", values: SetValues(weight: 35, reps: 10))
        #expect(try world.active().card(card.id)?.exercise.activePersonId == "p_maria")
    }

    @Test func deletingASetRenumbersTheRest() throws {
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0]
        var ids: [String] = []
        for reps in [8, 7, 6] {
            world.clock.advance(seconds: 60)
            ids.append(try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: reps)))
        }
        try world.engine.deleteSet(id: ids[1])
        let sets = try world.active().sets(cardId: card.id, personId: "p_alex")
        #expect(sets.map(\.setIndex) == [0, 1])
        #expect(sets.map(\.reps) == [8, 6])
    }

    @Test func variantsTagSetsButShareOneIndexSequence() throws {
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0]
        #expect(card.exercise.variant == .normal)
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.setVariant(sessionExerciseId: card.id, variant: .highReps)
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 60, reps: 15))
        let pinned = try world.engine.logSet(
            sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 90, reps: 3), variant: .maxWeight
        )
        let active = try world.active()
        let sets = active.sets(cardId: card.id, personId: "p_alex")
        #expect(sets.map(\.variant) == [.normal, .highReps, .maxWeight])
        #expect(sets.map(\.setIndex) == [0, 1, 2])
        #expect(sets.last?.id == pinned)
        #expect(active.sets(cardId: card.id, personId: "p_alex", variant: .highReps).count == 1)
    }

    @Test func blankNotesAreStoredAsNil() throws {
        let world = try World()
        let card = try world.startPushDay().cards[0]
        let id = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8, note: "   "))
        #expect(try world.active().sets.first { $0.id == id }?.note == nil)
        try world.engine.editSet(id: id, values: SetValues(weight: 82.5, reps: 6, note: "belt"))
        let edited = try #require(try world.active().sets.first { $0.id == id })
        #expect(edited.weight == 82.5)
        #expect(edited.reps == 6)
        #expect(edited.note == "belt")
    }

    @Test func loggingIsRefusedForPeopleNotOnTheCard() throws {
        let world = try World()
        let active = try world.startPushDay()
        let dip = try #require(active.cards.first { $0.exercise.exerciseId == "ex_dip" })
        #expect(dip.people.map(\.personId) == ["p_alex"])
        #expect(throws: EngineError.self) {
            try world.engine.logSet(sessionExerciseId: dip.id, personId: "p_maria", values: SetValues(weight: 10, reps: 5))
        }
    }

    @Test func undoReturnsTheTurnClearsTheTimerAndResetsStatus() throws {
        let world = try World()
        let card = try world.startPushDay(.alternate).cards[0]
        let id = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.undoSet(id: id)
        let active = try world.active()
        #expect(active.card(card.id)?.exercise.activePersonId == "p_alex")
        #expect(active.card(card.id)?.row(for: "p_alex")?.status == .pending)
        #expect(active.timers["p_alex"] == nil)
        #expect(active.sets.isEmpty)
    }

    @Test func substitutionChangesTheLoggedExerciseAndRest() throws {
        let world = try World()
        let card = try world.startPushDay().cards[0]
        try world.engine.substituteExercise(sessionExerciseId: card.id, personId: "p_maria", substituteExerciseId: "ex_machinechest")
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_maria", values: SetValues(weight: 30, reps: 10))
        let active = try world.active()
        let set = try #require(active.sets(cardId: card.id, personId: "p_maria").first)
        #expect(set.exerciseId == "ex_machinechest")
        #expect(active.timers["p_maria"]?.durationSeconds == 90)
        #expect(active.card(card.id)?.exerciseId(for: "p_maria") == "ex_machinechest")
    }

    @Test func onePersonWorkoutsDropExercisesForTheOther() throws {
        let world = try World()
        let active = try world.startPushDay(.alternate, people: ["p_alex"])
        #expect(active.cards.map(\.exercise.exerciseId) == ["ex_bench", "ex_incline", "ex_dip", "ex_pushdown"])
        #expect(active.cards.map(\.exercise.orderIndex) == [0, 1, 2, 3])
        #expect(active.cards.allSatisfy { $0.people.map(\.personId) == ["p_alex"] })
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        #expect(try world.active().cards[0].exercise.activePersonId == "p_alex")
        #expect(try world.engine.addSessionExercise(sessionId: active.session.id, exerciseId: "ex_facepull", assignment: .partner) == nil)
    }
}

@Suite struct Corrections {
    @Test func reassigningMovesTheSetAndRenumbersBothPeople() throws {
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0]
        world.clock.advance(seconds: 10)
        let a1 = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        world.clock.advance(seconds: 10)
        let a2 = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 35, reps: 10))
        world.clock.advance(seconds: 10)
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_maria", values: SetValues(weight: 35, reps: 9))

        try world.engine.reassignSet(id: a2, toPersonId: "p_maria")
        let active = try world.active()
        #expect(active.sets(cardId: card.id, personId: "p_alex").map(\.id) == [a1])
        let maria = active.sets(cardId: card.id, personId: "p_maria")
        #expect(maria.map(\.setIndex) == [0, 1])
        #expect(maria.first?.id == a2) // logged earlier, so it sorts first
    }

    @Test func reassigningTheOnlySetResetsTheOriginalPersonToPending() throws {
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0]
        let id = try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.reassignSet(id: id, toPersonId: "p_maria")
        let active = try world.active()
        #expect(active.card(card.id)?.row(for: "p_alex")?.status == .pending)
        #expect(active.card(card.id)?.row(for: "p_maria")?.status == .logged)
        #expect(active.currentCardID == card.id)
    }

    @Test func reassigningLegacyHistoryKeepsTheExercise() throws {
        let world = try World()
        try world.engine.reassignSet(id: "h1_ex_bench_p_alex_1", toPersonId: "p_maria")
        let detail = try #require(try world.store.workoutDetail(id: "sess_prev"))
        let alex = detail.sets(exerciseId: "ex_bench", personId: "p_alex")
        let maria = detail.sets(exerciseId: "ex_bench", personId: "p_maria")
        #expect(alex.map(\.setIndex) == [0, 1])
        #expect(maria.count == 4)
        #expect(maria.map(\.setIndex).sorted() == [0, 1, 2, 3])
        #expect(maria.allSatisfy { $0.exerciseId == "ex_bench" })
    }

    @Test func deletingAHistorySetRenumbersByExercise() throws {
        let world = try World()
        try world.engine.deleteSet(id: "h1_ex_incline_p_maria_0")
        let detail = try #require(try world.store.workoutDetail(id: "sess_prev"))
        #expect(detail.sets(exerciseId: "ex_incline", personId: "p_maria").map(\.setIndex) == [0, 1])
        #expect(detail.sets(exerciseId: "ex_incline", personId: "p_maria").map(\.reps) == [11, 10])
    }
}

@Suite struct TurnsAndSkips {
    @Test func skipTurnPassesOverPeopleWhoSkipped() throws {
        let world = try World()
        let card = try world.startPushDay(.alternate).cards[0]
        try world.engine.skipTurn(sessionExerciseId: card.id, personId: "p_alex")
        #expect(try world.active().card(card.id)?.exercise.activePersonId == "p_maria")

        try world.engine.skipExercise(sessionExerciseId: card.id, personId: "p_maria", reason: "shoulder")
        var active = try world.active()
        #expect(active.card(card.id)?.exercise.activePersonId == "p_alex")
        #expect(active.card(card.id)?.row(for: "p_maria")?.status == .skipped)
        #expect(active.card(card.id)?.row(for: "p_maria")?.skipReason == "shoulder")
        #expect(active.card(card.id)?.visiblePeople.map(\.personId) == ["p_alex"])

        // Nobody else to pass to: the turn stays put.
        try world.engine.skipTurn(sessionExerciseId: card.id, personId: "p_alex")
        active = try world.active()
        #expect(active.card(card.id)?.exercise.activePersonId == "p_alex")
    }

    @Test func skipExercisePassesToTheOtherPersonWhateverTheirStatus() throws {
        let world = try World()
        let card = try world.startPushDay(.alternate).cards[0]
        try world.engine.skipExercise(sessionExerciseId: card.id, personId: "p_maria", reason: "  ")
        try world.engine.skipExercise(sessionExerciseId: card.id, personId: "p_alex", reason: nil)
        let active = try world.active()
        #expect(active.card(card.id)?.exercise.activePersonId == "p_maria")
        #expect(active.card(card.id)?.row(for: "p_maria")?.skipReason == nil)
        #expect(active.currentCardID == active.cards[1].id)
    }

    @Test func currentAndUnfinishedCardsFollowStatuses() throws {
        let world = try World()
        let active = try world.startPushDay(.alternate)
        #expect(active.currentCardID == active.cards[0].id)
        #expect(active.unfinishedCards.count == active.cards.count)
        for person in ["p_alex", "p_maria"] {
            try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: person, values: SetValues(weight: 50, reps: 5))
        }
        let after = try world.active()
        #expect(after.currentCardID == after.cards[1].id)
        #expect(after.unfinishedCards.map(\.id) == Array(after.cards.dropFirst().map(\.id)))
    }
}

@Suite struct RestTimers {
    @Test func plusThirtyExtendsRestOrRestartsIt() throws {
        let world = try World()
        let active = try world.startPushDay()
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.adjustRest(sessionId: active.session.id, personId: "p_alex", by: 30)
        #expect(try world.active().timers["p_alex"]?.durationSeconds == 180)

        world.clock.advance(seconds: 400)
        try world.engine.adjustRest(sessionId: active.session.id, personId: "p_alex", by: 30)
        let timer = try #require(try world.active().timers["p_alex"])
        #expect(timer.durationSeconds == 30)
        #expect(timer.startedAt == world.clock.now)
    }

    @Test func skipRestMakesThePersonReady() throws {
        let world = try World()
        let active = try world.startPushDay()
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        world.clock.advance(seconds: 20)
        try world.engine.skipRest(sessionId: active.session.id, personId: "p_alex")
        let timer = try #require(try world.active().timers["p_alex"])
        #expect(timer.phase(now: world.clock.now) == .ready)
    }

    @Test func restPhasesMatchThePWA() {
        #expect(RestPhase(startedAt: 0, durationSeconds: 90, now: 30_000) == .resting(remaining: 60))
        #expect(RestPhase(startedAt: 0, durationSeconds: 90, now: 90_000) == .ready)
        #expect(RestPhase(startedAt: 0, durationSeconds: 90, now: 119_000) == .ready)
        #expect(RestPhase(startedAt: 0, durationSeconds: 90, now: 125_000) == .overdue(over: 35))
    }

    @Test func finishingClearsTimers() throws {
        let world = try World()
        let active = try world.startPushDay()
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.finishSession(id: active.session.id)
        #expect(try world.count(RestTimer.self) == 0)
    }
}

@Suite struct CatalogEditing {
    @Test func routineExercisesReorderAndRenumber() throws {
        let world = try World()
        try world.engine.moveTemplateExercises(templateId: "t_push", fromOffsets: IndexSet(integer: 4), toOffset: 0)
        var rows = try #require(try world.snapshot().catalog.routine("t_push")).exercises
        #expect(rows.map(\.exerciseId) == ["ex_pushdown", "ex_bench", "ex_incline", "ex_cablefly", "ex_dip"])
        #expect(rows.map(\.orderIndex) == [0, 1, 2, 3, 4])

        try world.engine.removeTemplateExercise(id: rows[1].id)
        rows = try #require(try world.snapshot().catalog.routine("t_push")).exercises
        #expect(rows.map(\.exerciseId) == ["ex_pushdown", "ex_incline", "ex_cablefly", "ex_dip"])
        #expect(rows.map(\.orderIndex) == [0, 1, 2, 3])

        let added = try world.engine.addTemplateExercise(templateId: "t_push", exerciseId: "ex_plank", assignment: .owner)
        try world.engine.setAssignment(templateExerciseId: added, assignment: .partner)
        rows = try #require(try world.snapshot().catalog.routine("t_push")).exercises
        #expect(rows.last?.assignment == .partner)
        #expect(rows.last?.orderIndex == 4)
    }

    @Test func savingAnExerciseKeepsEquipmentAndUpsertsProfiles() throws {
        let world = try World()
        var draft = ExerciseDraft(try #require(try world.snapshot().catalog.exercise("ex_bench")))
        draft.name = "Bench Press (paused)"
        draft.profiles = [ProfileDraft(personId: "p_maria", restSeconds: 100, machineSetup: "Rack 3", cues: "Tuck elbows")]
        try world.engine.saveExercise(draft)
        let catalog = try world.snapshot().catalog
        #expect(catalog.exercise("ex_bench")?.equipment == "Barbell")
        #expect(catalog.exercise("ex_bench")?.name == "Bench Press (paused)")
        #expect(catalog.profile(personId: "p_maria", exerciseId: "ex_bench")?.machineSetup == "Rack 3")
        #expect(catalog.profile(personId: "p_alex", exerciseId: "ex_bench")?.restSeconds == 150)
        #expect(throws: EngineError.self) {
            try world.engine.saveExercise(ExerciseDraft(name: "Nothing", tracksWeight: false, tracksReps: false))
        }
    }

    @Test func deletingAnExerciseStripsRoutinesButKeepsHistory() throws {
        let world = try World()
        try world.engine.deleteExercise(id: "ex_cablefly")
        let catalog = try world.snapshot().catalog
        #expect(catalog.exercise("ex_cablefly") == nil)
        #expect(catalog.routine("t_push")?.exercises.map(\.orderIndex) == [0, 1, 2, 3])
        #expect(catalog.profile(personId: "p_maria", exerciseId: "ex_cablefly") == nil)
        let detail = try #require(try world.store.workoutDetail(id: "sess_prev"))
        #expect(detail.sets(exerciseId: "ex_cablefly", personId: "p_maria").count == 3)
    }

    @Test func deletingAnExerciseInTheCurrentWorkoutIsRefused() throws {
        let world = try World()
        try world.startPushDay()
        #expect(throws: EngineError.self) { try world.engine.deleteExercise(id: "ex_bench") }
    }

    @Test func profileRestFeedsTheTimer() throws {
        let world = try World()
        try world.engine.setProfileRest(personId: "p_maria", exerciseId: "ex_bench", restSeconds: 45)
        let card = try world.startPushDay().cards[0]
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_maria", values: SetValues(weight: 35, reps: 10))
        #expect(try world.active().timers["p_maria"]?.durationSeconds == 45)
    }

    @Test func onboardingCreatesOwnerPartnerAndDemoRoutine() throws {
        let world = try World(seeded: false)
        #expect(try world.snapshot().needsOnboarding)
        try world.engine.createOwner(name: " anna ", color: .red, unit: .kg)
        try world.engine.savePartner(name: "Max", color: .steel, unit: .lb)
        try world.engine.restoreDemoRoutine()
        let catalog = try world.snapshot().catalog
        #expect(catalog.owner?.name == "anna")
        #expect(catalog.owner?.initials == "A")
        #expect(catalog.partner?.unit == .lb)
        #expect(catalog.routine("t_push")?.exercises.count == 5)
        #expect(catalog.exercises.count == 8)
        #expect(throws: EngineError.self) { try world.engine.createOwner(name: "Again", color: .red, unit: .kg) }
    }
}

@Suite struct ReadHelpers {
    @Test func lastTimeComesFromTheMostRecentFinishedWorkout() throws {
        let world = try World()
        let active = try world.startPushDay()
        let last = try #require(active.lastTime(cardId: active.cards[0].id, personId: "p_alex"))
        #expect(last.label == "Mon")
        #expect(last.sets.map(\.reps) == [8, 7, 8])
        // Set 1 starts from last time's set 1 (80×8), not its final set.
        #expect(active.defaultValues(cardId: active.cards[0].id, personId: "p_alex") == SetValues(weight: 80, reps: 8))

        // 85 vs last time's 80: set 2 (80×7) carries the +5.
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 85, reps: 5))
        #expect(try world.active().defaultValues(cardId: active.cards[0].id, personId: "p_alex") == SetValues(weight: 85, reps: 7))
    }

    @Test func lastTimeIsPerVariantAndLabelledByWeekday() throws {
        let world = try World()
        var active = try world.startPushDay()
        let card = active.cards[0]
        try world.engine.setVariant(sessionExerciseId: card.id, variant: .highReps)
        active = try world.active()
        #expect(active.lastTime(cardId: card.id, personId: "p_alex") == nil)
        try world.engine.logSet(sessionExerciseId: card.id, personId: "p_alex", values: SetValues(weight: 60, reps: 15))
        try world.engine.finishSession(id: active.session.id)

        let next = try world.startPushDay()
        try world.engine.setVariant(sessionExerciseId: next.cards[0].id, variant: .highReps)
        let last = try #require(try world.active().lastTime(cardId: next.cards[0].id, personId: "p_alex"))
        #expect(last.label == Format.weekday(active.session.startTime))
        #expect(last.sets.map(\.reps) == [15])
    }

    @Test func historyVolumeIsPerPerson() throws {
        let world = try World()
        let item = try #require(try world.store.history().first)
        #expect(item.volumeByPerson["p_alex"] == PersonTotals(sets: try #require(try world.store.workoutDetail(id: "sess_prev")).sets(personId: "p_alex")).volume)
        #expect(item.exerciseCount == 5)
    }

    @Test func workoutDetailOrdersExercisesByCardThenAppearance() throws {
        let world = try World()
        let detail = try #require(try world.store.workoutDetail(id: "sess_prev"))
        #expect(detail.exerciseOrder == ["ex_bench", "ex_incline", "ex_cablefly", "ex_dip", "ex_pushdown"])

        let active = try world.startPushDay(.independent)
        // Log the second card first; card order still wins.
        try world.engine.logSet(sessionExerciseId: active.cards[1].id, personId: "p_alex", values: SetValues(weight: 30, reps: 8))
        world.clock.advance(seconds: 60)
        try world.engine.logSet(sessionExerciseId: active.cards[0].id, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        let live = try #require(try world.store.workoutDetail(id: active.session.id))
        #expect(live.exerciseOrder == ["ex_bench", "ex_incline"])
    }

    @Test func formattingMatchesThePWA() throws {
        #expect(Format.trimNum(80) == "80")
        #expect(Format.trimNum(77.5) == "77.5")
        #expect(Format.trimNum(42.125) == "42.13")
        #expect(Format.clock(42) == "00:42")
        #expect(Format.clock(605) == "10:05")
        #expect(Format.duration(90) == "1:30")
        #expect(Format.elapsed(72 * 60_000) == "1:12")
        #expect(Format.elapsed(125_000) == "2:05")
        #expect(Format.ordinal(3) == "03")
        let set = SetEntry(id: "s", sessionId: "x", sessionExerciseId: nil, exerciseId: "e", personId: "p", setIndex: 0, weight: 80, reps: 8, duration: 90)
        let bench = Exercise(id: "e", name: "Bench")
        #expect(Format.setSummary(set, exercise: bench, unit: .kg) == "80 kg × 8")
        #expect(Format.setSummary(set, exercise: nil, unit: .lb) == "80 lb × 8 1:30")
        #expect(Format.date(1_782_237_600_000, locale: Locale(identifier: "en_US")) == "Tue, Jun 23")
    }

    @Test func legacyColorKeysResolve() {
        #expect(PersonColor(key: "blue") == .steel)
        #expect(PersonColor(key: "orange") == .red)
        #expect(PersonColor(key: "purple") == .steel)
        #expect(PersonColor(key: "whatever") == .steel)
        #expect(PersonColor(key: "mustard") == .mustard)
    }
}

@Suite struct SetBySetPrefill {
    func log(_ world: World, _ card: String, _ person: String, _ w: Double?, _ r: Int?, duration: Int? = nil) throws {
        try world.engine.logSet(sessionExerciseId: card, personId: person, values: SetValues(weight: w, reps: r, duration: duration, note: "x"))
    }

    @Test func followsLastTimeSetBySetAndCarriesWeightChanges() throws {
        // Last time Alex benched 80×8, 80×7, 77.5×8.
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0].id
        func prefill() throws -> Prefill? { try world.active().prefill(cardId: card, personId: "p_alex") }

        #expect(try prefill() == Prefill(values: SetValues(weight: 80, reps: 8), source: .lastTime(setIndex: 0, weightChange: nil)))
        try log(world, card, "p_alex", 80, 8)
        #expect(try prefill() == Prefill(values: SetValues(weight: 80, reps: 7), source: .lastTime(setIndex: 1, weightChange: nil)))
        try log(world, card, "p_alex", 82.5, 7) // +2.5 on set 2
        #expect(try prefill() == Prefill(values: SetValues(weight: 80, reps: 8), source: .lastTime(setIndex: 2, weightChange: 2.5)))
        try log(world, card, "p_alex", 80, 8)
        // Past last time's three sets: repeat today's latest (never its note).
        #expect(try prefill() == Prefill(values: SetValues(weight: 80, reps: 8), source: .today(ordinal: 3)))
    }

    @Test func undoMovesThePrefillBack() throws {
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0].id
        let id = try world.engine.logSet(sessionExerciseId: card, personId: "p_alex", values: SetValues(weight: 80, reps: 8))
        try world.engine.undoSet(id: id)
        #expect(try world.active().defaultValues(cardId: card, personId: "p_alex") == SetValues(weight: 80, reps: 8))
    }

    @Test func withoutHistoryItRepeatsTodaysLatestSet() throws {
        let world = try World()
        let active = try world.startPushDay(.independent)
        let card = active.cards[0].id
        try world.engine.setVariant(sessionExerciseId: card, variant: .highReps)
        #expect(try world.active().prefill(cardId: card, personId: "p_alex") == nil)
        try log(world, card, "p_alex", 60, 15)
        #expect(try world.active().prefill(cardId: card, personId: "p_alex") ==
                Prefill(values: SetValues(weight: 60, reps: 15), source: .today(ordinal: 1)))
    }

    @Test func eachVariantFollowsItsOwnLastTime() throws {
        let world = try World()
        var active = try world.startPushDay(.independent)
        try world.engine.setVariant(sessionExerciseId: active.cards[0].id, variant: .highReps)
        try log(world, active.cards[0].id, "p_alex", 50, 15)
        try log(world, active.cards[0].id, "p_alex", 50, 12)
        try world.engine.finishSession(id: active.session.id)

        world.clock.advance(seconds: 86_400)
        active = try world.startPushDay(.independent)
        let card = active.cards[0].id
        #expect(try world.active().defaultValues(cardId: card, personId: "p_alex") == SetValues(weight: 80, reps: 8))
        try world.engine.setVariant(sessionExerciseId: card, variant: .highReps)
        #expect(try world.active().defaultValues(cardId: card, personId: "p_alex") == SetValues(weight: 50, reps: 15))
    }

    @Test func timedExercisesDoNotCarryWeight() throws {
        let world = try World()
        let active = try world.startPushDay(.independent)
        let plank = try #require(try world.engine.addSessionExercise(sessionId: active.session.id, exerciseId: "ex_plank"))
        try log(world, plank, "p_alex", nil, nil, duration: 60)
        try log(world, plank, "p_alex", nil, nil, duration: 75)
        try world.engine.finishSession(id: active.session.id)

        world.clock.advance(seconds: 86_400)
        let next = try world.startPushDay(.independent)
        let card = try #require(try world.engine.addSessionExercise(sessionId: next.session.id, exerciseId: "ex_plank"))
        try log(world, card, "p_alex", nil, nil, duration: 90)
        #expect(try world.active().prefill(cardId: card, personId: "p_alex") ==
                Prefill(values: SetValues(duration: 75), source: .lastTime(setIndex: 1, weightChange: nil)))
    }

    @Test func repeatLogsTheSetJustDone() throws {
        let world = try World()
        let card = try world.startPushDay(.independent).cards[0].id
        #expect(try world.active().repeatValues(cardId: card, personId: "p_alex") == SetValues(weight: 80, reps: 8))
        try log(world, card, "p_alex", 90, 3)
        // The pre-fill moves on to last time's set 2 (+10); Repeat repeats 90×3.
        #expect(try world.active().defaultValues(cardId: card, personId: "p_alex") == SetValues(weight: 90, reps: 7))
        #expect(try world.active().repeatValues(cardId: card, personId: "p_alex") == SetValues(weight: 90, reps: 3))
    }
}
