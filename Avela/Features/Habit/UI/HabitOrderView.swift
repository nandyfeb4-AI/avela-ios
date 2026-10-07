import SwiftUI

struct HabitOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var model: HabitOrderViewModel
    let onSaved: () -> Void

    init(repository: HabitRepository, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: HabitOrderViewModel(repository: repository))
        self.onSaved = onSaved
    }

    var body: some View {
        List {
            if let error = model.errorMessage {
                Section {
                    Text(error)
                    Button("Reload Habits", action: model.load)
                        .accessibilityIdentifier("habitOrder.reload")
                }
            }
            Section {
                ForEach(Array(model.habits.enumerated()), id: \.element.id) { index, habit in
                    orderRow(habit, index: index)
                }
                .onMove(perform: model.move)
                .moveDisabled(model.needsReload || !model.isLoaded)
            } header: {
                Text("Active Habits")
            } footer: {
                Text("Drag the handles or use Move Up and Move Down. This order applies to Today, including habits scheduled for other days. Completed habits still move into Done.")
            }
            if model.isLoaded && model.habits.isEmpty {
                ContentUnavailableView("No Active Habits", systemImage: "list.bullet", description: Text("Create a habit from Today to start arranging your list."))
            }
        }
        .environment(\.editMode, .constant(.active))
        .appThemeCanvas()
        .navigationTitle("Habit Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("habitOrder.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if model.save() { onSaved(); dismiss() }
                }
                .disabled(!model.canSave)
                .accessibilityIdentifier("habitOrder.save")
            }
        }
        .task { if !model.isLoaded { model.load() } }
    }

    private func orderRow(_ habit: Habit, index: Int) -> some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: habit.iconName)
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name).font(.body.weight(.semibold))
                        .accessibilityIdentifier("habitOrder.name.\(habit.id)")
                    Text("\(index + 1) of \(model.habits.count) · \(HabitScheduleFormatter.description(for: habit.schedule))")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("habitOrder.position.\(habit.id)")
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                moveButton(habit, up: true, disabled: index == 0)
                moveButton(habit, up: false, disabled: index == model.habits.count - 1)
            }
        }
        .accessibilityAction(named: "Move Up") { model.move(habit.id, up: true) }
        .accessibilityAction(named: "Move Down") { model.move(habit.id, up: false) }
    }

    private func moveButton(_ habit: Habit, up: Bool, disabled: Bool) -> some View {
        Button { model.move(habit.id, up: up) } label: {
            Image(systemName: up ? "chevron.up" : "chevron.down")
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .disabled(disabled || model.needsReload || !model.isLoaded)
        .accessibilityLabel("Move \(habit.name) \(up ? "up" : "down")")
        .accessibilityIdentifier("habitOrder.\(up ? "up" : "down").\(habit.id)")
    }
}
