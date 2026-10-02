import XCTest
@testable import Avela

final class AppShellTests: XCTestCase {
    func testNavigationDestinationsHaveStableOrderAndIdentity() {
        XCTAssertEqual(AppTab.allCases, [.today, .insights, .history, .settings])
        XCTAssertEqual(AppTab.allCases.map(\.id), ["today", "insights", "history", "settings"])
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Today", "Insights", "History", "Settings"])
    }
}
