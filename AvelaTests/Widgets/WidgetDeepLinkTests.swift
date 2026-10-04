import XCTest
@testable import Avela

final class WidgetDeepLinkTests: XCTestCase {
    func testTodayAndCompletionRoundTrip() {
        XCTAssertEqual(WidgetDeepLink.parse(WidgetDeepLink.today.url), .today)
        let link = WidgetDeepLink.complete(habitID: UUID(), localDateKey: "2026-10-04")
        XCTAssertEqual(WidgetDeepLink.parse(link.url), link)
    }

    func testRejectsWrongSchemeMalformedIDsDatesDuplicateAndUnexpectedParameters() {
        let id = UUID().uuidString
        let invalid = [
            "https://complete?habit=\(id)&day=2026-10-04",
            "avela://complete?habit=invalid&day=2026-10-04",
            "avela://complete?habit=\(id)&day=2026-02-30",
            "avela://complete?habit=\(id)&day=2026-2-03",
            "avela://complete?habit=\(id)&day=2026-10-04&day=2026-10-04",
            "avela://complete?habit=\(id)&day=2026-10-04&extra=yes",
            "avela://complete/path?habit=\(id)&day=2026-10-04",
            "avela://user@complete?habit=\(id)&day=2026-10-04",
            "avela://complete?habit=\(id)&day=2026-10-04#fragment",
            "avela://today?extra=yes",
            "avela://unknown"
        ]
        for text in invalid {
            XCTAssertNil(WidgetDeepLink.parse(URL(string: text)!), text)
        }
    }

    func testAcceptsRealLeapDay() {
        let link = WidgetDeepLink.complete(habitID: UUID(), localDateKey: "2024-02-29")
        XCTAssertEqual(WidgetDeepLink.parse(link.url), link)
    }
}
