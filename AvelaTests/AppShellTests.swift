import XCTest
import UIKit
@testable import Avela

final class AppShellTests: XCTestCase {
    func testBundledSystemIntegrationConfigurationIsPresent() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool, true,
                       "The installed app must declare Live Activity support, not just compile ActivityKit code")
        for key in ["NSHealthShareUsageDescription", "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"] {
            let purpose = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? String, key)
            XCTAssertFalse(purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
        }
    }

    func testRilovaBrandIsBundledWithoutChangingExistingIntegrationIdentity() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Rilova")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.example.Avela")
        XCTAssertEqual(WidgetSnapshotStore.appGroupID, "group.com.example.Avela")
        XCTAssertEqual(PremiumProductID.monthly, "com.avela.premium.monthly")
        XCTAssertEqual(PremiumProductID.annual, "com.avela.premium.annual")
        let icon = try XCTUnwrap(UIImage(named: "BrandIcon"))
        XCTAssertEqual(icon.size.width, icon.size.height)
        XCTAssertGreaterThanOrEqual(icon.size.width, 256)
        let healthPurpose = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") as? String)
        XCTAssertTrue(healthPurpose.hasPrefix("Rilova reads"))
    }
    func testNavigationDestinationsHaveStableOrderAndIdentity() {
        XCTAssertEqual(AppTab.allCases, [.today, .insights, .history, .settings])
        XCTAssertEqual(AppTab.allCases.map(\.id), ["today", "insights", "history", "settings"])
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Today", "Insights", "History", "Settings"])
    }
}
