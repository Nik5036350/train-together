import XCTest

/// A visual audit: restores from a local backend (see WorkoutFlowTests for
/// how to start one), then visits every screen and sheet and screenshots it.
/// Nothing is asserted beyond getting there; a missing step is noted and the
/// tour goes on.
///
/// Screenshots are attached to the result, and also written as numbered PNGs
/// to `TT_SHOTS_DIR` when it's set:
///
///     TEST_RUNNER_TT_SHOTS_DIR=/tmp/shots xcodebuild test -scheme TrainTogetherE2E \
///       -only-testing:TrainTogetherUITests/ScreenTourTests …
@MainActor
final class ScreenTourTests: XCTestCase {
    private var app: XCUIApplication!
    private var shots = 0
    private let env = ProcessInfo.processInfo.environment
    private var server: String { env["TT_E2E_SERVER"] ?? "http://localhost:8080" }
    private var token: String { env["TT_E2E_TOKEN"] ?? "e2e-token-0123456789abcdefghijklmnop" }

    override func setUp() async throws {
        continueAfterFailure = true
        app = XCUIApplication()
        // Browse tests use whatever the simulator already has.
        if !name.contains("testBrowse") { app.launchEnvironment["TT_RESET"] = "1" }
        app.launchArguments += ["-device.restAlerts", "NO", "-device.liveActivity", "NO"]
        app.launch()
    }

    func testTour() throws {
        onboarding()
        workoutTab()
        liveWorkout()
        history()
        settings()
        finishWorkout()
    }

    /// Flicks History down and back up to the top in both modes, for a
    /// screen recording (`xcrun simctl io booted recordVideo`).
    func testBrowseHistoryScroll() throws {
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 15), "no data on the phone")
        app.tabBars.buttons["History"].tap()
        for mode in ["Workouts", "Exercises"] {
            tap(button(mode))
            sleep(1)
            for _ in 0..<3 { app.swipeUp(velocity: .fast) }
            for _ in 0..<4 { app.swipeDown(velocity: .fast) }
            sleep(2)
        }
    }

    // MARK: Sections

    private func onboarding() {
        guard wait(button("Restore from server"), 15) else { return }
        shot("onboarding-welcome")
        tap(button("Start fresh"))
        shot("onboarding-you")
        back()
        tap(button("Restore from server"))
        shot("onboarding-restore")
        let fields = app.textFields
        fields.element(boundBy: 0).tap()
        fields.element(boundBy: 0).typeText(server)
        fields.element(boundBy: 1).tap()
        fields.element(boundBy: 1).typeText(token)
        tap(button("Restore"))
        dismissSystemPrompts()
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 30), "restore didn't finish")
        sleep(1)
    }

    private func workoutTab() {
        shot("workout-home")
        app.swipeUp()
        shot("workout-home-bottom")
        app.swipeDown()

        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Edit ")).firstMatch)
        shot("routine-builder")
        let add = button("Add exercise")
        for _ in 0..<3 where !add.isHittable { app.swipeUp() }
        tap(add)
        sleep(1)
        shot("picker")
        app.swipeUp()
        shot("picker-popular")
        tap(button("Legs"))
        shot("picker-legs")
        tap(button("All"))
        // The list is lazy: its first row only exists once scrolled back up.
        app.swipeDown()
        app.swipeDown()
        tap(app.buttons["create-exercise"])
        shot("editor-new")
        back()
        let search = app.searchFields.firstMatch
        if wait(search, 3) {
            search.tap()
            search.typeText("curl")
            sleep(1)
            shot("picker-search")
        }
        // Searching hides the sheet's Cancel; drag the sheet away instead.
        dismissSheet()
        if !add.waitForExistence(timeout: 2) { dismissSheet() }
        back()
    }

    private func liveWorkout() {
        // Back at the Workout tab's root, whatever the previous section left.
        app.tabBars.buttons["Workout"].tap()
        app.tabBars.buttons["Workout"].tap()
        // A workout restored from the server is resumed instead.
        let resume = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume")).firstMatch
        if resume.waitForExistence(timeout: 2) {
            resume.tap()
        } else {
            tap(button("Start workout"))
            guard wait(text("Who's training"), 5) else { return }
            shot("start-sheet")
            tap(app.buttons["start-workout-confirm"])
        }
        // Resuming reopens the card it was on; step back to the overview.
        if !wait(text("Standard plan"), 5) {
            shot("resumed")
            back()
        }
        guard wait(text("Standard plan"), 5) else {
            shot("no-live-overview")
            return XCTFail("no live overview")
        }
        shot("live-overview")
        app.swipeUp()
        shot("live-overview-bottom")
        app.swipeDown()

        tap(app.buttons["card-1"])
        let log = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Log set", "Log & pass")).firstMatch
        guard wait(log, 5) else { return }
        shot("logging-card")
        log.tap()
        sleep(1)
        shot("logging-logged")
        app.swipeUp()
        shot("logging-card-bottom")
        app.swipeDown()

        sleep(6) // let the "Logged" snackbar clear the action row
        for (label, name) in [("Notes", "sheet-notes"), ("Skip", "sheet-skip")] {
            tap(button(label))
            sleep(1)
            shot(name)
            dismissSheet()
        }
        tap(button("Substitute"))
        sleep(1)
        shot("sheet-substitute")
        let field = app.textFields.firstMatch
        if wait(field, 2) {
            field.tap()
            field.typeText("row")
            shot("sheet-substitute-search")
        }
        dismissSheet()

        let set = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Edit set")).firstMatch
        if wait(set, 2) {
            set.tap()
            sleep(1)
            shot("set-menu")
            let edit = button("Edit")
            if wait(edit, 2) {
                edit.tap()
                sleep(1)
                shot("sheet-edit-set")
                dismissSheet()
            } else {
                dismissMenu()
            }
        }
        let rest = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Resting", "Ready")).firstMatch
        if wait(rest, 2) {
            rest.tap()
            sleep(1)
            shot("rest-menu")
            let setDefault = button("Set default rest…")
            if wait(setDefault, 2) {
                setDefault.tap()
                sleep(1)
                shot("sheet-rest-length")
                dismissSheet()
            } else {
                dismissMenu()
            }
        }
        back()
        tap(app.buttons["find-exercise"])
        sleep(1)
        shot("live-find-exercise")
        tap(button("Cancel"))
        tap(app.buttons["Minimize workout"])
        sleep(1)
        shot("workout-home-in-progress")
    }

    private func history() {
        app.tabBars.buttons["History"].tap()
        sleep(1)
        shot("history-workouts")
        app.swipeUp()
        shot("history-workouts-scrolled")
        app.swipeDown()
        tap(app.cells.firstMatch)
        sleep(1)
        shot("workout-detail")
        app.swipeUp()
        shot("workout-detail-bottom")
        let progress = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress-")).firstMatch
        for _ in 0..<3 where !progress.isHittable { app.swipeDown() }
        if wait(progress, 2) {
            progress.tap()
            sleep(1)
            shot("exercise-progress-from-workout")
            back()
        }
        back()

        tap(button("Exercises"))
        sleep(1)
        shot("history-exercises")
        app.swipeUp()
        shot("history-exercises-scrolled")
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "exercise-")).firstMatch
        for _ in 0..<4 where !first.exists { app.swipeUp() }
        if wait(first, 3) {
            first.tap()
            sleep(1)
            shot("exercise-progress")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).tap()
            shot("exercise-progress-selected")
            app.swipeUp()
            shot("exercise-progress-records")
            app.swipeUp()
            shot("exercise-progress-ledger")
            back()
        }
        app.swipeDown()
        app.swipeDown()
        tap(button("Workouts"))
    }

    private func settings() {
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        shot("settings")
        app.swipeUp()
        shot("settings-bottom")
        app.swipeDown()
        tap(app.buttons["settings-owner"])
        sleep(1)
        shot("person-edit")
        app.swipeUp()
        shot("person-edit-bottom")
        back()
        tap(app.buttons["settings-exercises"])
        sleep(1)
        shot("exercise-library")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Weight")).firstMatch)
        sleep(1)
        shot("exercise-editor")
        app.swipeUp()
        shot("exercise-editor-bottom")
        back()
        back()
        let sync = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Server sync")).firstMatch
        for _ in 0..<3 where !sync.isHittable { app.swipeUp() }
        tap(sync)
        sleep(1)
        shot("sync")
        back()
        let data = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Data on this phone")).firstMatch
        for _ in 0..<3 where !data.isHittable { app.swipeUp() }
        tap(data)
        sleep(2)
        shot("data")
        back()
    }

    private func finishWorkout() {
        app.tabBars.buttons["Workout"].tap()
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume")).firstMatch)
        if !wait(text("Standard plan"), 5) { back() }
        guard wait(button("Finish"), 5) else { return XCTFail("no Finish button") }
        tap(button("Finish"))
        sleep(1)
        shot("finish-sheet")
        tap(app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label ==[c] %@", "Finish anyway", "Finish & see summary")).firstMatch)
        guard wait(text("Workout complete"), 5) else { return }
        shot("summary")
        app.swipeUp()
        shot("summary-bottom")
        tap(button("Done"))
        sleep(1)
        shot("workout-home-after")
    }

    // MARK: Helpers

    private func shot(_ name: String) {
        shots += 1
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = env["TT_SHOTS_DIR"] {
            let file = String(format: "%02d-%@.png", shots, name)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: file))
        }
    }

    @discardableResult
    private func wait(_ element: XCUIElement, _ timeout: TimeInterval = 3) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Taps when the element shows up; otherwise notes it and moves on.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        if element.waitForExistence(timeout: 4) {
            element.tap()
        } else {
            XCTFail("not found: \(element)", file: file, line: line)
        }
    }

    private func back() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 2) { back.tap() }
        sleep(1)
    }

    private func dismissSheet() {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        sleep(1)
    }

    private func dismissMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        sleep(1)
    }

    private func dismissSystemPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Not Now", "Don’t Allow", "Don't Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1) { button.tap() }
        }
    }

    private func button(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    private func text(_ label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }
}
