import SwiftUI

/// Attention goal detail screen: today's status and entries, logging,
/// correcting, deleting, and editing the budget. All data comes from
/// `AttentionGoalDetailViewModel`; this view neither queries SwiftData nor
/// computes threshold math itself.
struct AttentionGoalDetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appPalette) private var palette
    @Bindable var viewModel: AttentionGoalDetailViewModel

    var body: some View {
        Group {
            if let display = viewModel.display {
                List {
                    Section {
                        budgetHero(display)
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }

                    Section("Today") {
                        Text(display.statusLabel)
                            .foregroundStyle(stateColor(display.state))
                            .accessibilityIdentifier("attentionGoalDetail.status")
                        Text("Logged manually. An unlogged day is unknown, not zero.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                        Button { viewModel.activeSheet = .logUsage } label: {
                            Label("Log Usage", systemImage: "plus")
                                .font(.headline).foregroundStyle(palette.prominentInk)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(palette.prominentFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(RilovaPressStyle())
                        .accessibilityIdentifier("attentionGoalDetail.logUsageButton")
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

                }
            } else {
                ProgressView()
            }
        }
        .appThemeCanvas()
        .navigationTitle(viewModel.display?.name ?? "Attention Goal")
        .navigationBarTitleDisplayMode(.inline)
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

    private func budgetHero(_ display: AttentionGoalDetailDisplay) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("YOUR DAILY BUDGET").font(.caption2.weight(.bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.85))
            Text(display.name).font(.system(.title, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("attentionGoalDetail.name")
            if let label = display.appOrCategoryLabel {
                Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            Text(display.targetLabel).font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("attentionGoalDetail.target")
            Label("Your time, reported by you", systemImage: "hand.tap")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background { RilovaAurora() }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
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
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(identifier)
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                Text(value).foregroundStyle(.secondary).accessibilityIdentifier(identifier)
            }
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
