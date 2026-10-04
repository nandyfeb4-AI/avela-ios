import XCTest
@testable import Avela

final class PremiumAccessPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testVerifiedRecognizedUnexpiredSubscriptionUnlocksPremium() {
        for productID in PremiumProductID.all {
            XCTAssertTrue(PremiumAccessPolicy.hasPremium([
                PremiumEntitlement(productID: productID, isVerified: true, expirationDate: now.addingTimeInterval(60), revocationDate: nil)
            ], asOf: now))
        }
    }

    func testUnverifiedRevokedExpiredUnknownAndMissingExpiryCannotUnlock() {
        let rejected = [
            PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: false, expirationDate: now.addingTimeInterval(60), revocationDate: nil),
            PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: true, expirationDate: now.addingTimeInterval(60), revocationDate: now),
            PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: true, expirationDate: now, revocationDate: nil),
            PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: true, expirationDate: now.addingTimeInterval(-1), revocationDate: nil),
            PremiumEntitlement(productID: "another.product", isVerified: true, expirationDate: now.addingTimeInterval(60), revocationDate: nil),
            PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: true, expirationDate: nil, revocationDate: nil)
        ]
        for entitlement in rejected {
            XCTAssertFalse(PremiumAccessPolicy.hasPremium([entitlement], asOf: now))
        }
        XCTAssertFalse(PremiumAccessPolicy.hasPremium([], asOf: now))
    }

    func testFreeCreationLimitsAndPremiumAccess() {
        XCTAssertTrue(PremiumAccessPolicy.canCreateHabit(activeCount: 2, hasPremium: false))
        XCTAssertFalse(PremiumAccessPolicy.canCreateHabit(activeCount: 3, hasPremium: false))
        XCTAssertFalse(PremiumAccessPolicy.canCreateHabit(activeCount: 10, hasPremium: false))
        XCTAssertTrue(PremiumAccessPolicy.canCreateHabit(activeCount: 10, hasPremium: true))
        XCTAssertTrue(PremiumAccessPolicy.canCreateAttentionGoal(activeCount: 0, hasPremium: false))
        XCTAssertFalse(PremiumAccessPolicy.canCreateAttentionGoal(activeCount: 1, hasPremium: false))
        XCTAssertTrue(PremiumAccessPolicy.canCreateAttentionGoal(activeCount: 10, hasPremium: true))
    }
}
