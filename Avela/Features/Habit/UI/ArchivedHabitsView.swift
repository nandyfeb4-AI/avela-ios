import SwiftUI

/// Settings' Archived Habits list. Shows every archived habit with a way to
/// reactivate it; the view performs no persistence or business logic itself.
struct ArchivedHabitsView: View {
    @Environment(\.habitReminderService) private var reminderService
    @State private var viewModel: ArchivedHabitsViewModel
    var subscriptionManager: SubscriptionManager? = nil

    init(viewModel: ArchivedHabitsViewModel, subscriptionManager: SubscriptionManager? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.subscriptionManager = subscriptionManager
    }

    var body: some View {
        Group {
            if viewModel.rows.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Archived Habits")
                            .accessibilityIdentifier("archivedHabits.emptyState.title")
                    } icon: {
                        Image(systemName: "archivebox")
                    }
                } description: {
                    Text("Habits you archive keep their history here and can be reactivated anytime.")
                }
            } else {
                List(viewModel.rows) { row in
                    HStack(spacing: 12) {
                        HabitIconBadge(symbol: row.iconName, isArchived: true)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                            Text(row.scheduleLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reactivate") {
                            viewModel.reactivate(row)
                            Task { try? await reminderService?.synchronize() }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Reactivate \(row.name)")
                    }
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("Archived Habits")
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingPremium }, set: { viewModel.isShowingPremium = $0 }
        )) { if let subscriptionManager { PremiumPaywallView(manager: subscriptionManager) } }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            if let subscriptionManager {
                viewModel.activationAllowed = { subscriptionManager.canCreateHabit(activeCount: $0) }
            }
            viewModel.load()
        }
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    NavigationStack {
        ArchivedHabitsView(viewModel: ArchivedHabitsViewModel(repository: SwiftDataHabitRepository(modelContext: container.mainContext)))
    }
}
