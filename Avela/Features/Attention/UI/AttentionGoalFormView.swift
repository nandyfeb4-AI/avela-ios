import SwiftUI

/// Attention goal creation and editing form. Emits a finished
/// `AttentionGoalDraft` via `onSave`; it has no repository access of its own
/// and performs no persistence or threshold logic — only input collection and
/// lightweight presentation validation (non-empty name, positive target).
/// Passing `initialDraft` switches the form into edit mode, mirroring
/// `HabitFormView`.
struct AttentionGoalFormView: View {
    let initialDraft: AttentionGoalDraft?
    let onSave: (AttentionGoalDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var appOrCategoryLabel: String
    @State private var targetMinutesText: String
    @State private var goalType: AttentionGoalType
    @State private var windowStart: Date
    @State private var windowEnd: Date

    init(initialDraft: AttentionGoalDraft? = nil, onSave: @escaping (AttentionGoalDraft) -> Void) {
        self.initialDraft = initialDraft
        self.onSave = onSave
        _goalType = State(initialValue: initialDraft?.type ?? .maxDurationPerDay)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        _windowStart = State(initialValue: calendar.date(byAdding: .minute, value: initialDraft?.windowStartMinute ?? 0, to: today) ?? today)
        _windowEnd = State(initialValue: calendar.date(byAdding: .minute, value: initialDraft?.windowEndMinute ?? 540, to: today) ?? today)
        _name = State(initialValue: initialDraft?.name ?? "")
        _appOrCategoryLabel = State(initialValue: initialDraft?.appOrCategoryLabel ?? "")
        _targetMinutesText = State(initialValue: initialDraft.map { Self.format($0.targetValue) } ?? "30")
    }

    private var isEditing: Bool { initialDraft != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Goal name", text: $name)
                        .accessibilityIdentifier("attentionGoalForm.nameField")
                }

                Section("App or Category") {
                    TextField("Optional", text: $appOrCategoryLabel)
                        .accessibilityIdentifier("attentionGoalForm.categoryLabelField")
                }

                if !isEditing {
                    Section("Goal Type") {
                        Picker("Type", selection: $goalType) {
                            Text("Daily budget").tag(AttentionGoalType.maxDurationPerDay)
                            Text("Protected window").tag(AttentionGoalType.noUseBeforeTime)
                            Text("Phone-free window").tag(AttentionGoalType.phoneFreeUntilTime)
                            Text("Phone-free session").tag(AttentionGoalType.phoneFreeSession)
                        }
                        .accessibilityIdentifier("attentionGoalForm.typePicker")
                    }
                }
                if goalType == .noUseBeforeTime || goalType == .phoneFreeUntilTime {
                    Section {
                        DatePicker("Start", selection: $windowStart, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $windowEnd, displayedComponents: .hourAndMinute)
                    } header: { Text("Protected Window") } footer: {
                        Text("Times follow your local clock. An end before the start continues overnight. You report whether you kept the window; Avela does not monitor phone use.")
                    }
                } else {
                    Section {
                    HStack {
                        TextField("Minutes", text: $targetMinutesText)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("attentionGoalForm.targetField")
                        Text(goalType == .phoneFreeSession ? "min/session" : "min/day")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(goalType == .phoneFreeSession ? "Session Duration" : "Daily Budget")
                } footer: {
                    Text("Choose a duration greater than 0 and no more than 1,440 minutes (24 hours).")
                }
                }
            }
            .navigationTitle(isEditing ? "Edit Attention Goal" : "New Attention Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("attentionGoalForm.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("attentionGoalForm.saveButton")
                }
            }
        }
    }

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if goalType == .noUseBeforeTime || goalType == .phoneFreeUntilTime {
            return minute(windowStart) != minute(windowEnd)
        }
        guard let value = Double(targetMinutesText), value.isFinite, value > 0, value <= 1440 else { return false }
        return true
    }

    private func save() {
        guard isValid else { return }
        let value = goalType == .noUseBeforeTime || goalType == .phoneFreeUntilTime ? 30 : (Double(targetMinutesText) ?? 30)
        let trimmedLabel = appOrCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = AttentionGoalDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            appOrCategoryLabel: trimmedLabel.isEmpty ? nil : trimmedLabel,
            type: goalType,
            targetValue: value,
            unit: .minutes,
            windowStartMinute: goalType == .noUseBeforeTime || goalType == .phoneFreeUntilTime ? minute(windowStart) : nil,
            windowEndMinute: goalType == .noUseBeforeTime || goalType == .phoneFreeUntilTime ? minute(windowEnd) : nil
        )
        onSave(draft)
    }

    private func minute(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func format(_ value: Double) -> String {
        value.isFinite ? (value.rounded() == value ? String(format: "%.0f", value) : String(value)) : ""
    }
}

#Preview("Create") {
    AttentionGoalFormView { _ in }
}

#Preview("Edit") {
    AttentionGoalFormView(initialDraft: AttentionGoalDraft(
        name: "Instagram", appOrCategoryLabel: "Social", type: .maxDurationPerDay, targetValue: 30, unit: .minutes
    )) { _ in }
}
