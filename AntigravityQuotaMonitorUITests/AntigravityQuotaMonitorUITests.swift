import XCTest

final class AntigravityQuotaMonitorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuBarAppLaunchesAndRelaunchesCleanly() throws {
        let app = XCUIApplication()
        app.launch()

        let isRunningFirstLaunch = app.wait(for: .runningBackground, timeout: 5)
            || app.wait(for: .runningForeground, timeout: 1)
        XCTAssertTrue(isRunningFirstLaunch)

        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))

        app.launch()
        let isRunningSecondLaunch = app.wait(for: .runningBackground, timeout: 5)
            || app.wait(for: .runningForeground, timeout: 1)
        XCTAssertTrue(isRunningSecondLaunch)

        app.terminate()
    }
}
