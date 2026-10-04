import SwiftUI

struct PremiumPaywallView: View {
    @Bindable var manager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?
    @State private var isShowingPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(manager.hasPremium ? "You're using Avela Premium" : "Room for more of what matters")
                            .font(.largeTitle.bold())
                        Text("Free includes 3 active habits and 1 attention goal. Premium adds unlimited habits and attention goals.")
                            .foregroundStyle(.secondary)
                    }

                    Label("Unlimited habit tracking", systemImage: "checkmark.circle")
                    Label("Unlimited attention goals", systemImage: "hourglass")
                    Label("Your history always stays accessible", systemImage: "clock.arrow.circlepath")

                    if !manager.hasPremium {
                        if manager.plans.isEmpty {
                            Text("Subscription options aren't available right now. You can keep using Avela for free.")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("premium.productsUnavailable")
                            Button("Try Again") { Task { await manager.loadPlans() } }
                                .disabled(manager.isBusy)
                        } else {
                            ForEach(manager.plans) { plan in
                                Button {
                                    selectedProductID = plan.id
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: selectedProductID == plan.id ? "checkmark.circle.fill" : "circle")
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(plan.displayName).font(.headline)
                                            Text("\(plan.displayPrice) / \(plan.billingPeriod)")
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44)
                                    .padding(16)
                                    .background(Color.appSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("premium.plan.\(plan.id)")
                                .accessibilityAddTraits(selectedProductID == plan.id ? .isSelected : [])
                            }

                            if let selectedPlan {
                                Button("Subscribe · \(selectedPlan.displayPrice) / \(selectedPlan.billingPeriod)") {
                                    Task { await manager.purchase(productID: selectedPlan.id) }
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .disabled(manager.isBusy)
                                .accessibilityIdentifier("premium.subscribeButton")
                            }
                            Text("Payment is charged to your Apple Account. Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your Apple Account subscription settings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if manager.isBusy { ProgressView().accessibilityLabel("Contacting the App Store") }
                    if let message = manager.status.message {
                        Text(message)
                            .accessibilityIdentifier("premium.status")
                    }

                    Button("Restore Purchases") { Task { await manager.restorePurchases() } }
                        .disabled(manager.isBusy)
                        .accessibilityIdentifier("premium.restoreButton")
                    Link("Manage Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    Button("Privacy") { isShowingPrivacy = true }
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Text("If Premium ends, existing active habits, goals and history remain usable. Free limits apply when adding items or reactivating archived habits.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("Avela Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("premium.closeButton")
                }
            }
            .sheet(isPresented: $isShowingPrivacy) {
                NavigationStack {
                    PrivacyView()
                    .navigationTitle("Privacy")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { isShowingPrivacy = false }
                        }
                    }
                }
            }
            .task {
                await manager.start()
                selectInitialPlan()
            }
            .onChange(of: manager.plans) { _, _ in selectInitialPlan() }
        }
    }

    private var selectedPlan: SubscriptionPlan? {
        manager.plans.first { $0.id == selectedProductID }
    }

    private func selectInitialPlan() {
        if selectedPlan == nil {
            selectedProductID = manager.plans.first?.id
        }
    }
}
