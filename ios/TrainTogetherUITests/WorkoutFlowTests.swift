import XCTest

/// End-to-end: a fresh phone restores the legacy data from a local backend,
/// runs a two-person workout and checks history and sync. Screenshots are
/// attached to the test result.
///
/// Needs the backend running with the seed imported into the sync store:
///
///     cd backend && SYNC_TOKEN=<token> cargo run
///     curl -X POST -H "Authorization: Bearer <token>" \
///       "http://localhost:8080/api/v2/admin/import-legacy?source=db&replace=true"
///
/// and the same token in TT_E2E_TOKEN (default below).
@MainActor
final class WorkoutFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private let server = ProcessInfo.processInfo.environment["TT_E2E_SERVER"] ?? "http://localhost:8080"
    private let token = ProcessInfo.processInfo.environment["TT_E2E_TOKEN"] ?? "e2e-token-0123456789abcdefghijklmnop"

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TT_RESET"] = "1"
        // No permission prompts mid-flow.
        app.launchArguments += ["-device.restAlerts", "NO", "-device.liveActivity", "NO"]
        app.launch()
    }

    func testRestoreWorkoutAndHistory() throws {
        // Onboarding → restore from the server.
        snapshot("01-onboarding")
        button("Restore from server").tap()
        let fields = app.textFields
        fields.element(boundBy: 0).tap()
        fields.element(boundBy: 0).typeText(server)
        fields.element(boundBy: 1).tap()
        fields.element(boundBy: 1).typeText(token)
        button("Restore").tap()
        dismissSystemPrompts()

        // Workout tab with the imported routine.
        XCTAssertTrue(text("Push Day").waitForExistence(timeout: 15), "restore didn't bring Push Day")
        dismissSystemPrompts()
        snapshot("02-workout-home")

        // Start Push Day for both people.
        button("Start workout").tap()
        XCTAssertTrue(text("Who's training").waitForExistence(timeout: 5))
        snapshot("03-start-sheet")
        app.buttons["start-workout-confirm"].tap()

        // Live overview → first exercise.
        XCTAssertTrue(text("Standard plan").waitForExistence(timeout: 8), "the live workout didn't open")
        snapshot("04-live-overview")
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Bench Press")).firstMatch.tap()

        // Log for Alex (pre-filled from last time), then Maria.
        let logAlex = button("Log set · Alex")
        XCTAssertTrue(logAlex.waitForExistence(timeout: 5))
        snapshot("05-logging-card")
        logAlex.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Logged")).firstMatch.waitForExistence(timeout: 3))
        snapshot("06-logged-snackbar")
        let logMaria = button("Log set · Maria")
        if logMaria.waitForExistence(timeout: 3) { logMaria.tap() }
        snapshot("07-both-logged")

        // Back to the overview and finish.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        button("Finish").tap()
        let finish = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label ==[c] %@", "Finish anyway", "Finish & see summary")).firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        snapshot("08-finish-sheet")
        finish.tap()

        // Summary → Done.
        XCTAssertTrue(text("Workout complete").waitForExistence(timeout: 5))
        snapshot("09-summary")
        button("Done").tap()

        // History has both workouts.
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.cells.element(boundBy: 1).waitForExistence(timeout: 5), "expected two workouts in history")
        snapshot("10-history")
        app.cells.element(boundBy: 0).tap()
        XCTAssertTrue(text("Shared session").waitForExistence(timeout: 5))
        snapshot("11-workout-detail")

        // Settings → sync shows everything uploaded.
        app.tabBars.buttons["Settings"].tap()
        snapshot("12-settings")
        // The sync row is below the fold; list rows only exist once on screen.
        let syncRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Server sync")).firstMatch
        for _ in 0..<4 where !syncRow.isHittable { app.swipeUp() }
        syncRow.tap()
        let synced = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "SYNCED")).firstMatch
        XCTAssertTrue(synced.waitForExistence(timeout: 15), "sync didn't settle")
        snapshot("13-sync")
    }

    /// Read-only: restores from the server and walks History and Settings →
    /// Data (phone vs server counts) for screenshots — nothing is written
    /// back, so it's safe against production
    /// (`TEST_RUNNER_TT_E2E_SERVER=https://… TEST_RUNNER_TT_E2E_TOKEN=…`).
    /// Uninstall the app afterwards so the simulator can't become a second
    /// writer.
    func testRestoreOnly() throws {
        button("Restore from server").tap()
        let fields = app.textFields
        fields.element(boundBy: 0).tap()
        fields.element(boundBy: 0).typeText(server)
        fields.element(boundBy: 1).tap()
        fields.element(boundBy: 1).typeText(token)
        button("Restore").tap()
        dismissSystemPrompts()
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 30), "restore didn't finish")
        snapshot("restore-01-workout")

        // History renders rows lazily, so only check it isn't empty; the Data
        // screen below is the count comparison.
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5), "no workouts restored")
        snapshot("restore-02-history")

        // Settings → Data compares the phone's record counts with the server's.
        app.tabBars.buttons["Settings"].tap()
        let dataRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Data on this phone")).firstMatch
        for _ in 0..<4 where !dataRow.isHittable { app.swipeUp() }
        dataRow.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Sets")).firstMatch.waitForExistence(timeout: 10))
        sleep(2) // the server column loads asynchronously
        snapshot("restore-03-data")
    }

    // MARK: Helpers

    /// Springboard prompts (e.g. "Save Password?") that would swallow taps.
    private func dismissSystemPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Not Now", "Don’t Allow", "Don't Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1) { button.tap() }
            let inApp = app.buttons[label]
            if inApp.exists { inApp.tap() }
        }
    }

    private func button(_ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    private func text(_ label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
