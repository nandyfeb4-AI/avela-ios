import StoreKitTest
import XCTest
@testable import Avela

/// Native local StoreKit testing: no App Store Connect account or runtime
/// secrets. The config must be copied into the AvelaTests resource bundle.
@MainActor
final class StoreKitSubscriptionServiceTests: XCTestCase {
    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Avela", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// StoreKitTest mutations are acknowledged before StoreKit 2's local
    /// entitlement sequence necessarily reflects them. Wait for the real
    /// authoritative result with a bounded timeout, never assume a fixed sleep.
    private func waitForPremium(_ expected: Bool, service: StoreKitSubscriptionService) async throws -> Bool {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            let current = await service.currentEntitlements()
            if PremiumAccessPolicy.hasPremium(current, asOf: Date()) == expected { return true }
            try await Task.sleep(for: .milliseconds(50))
        } while Date() < deadline
        return false
    }

    func testLocalProductsSupplyPricesAndVerifiedPurchaseUnlocks() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = StoreKitSubscriptionService()
        let plans = try await service.loadPlans()
        XCTAssertEqual(Set(plans.map(\.id)), PremiumProductID.all)
        XCTAssertTrue(plans.allSatisfy { !$0.displayPrice.isEmpty })
        XCTAssertEqual(plans.first?.billingPeriod, "month")

        let outcome = try await service.purchase(productID: PremiumProductID.monthly)
        XCTAssertEqual(outcome, .purchased)
        let entitlements = await service.currentEntitlements()
        XCTAssertTrue(PremiumAccessPolicy.hasPremium(entitlements, asOf: Date()))
        try await service.restore()
        let restored = await service.currentEntitlements()
        XCTAssertTrue(PremiumAccessPolicy.hasPremium(restored, asOf: Date()))
    }

    func testLocalExpiredSubscriptionRemovesPremiumAccess() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.timeRate = .oneRenewalEveryTwoSeconds
        let transaction = try await session.buyProduct(identifier: PremiumProductID.monthly)
        await transaction.finish()
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        let service = StoreKitSubscriptionService()
        let before = await service.currentEntitlements()
        XCTAssertTrue(PremiumAccessPolicy.hasPremium(before, asOf: Date()))
        // Use actual accelerated expiration with auto-renew disabled. On this
        // Xcode runtime, expireSubscription mutates SKTestSession metadata but
        // leaves StoreKit 2's original signed expiry/status cached. Natural
        // expiration exercises the real app authority instead of that helper.
        let removed = try await waitForPremium(false, service: service)
        XCTAssertTrue(removed, "Expired subscription must disappear from authoritative StoreKit entitlements")
    }

    func testLocalRefundRemovesPremiumAccess() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let transaction = try await session.buyProduct(identifier: PremiumProductID.annual)
        await transaction.finish()
        let service = StoreKitSubscriptionService()
        let before = await service.currentEntitlements()
        XCTAssertTrue(PremiumAccessPolicy.hasPremium(before, asOf: Date()))
        try session.refundTransaction(identifier: UInt(transaction.id))
        let removed = try await waitForPremium(false, service: service)
        XCTAssertTrue(removed, "Refunded subscription must disappear from authoritative StoreKit entitlements")
    }
}
