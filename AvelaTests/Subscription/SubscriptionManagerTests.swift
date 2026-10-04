import XCTest
@testable import Avela

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func activeEntitlement() -> PremiumEntitlement {
        PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: true, expirationDate: now.addingTimeInterval(3600), revocationDate: nil)
    }

    func testPurchaseOnlyUnlocksAfterAuthoritativeEntitlementRefresh() async {
        let service = TestSubscriptionService()
        let manager = SubscriptionManager(service: service, now: { self.now })
        await manager.loadPlans()
        service.entitlements = [activeEntitlement()]
        await manager.purchase(productID: PremiumProductID.monthly)
        XCTAssertTrue(manager.hasPremium)
        XCTAssertEqual(manager.status, .purchased)
        XCTAssertEqual(service.purchasedIDs, [PremiumProductID.monthly])
    }

    func testSuccessfulPurchaseWithoutVerifiedEntitlementDoesNotUnlock() async {
        let manager = SubscriptionManager(service: TestSubscriptionService(), now: { self.now })
        await manager.loadPlans()
        await manager.purchase(productID: PremiumProductID.monthly)
        XCTAssertFalse(manager.hasPremium)
        XCTAssertEqual(manager.status, .verificationFailed)
    }

    func testPendingCancelledAndUnverifiedAreDistinctAndDoNotUnlock() async {
        for (outcome, status) in [
            (SubscriptionPurchaseOutcome.pending, SubscriptionActionStatus.pending),
            (.cancelled, .cancelled), (.unverified, .verificationFailed)
        ] {
            let service = TestSubscriptionService()
            service.outcome = outcome
            let manager = SubscriptionManager(service: service, now: { self.now })
            await manager.loadPlans()
            await manager.purchase(productID: PremiumProductID.monthly)
            XCTAssertEqual(manager.status, status)
            XCTAssertFalse(manager.hasPremium)
            XCTAssertFalse(manager.isBusy)
        }
    }

    func testUnavailableStoreDoesNotRemoveExistingAccess() async {
        let service = TestSubscriptionService()
        service.entitlements = [activeEntitlement()]
        let manager = SubscriptionManager(service: service, now: { self.now })
        await manager.refreshEntitlements()
        service.shouldFail = true
        await manager.loadPlans()
        XCTAssertTrue(manager.hasPremium)
        XCTAssertEqual(manager.status, .unavailable)
        XCTAssertFalse(manager.isBusy)
    }

    func testPendingApprovalRefreshUpdatesBothAccessAndMessage() async {
        let service = TestSubscriptionService()
        service.outcome = .pending
        let manager = SubscriptionManager(service: service, now: { self.now })
        await manager.loadPlans()
        await manager.purchase(productID: PremiumProductID.monthly)
        XCTAssertEqual(manager.status, .pending)
        service.entitlements = [activeEntitlement()]
        await manager.refreshEntitlements()
        XCTAssertTrue(manager.hasPremium)
        XCTAssertEqual(manager.status, .purchased)
    }

    func testRestoreRefreshesAppleAuthorityAndReportsNothingWhenEmpty() async {
        let service = TestSubscriptionService()
        let manager = SubscriptionManager(service: service, now: { self.now })
        await manager.restorePurchases()
        XCTAssertEqual(manager.status, .nothingToRestore)
        XCTAssertEqual(service.restoreCalls, 1)
        service.entitlements = [activeEntitlement()]
        await manager.restorePurchases()
        XCTAssertEqual(manager.status, .restored)
        XCTAssertTrue(manager.hasPremium)
        service.entitlements = []
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.hasPremium, "An empty authoritative snapshot must remove expired/refunded access")
    }

    func testExpiredSubscriptionRestoresFreeCreationLimits() async {
        let service = TestSubscriptionService()
        service.entitlements = [PremiumEntitlement(productID: PremiumProductID.monthly, isVerified: true, expirationDate: now, revocationDate: nil)]
        let manager = SubscriptionManager(service: service, now: { self.now })
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.hasPremium)
        XCTAssertFalse(manager.canCreateHabit(activeCount: 3))
        XCTAssertFalse(manager.canCreateAttentionGoal(activeCount: 1))
    }

    func testMissingProductsHaveHonestUnavailableStateAndCannotPurchase() async {
        let service = TestSubscriptionService()
        service.plans = []
        let manager = SubscriptionManager(service: service)
        await manager.loadPlans()
        XCTAssertEqual(manager.status, .unavailable)
        await manager.purchase(productID: PremiumProductID.monthly)
        XCTAssertEqual(service.purchasedIDs, [])
    }

    func testRestoreFailureLeavesFreeTrackingUsable() async {
        let service = TestSubscriptionService()
        service.shouldFail = true
        let manager = SubscriptionManager(service: service)
        await manager.restorePurchases()
        XCTAssertEqual(manager.status, .unavailable)
        XCTAssertTrue(manager.canCreateHabit(activeCount: 0))
        XCTAssertFalse(manager.isBusy)
    }
}

@MainActor
private final class TestSubscriptionService: SubscriptionService {
    var plans = [SubscriptionPlan(id: PremiumProductID.monthly, displayName: "Monthly", displayPrice: "$2.99", billingPeriod: "month")]
    var entitlements: [PremiumEntitlement] = []
    var outcome: SubscriptionPurchaseOutcome = .purchased
    var shouldFail = false
    var purchasedIDs: [String] = []
    var restoreCalls = 0

    func loadPlans() async throws -> [SubscriptionPlan] {
        if shouldFail { throw SubscriptionStoreError.productUnavailable }
        return plans
    }
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        if shouldFail { throw SubscriptionStoreError.productUnavailable }
        purchasedIDs.append(productID)
        return outcome
    }
    func currentEntitlements() async -> [PremiumEntitlement] { entitlements }
    func restore() async throws {
        if shouldFail { throw SubscriptionStoreError.productUnavailable }
        restoreCalls += 1
    }
    func listenForUpdates(onUpdate: @escaping @MainActor () async -> Void) async {}
}
