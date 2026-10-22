import SwiftUI

/// Read-only History screen: completions and skips from the last 30 local
/// calendar days, grouped by their stored day and optionally filtered to one
/// habit. No logging, editing, or deletion happens here — this view only
/// renders what `HistoryViewModel` hands it.
struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your story, recorded.")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(viewModel.rangeLabel).font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityIdentifier("history.rangeLabel")
                }
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "clock.arrow.circlepath").font(.title2.weight(.light))
                        .foregroundStyle(palette.luminousHighlight).accessibilityHidden(true)
                }
            }
            .foregroundStyle(.white).padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { RilovaAurora() }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)

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
        .appThemeCanvas()
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
    @Environment(\.appPalette) private var palette
    let row: HistoryRow

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            HabitIconBadge(symbol: row.habitIconName, isArchived: row.isHabitArchived)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(row.habitName).font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(row.kindLabel, systemImage: row.kindSymbolName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(row.kindLabel == "Completed" ? palette.accent : Color.secondary)
                if row.isHabitArchived {
                    Text("Archived").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
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
