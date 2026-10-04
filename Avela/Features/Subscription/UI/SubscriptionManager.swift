import Foundation
import Observation
import OSLog

enum SubscriptionActionStatus: Equatable {
    case idle, purchased, pending, cancelled, restored, nothingToRestore, unavailable, verificationFailed

    var message: String? {
        switch self {
        case .idle: return nil
        case .purchased: return "Premium is ready. Thank you for supporting Avela."
        case .pending: return "Your purchase is awaiting approval. Premium will unlock when Apple confirms it."
        case .cancelled: return "Purchase cancelled. You can continue using Avela for free."
        case .restored: return "Your Premium subscription has been restored."
        case .nothingToRestore: return "No active Premium subscription was found for this Apple Account."
        case .unavailable: return "The App Store is unavailable right now. Please try again later. Your existing tracking remains available."
        case .verificationFailed: return "We couldn't verify this purchase. Please try Restore Purchases. Your existing tracking remains available."
        }
    }
}

/// One app-owned manager. StoreKit remains the sole authority; no cached
/// Boolean or DEBUG environment variable can grant Premium access.
@MainActor
@Observable
final class SubscriptionManager {
    private(set) var plans: [SubscriptionPlan] = []
    private(set) var entitlements: [PremiumEntitlement] = []
    private(set) var isBusy = false
    private(set) var status: SubscriptionActionStatus = .idle

    @ObservationIgnored private let service: SubscriptionService
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var refreshRevision = 0
    private static let logger = Logger(subsystem: "com.example.Avela", category: "Subscription")

    init(service: SubscriptionService? = nil, now: @escaping () -> Date = Date.init) {
        self.service = service ?? StoreKitSubscriptionService()
        self.now = now
    }

    deinit { updatesTask?.cancel() }

    var hasPremium: Bool {
        PremiumAccessPolicy.hasPremium(entitlements, asOf: now())
    }

    func canCreateHabit(activeCount: Int) -> Bool {
        PremiumAccessPolicy.canCreateHabit(activeCount: activeCount, hasPremium: hasPremium)
    }

    func canCreateAttentionGoal(activeCount: Int) -> Bool {
        PremiumAccessPolicy.canCreateAttentionGoal(activeCount: activeCount, hasPremium: hasPremium)
    }

    /// Start at the app composition root, and refresh on scene activation.
    /// Repeated paywall presentations do not create duplicate listeners.
    func start() async {
        if updatesTask == nil {
            let service = self.service
            updatesTask = Task { [weak self] in
                await service.listenForUpdates { [weak self] in
                    await self?.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
        if plans.isEmpty { await loadPlans() }
    }

    func refreshEntitlements() async {
        refreshRevision += 1
        let revision = refreshRevision
        let current = await service.currentEntitlements()
        guard revision == refreshRevision else { return }
        entitlements = current
        if hasPremium && status == .pending {
            status = .purchased
        } else if !hasPremium && (status == .purchased || status == .restored) {
            status = .idle
        }
    }

    func loadPlans() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            plans = try await service.loadPlans()
            status = plans.isEmpty ? .unavailable : .idle
        } catch {
            status = .unavailable
            Self.logger.error("Loading subscription products failed: \(String(describing: error), privacy: .private)")
        }
    }

    func purchase(productID: String) async {
        guard !isBusy else { return }
        guard plans.contains(where: { $0.id == productID }) else {
            status = .unavailable
            return
        }
        isBusy = true
        status = .idle
        defer { isBusy = false }
        do {
            switch try await service.purchase(productID: productID) {
            case .purchased:
                await refreshEntitlements()
                status = hasPremium ? .purchased : .verificationFailed
            case .pending: status = .pending
            case .cancelled: status = .cancelled
            case .unverified: status = .verificationFailed
            }
        } catch {
            status = .unavailable
            Self.logger.error("Subscription purchase failed: \(String(describing: error), privacy: .private)")
        }
    }

    func restorePurchases() async {
        guard !isBusy else { return }
        isBusy = true
        status = .idle
        defer { isBusy = false }
        do {
            try await service.restore()
            await refreshEntitlements()
            status = hasPremium ? .restored : .nothingToRestore
        } catch {
            status = .unavailable
            Self.logger.error("Restoring purchases failed: \(String(describing: error), privacy: .private)")
        }
    }
}
