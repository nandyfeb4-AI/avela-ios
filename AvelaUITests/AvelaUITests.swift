import XCTest

final class AvelaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testShellNavigationAndRelaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["placeholder.today"].waitForExistence(timeout: 10))

        for destination in ["Insights", "History", "Settings", "Today"] {
            app.tabBars.buttons[destination].tap()
            XCTAssertTrue(
                app.staticTexts["placeholder.\(destination.lowercased())"].waitForExistence(timeout: 5)
            )
        }

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["placeholder.today"].waitForExistence(timeout: 10))
    }
}
