import Foundation
import StoreKit

@MainActor
final class StoreKitSubscriptionService: SubscriptionService {
    private var products: [String: Product] = [:]

    func loadPlans() async throws -> [SubscriptionPlan] {
        let fetched = try await Product.products(for: PremiumProductID.all)
        let subscriptions = fetched.filter { $0.type == .autoRenewable }
        products = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0) })
        return subscriptions.compactMap { product in
            guard let period = product.subscription?.subscriptionPeriod else { return nil }
            return SubscriptionPlan(
                id: product.id, displayName: product.displayName,
                displayPrice: product.displayPrice,
                billingPeriod: Self.periodLabel(value: period.value, unit: period.unit)
            )
        }.sorted { $0.id == PremiumProductID.monthly && $1.id != PremiumProductID.monthly }
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard let product = products[productID] else { throw SubscriptionStoreError.productUnavailable }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result else { return .unverified }
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw SubscriptionStoreError.productUnavailable
        }
    }

    func currentEntitlements() async -> [PremiumEntitlement] {
        var entitlements: [PremiumEntitlement] = []
        for await result in Transaction.currentEntitlements {
            // Never extract payload from an unverified result as authority.
            guard case .verified(let transaction) = result else { continue }
            var authoritativeTransaction = transaction
            // A signed transaction's original expiry can remain cached when
            // Apple's subscription status has already moved to expired or
            // revoked (also reproducible with SKTestSession forced expiry).
            // Consult the verified renewal status before granting access.
            if let status = await transaction.subscriptionStatus {
                guard case .verified(let statusTransaction) = status.transaction,
                      case .verified = status.renewalInfo,
                      statusTransaction.originalID == transaction.originalID,
                      status.state == .subscribed || status.state == .inGracePeriod
                else { continue }
                authoritativeTransaction = statusTransaction
            }
            // If status cannot be fetched offline, the verified transaction's
            // own bounded expiration still applies through domain policy.
            entitlements.append(PremiumEntitlement(
                productID: authoritativeTransaction.productID, isVerified: true,
                expirationDate: authoritativeTransaction.expirationDate,
                revocationDate: authoritativeTransaction.revocationDate
            ))
        }
        return entitlements
    }

    func restore() async throws {
        // This may prompt for Apple Account authentication; call only from
        // the explicit Restore Purchases control, never automatically.
        try await AppStore.sync()
    }

    func listenForUpdates(onUpdate: @escaping @MainActor () async -> Void) async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            guard case .verified(let transaction) = result else { continue }
            await onUpdate()
            await transaction.finish()
        }
    }

    private static func periodLabel(value: Int, unit: Product.SubscriptionPeriod.Unit) -> String {
        let singular: String
        switch unit {
        case .day: singular = "day"
        case .week: singular = "week"
        case .month: singular = "month"
        case .year: singular = "year"
        @unknown default: singular = "billing period"
        }
        return value == 1 ? singular : "\(value) \(singular)s"
    }
}

enum SubscriptionStoreError: Error {
    case productUnavailable
}
