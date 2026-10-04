import SwiftUI

/// Read-only History screen: completions and skips from the last 30 local
/// calendar days, grouped by their stored day and optionally filtered to one
/// habit. No logging, editing, or deletion happens here — this view only
/// renders what `HistoryViewModel` hands it.
struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text(viewModel.rangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .accessibilityIdentifier("history.rangeLabel")

            if viewModel.sections.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(section.dateLabel) {
                            ForEach(section.rows) { row in
                                HistoryRowView(row: row)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Filter by Habit", selection: $viewModel.selectedHabitID) {
                    Text("All Activity").tag(UUID?.none)
                    ForEach(viewModel.habitOptions) { option in
                        Text(option.label).tag(Optional(option.id))
                    }
                }
                .accessibilityIdentifier("history.habitFilter")
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
        .onChange(of: viewModel.selectedHabitID) { _, _ in
            viewModel.load()
        }
        .task {
            viewModel.load()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text(viewModel.selectedHabitID == nil ? "No History Yet" : "No Records for This Habit")
                    .accessibilityIdentifier("history.emptyState.title")
            } icon: {
                Image(systemName: "clock")
            }
        } description: {
            Text(
                viewModel.selectedHabitID == nil
                    ? "Habit completions, skips and manually logged attention usage from the last 30 days will show up here."
                    : "No completions or skips for this habit in the last 30 days."
            )
        }
    }
}

private struct HistoryRowView: View {
    let row: HistoryRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.kindSymbolName)
                .font(.title3)
                .foregroundStyle(row.kindLabel == "Completed" ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: row.habitIconName)
                        .foregroundStyle(row.isHabitArchived ? Color.secondary : Color.accentColor)
                        .accessibilityHidden(true)
                    Text(row.habitName)
                    if row.isHabitArchived {
                        Text("Archived")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(row.kindLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var subtitle: String {
        guard let detailText = row.detailText, !detailText.isEmpty else { return row.scheduleContextLabel }
        guard !row.scheduleContextLabel.isEmpty else { return detailText }
        return "\(row.scheduleContextLabel) · \(detailText)"
    }

    private var accessibilityLabel: String {
        var components = [row.habitName, row.kindLabel]
        if let detailText = row.detailText, !detailText.isEmpty { components.append(detailText) }
        if row.isHabitArchived { components.append("archived habit") }
        return components.joined(separator: ", ")
    }
}

#Preview {
    let container = try! AppPersistence.makeContainer(inMemory: true)
    NavigationStack {
        HistoryView(viewModel: HistoryViewModel(repository: SwiftDataHabitRepository(modelContext: container.mainContext)))
    }
}
