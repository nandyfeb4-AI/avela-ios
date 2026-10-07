import SwiftUI

/// Optional support, kept inside existing habit/recovery navigation.
struct HabitRecoveryChoiceView: View {
    @State private var model: HabitRecoveryChoiceViewModel
    @State private var confirmingPause = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.habitReminderService) private var reminders
    private let onLogSmallerAction: () -> Void
    private let onChanged: () -> Void

    init(habitID: UUID, habits: any HabitRepository, activities: any HabitActivityRepository,
         onLogSmallerAction: @escaping () -> Void, onChanged: @escaping () -> Void = {}) {
        _model = State(initialValue: HabitRecoveryChoiceViewModel(habitID: habitID, habits: habits, activities: activities))
        self.onLogSmallerAction = onLogSmallerAction
        self.onChanged = onChanged
    }

    var body: some View {
        List {
            if let suggestion = model.suggestion {
                Section {
                    Text(model.habitName).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(suggestion.reason).foregroundStyle(.secondary)
                    Text("Choose what fits today. Nothing changes unless you choose and confirm it.")
                        .foregroundStyle(.secondary)
                }
                if let action = suggestion.smallerAction {
                    Section {
                        Text(action).font(.headline)
                        Button("Open Smaller-Action Check-In") {
                            if model.canOpenSmallerAction() {
                                dismiss()
                                onLogSmallerAction()
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("recoveryChoice.smallerAction")
                    } header: { Text("Your Smaller Version") } footer: {
                        Text("This is the smaller action you configured. Opening the logger does not save anything. Smaller effort stays separate from full success.")
                    }
                }
                Section {
                    Button("Pause \(model.habitName)") { confirmingPause = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("recoveryChoice.pause")
                } header: { Text("Take a Break") } footer: {
                    Text("A pause keeps your history. Paused time adds no misses or successes. Reactivate from Settings → Archived Habits whenever you’re ready; there is no automatic resume date.")
                }
            } else {
                ContentUnavailableView("No Change Needed", systemImage: "leaf",
                    description: Text("This option appears only after repeated resolved misses on the current schedule. You can always use your normal check-in or habit support tools."))
                Button("Reload") { model.load() }.frame(minHeight: 44)
            }
        }
        .appThemeCanvas()
        .navigationTitle("A Smaller Step")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .task { model.load() }
        .alert("Pause \(model.habitName)?", isPresented: $confirmingPause) {
            Button("Pause Habit") {
                if model.pause() {
                    onChanged()
                    Task { try? await reminders?.synchronize() }
                    dismiss()
                }
            }
            Button("Keep Habit", role: .cancel) {}
        } message: {
            Text("Earlier progress stays. Paused time adds no misses or successes. There is no automatic resume date; reactivate from Settings → Archived Habits.")
        }
        .alert("Review Changed", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.clearError() } })) {
            Button("OK", role: .cancel) { model.clearError() }
        } message: { Text(model.errorMessage ?? "") }
    }
}
