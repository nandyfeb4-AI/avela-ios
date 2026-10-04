import SwiftUI

/// Attention goal detail screen: today's status and entries, logging,
/// correcting, deleting, and editing the budget. All data comes from
/// `AttentionGoalDetailViewModel`; this view neither queries SwiftData nor
/// computes threshold math itself.
struct AttentionGoalDetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: AttentionGoalDetailViewModel

    var body: some View {
        Group {
            if let display = viewModel.display {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(display.name)
                                .font(.title3)
                                .accessibilityIdentifier("attentionGoalDetail.name")
                            if let label = display.appOrCategoryLabel {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Today") {
                        detailRow("Budget", value: display.targetLabel, identifier: "attentionGoalDetail.target")
                        Text(display.statusLabel)
                            .foregroundStyle(stateColor(display.state))
                            .accessibilityIdentifier("attentionGoalDetail.status")
                    }

                    Section("Entries") {
                        if display.entries.isEmpty {
                            Text("No usage logged yet today.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(display.entries) { entry in
                                // A plain tap gesture, not a `Button`: a `Button`
                                // sharing a row with `.swipeActions` did not
                                // receive taps on this toolchain (confirmed by a
                                // UI test that waited for the correction sheet
                                // and never saw it appear, while the same row's
                                // swipe-to-delete worked) — `.swipeActions`
                                // appears to claim the row's own tap/pan gesture
                                // recognizers ahead of a nested `Button`.
                                HStack {
                                    Text(entry.amountLabel)
                                    Spacer()
                                    Text(entry.recordedAtLabel)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.activeSheet = .correct(entryID: entry.id)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint("Edit this usage entry")
                                .accessibilityAction {
                                    viewModel.activeSheet = .correct(entryID: entry.id)
                                }
                                .accessibilityIdentifier("attentionGoalDetail.entryRow.\(entry.id.uuidString)")
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteEntry(id: entry.id)
                                    }
                                    .accessibilityIdentifier("attentionGoalDetail.deleteEntryButton.\(entry.id.uuidString)")
                                }
                            }
                        }
                    }

                    Section {
                        Button("Log Usage") {
                            viewModel.activeSheet = .logUsage
                        }
                        .accessibilityIdentifier("attentionGoalDetail.logUsageButton")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel.display?.name ?? "Attention Goal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    viewModel.activeSheet = .edit
                }
                .accessibilityIdentifier("attentionGoalDetail.editButton")
            }
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .edit:
                AttentionGoalFormView(initialDraft: viewModel.draft) { updatedDraft in
                    viewModel.saveEdits(updatedDraft)
                }
            case .logUsage:
                AttentionUsageFormView(unit: viewModel.display?.targetUnit ?? .minutes) { amount in
                    viewModel.logUsage(amount: amount)
                }
            case .correct(let entryID):
                if let entry = viewModel.display?.entries.first(where: { $0.id == entryID }) {
                    AttentionUsageFormView(initialAmount: entry.amount, unit: viewModel.display?.targetUnit ?? .minutes) { amount in
                        viewModel.correctEntry(id: entryID, amount: amount)
                    }
                }
            }
        }
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
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in viewModel.load() }
        .task {
            viewModel.load()
        }
    }

    private func stateColor(_ state: AttentionProgressCalculator.ThresholdState?) -> Color {
        switch state {
        case .healthy: return .accentColor
        case .nearLimit: return .appRecovery
        case .exceeded: return .appOverBudget
        case nil: return .secondary
        }
    }

    private func detailRow(_ title: String, value: String, identifier: String = "") -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(identifier)
        }
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    let repository = SwiftDataAttentionRepository(modelContext: container.mainContext)
    let goal = try! repository.createGoal(
        AttentionGoalDraft(name: "Instagram", appOrCategoryLabel: "Social", type: .maxDurationPerDay, targetValue: 30, unit: .minutes),
        at: Date()
    )
    return NavigationStack {
        AttentionGoalDetailView(viewModel: AttentionGoalDetailViewModel(goalID: goal.id, repository: repository))
    }
}
