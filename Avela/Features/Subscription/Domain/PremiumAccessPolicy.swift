import Foundation

enum PremiumProductID {
    static let monthly = "com.avela.premium.monthly"
    static let annual = "com.avela.premium.annual"
    static let all: Set<String> = [monthly, annual]
}

/// A normalized StoreKit fact. Persistence is never the entitlement authority.
struct PremiumEntitlement: Equatable, Sendable {
    let productID: String
    let isVerified: Bool
    let expirationDate: Date?
    let revocationDate: Date?
}

/// Limits apply only to creating additional active tracking items. Existing
/// records, logging, editing, recovery and history remain accessible on expiry.
enum PremiumAccessPolicy {
    static let freeHabitLimit = 3
    static let freeAttentionGoalLimit = 1

    static func hasPremium(_ entitlements: [PremiumEntitlement], asOf date: Date) -> Bool {
        entitlements.contains {
            PremiumProductID.all.contains($0.productID)
                && $0.isVerified
                && $0.revocationDate == nil
                && ($0.expirationDate.map { $0 > date } ?? false)
        }
    }

    static func canCreateHabit(activeCount: Int, hasPremium: Bool) -> Bool {
        hasPremium || activeCount < freeHabitLimit
    }

    static func canCreateAttentionGoal(activeCount: Int, hasPremium: Bool) -> Bool {
        hasPremium || activeCount < freeAttentionGoalLimit
    }
}
