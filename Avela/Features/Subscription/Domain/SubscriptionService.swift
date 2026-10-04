import Foundation

struct SubscriptionPlan: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let billingPeriod: String
}

enum SubscriptionPurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
    case unverified
}

/// Apple platform adapter boundary; normalized values make purchase-state
/// handling testable without introducing StoreKit types into domain policy.
@MainActor
protocol SubscriptionService {
    func loadPlans() async throws -> [SubscriptionPlan]
    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome
    func currentEntitlements() async -> [PremiumEntitlement]
    func restore() async throws
    func listenForUpdates(onUpdate: @escaping @MainActor () async -> Void) async
}
