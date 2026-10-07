import SwiftUI

/// Manual usage logging/correction form. Reused for both logging a brand-new
/// entry (`initialAmount == nil`) and correcting an existing one
/// (`initialAmount` set) — the caller decides which `onSave` means, mirroring
/// `HabitFormView`'s create/edit reuse.
struct AttentionUsageFormView: View {
    let initialAmount: Double?
    let unit: AttentionUnit
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    init(initialAmount: Double? = nil, unit: AttentionUnit, onSave: @escaping (Double) -> Void) {
        self.initialAmount = initialAmount
        self.unit = unit
        self.onSave = onSave
        _amountText = State(initialValue: initialAmount.map { Self.format($0) } ?? "")
    }

    private var isEditing: Bool { initialAmount != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("attentionUsageForm.amountField")
                } header: { Text(unitSectionTitle) } footer: {
                    Text("Enter 0–1,440 minutes. Logging 0 explicitly reports no usage; leaving a day unlogged means unknown.")
                }
            }
            .appThemeCanvas()
        .navigationTitle(isEditing ? "Correct Usage" : "Log Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("attentionUsageForm.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("attentionUsageForm.saveButton")
                }
            }
        }
    }

    private var unitSectionTitle: String {
        switch unit {
        case .minutes:
            return "Minutes"
        }
    }

    private var isValid: Bool {
        guard let value = Double(amountText) else { return false }
        return value.isFinite && value >= 0 && value <= 1440
    }

    private func save() {
        guard isValid else { return }
        guard let value = Double(amountText) else { return }
        onSave(value)
    }

    private static func format(_ value: Double) -> String {
        value.isFinite ? (value.rounded() == value ? String(format: "%.0f", value) : String(value)) : ""
    }
}

#Preview("Log") {
    AttentionUsageFormView(unit: .minutes) { _ in }
}

#Preview("Correct") {
    AttentionUsageFormView(initialAmount: 15, unit: .minutes) { _ in }
}
