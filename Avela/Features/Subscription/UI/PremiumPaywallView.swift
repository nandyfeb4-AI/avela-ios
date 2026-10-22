import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.appPalette) private var palette
    @Bindable var manager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?
    @State private var isShowingPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RilovaSectionHeader(
                        title: manager.hasPremium ? "You're using Rilova Premium" : "Room for more of what matters",
                        subtitle: "Free includes 3 active habits and 1 attention goal. Premium adds unlimited habits and attention goals.",
                        symbol: "sparkles")

                    VStack(alignment: .leading, spacing: 16) {
                        premiumBenefit("Unlimited habit tracking", symbol: "checkmark.circle")
                        premiumBenefit("Unlimited attention goals", symbol: "hourglass")
                        premiumBenefit("Your history always stays accessible", symbol: "clock.arrow.circlepath")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))

                    if !manager.hasPremium {
                        if manager.plans.isEmpty {
                            Text("Subscription options aren't available right now. You can keep using Rilova for free.")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("premium.productsUnavailable")
                            Button { Task { await manager.loadPlans() } } label: { Text("Try Again").frame(minHeight: 44) }
                                .disabled(manager.isBusy)
                        } else {
                            ForEach(manager.plans) { plan in
                                Button {
                                    selectedProductID = plan.id
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: selectedProductID == plan.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(palette.accent)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(plan.displayName).font(.headline)
                                            Text("\(plan.displayPrice) / \(plan.billingPeriod)")
                                                .foregroundStyle(Color.appInkSecondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44)
                                    .padding(16)
                                    .background(palette.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(selectedProductID == plan.id ? palette.accent : Color.clear, lineWidth: 2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.appInk)
                                .accessibilityIdentifier("premium.plan.\(plan.id)")
                                .accessibilityAddTraits(selectedProductID == plan.id ? .isSelected : [])
                            }

                            if let selectedPlan {
                                Button("Subscribe · \(selectedPlan.displayPrice) / \(selectedPlan.billingPeriod)") {
                                    Task { await manager.purchase(productID: selectedPlan.id) }
                                }
                                .foregroundStyle(palette.prominentInk)
                                .buttonStyle(.borderedProminent)
                                .tint(palette.prominentFill)
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

                    Button { Task { await manager.restorePurchases() } } label: { Text("Restore Purchases").frame(minHeight: 44) }
                        .disabled(manager.isBusy)
                        .accessibilityIdentifier("premium.restoreButton")
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) { Text("Manage Subscriptions").frame(minHeight: 44) }
                    Button { isShowingPrivacy = true } label: { Text("Privacy").frame(minHeight: 44) }
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) { Text("Terms of Use").frame(minHeight: 44) }
                    Text("If Premium ends, existing active habits, goals and history remain usable. Free limits apply when adding items or reactivating archived habits.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .appThemeCanvas()
            .navigationTitle("Rilova Premium")
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

    private func premiumBenefit(_ text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(palette.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text).font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectInitialPlan() {
        if selectedPlan == nil {
            selectedProductID = manager.plans.first?.id
        }
    }
}
