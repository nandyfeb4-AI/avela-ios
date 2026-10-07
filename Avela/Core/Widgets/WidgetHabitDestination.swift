import SwiftUI

/// Stable identity for a deep-linked detail presentation, independent of a
/// refreshing Today list. A body tap never records a completion.
struct WidgetHabitDestination: View {
    @State private var model: HabitDetailViewModel
    @Environment(\.dismiss) private var dismiss
    let onViewHistory: (UUID) -> Void
    init(habitID: UUID, repository: HabitRepository, onViewHistory: @escaping (UUID) -> Void) {
        self.onViewHistory = onViewHistory
        _model = State(initialValue: HabitDetailViewModel(habitID: habitID, repository: repository))
    }
    var body: some View {
        NavigationStack {
            HabitDetailView(viewModel: model, onViewHistory: onViewHistory)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
