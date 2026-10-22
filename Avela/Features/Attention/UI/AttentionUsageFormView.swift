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
    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    RilovaSectionHeader(title: isEditing ? "Keep your record accurate" : "A little awareness, simply logged",
                        subtitle: isEditing ? "Replace this entry's amount. Your other entries stay the same." : "Enter the minutes you want to add to today's manual record.",
                        symbol: "hourglass")
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    TextField("Amount", text: $amountText)
                        .font(.system(.title2, design: .rounded, weight: .medium)).monospacedDigit()
                        .frame(minHeight: 44)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("attentionUsageForm.amountField")
                    if !isEditing {
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                            : AnyLayout(HStackLayout(spacing: 10))
                        layout {
                            ForEach([5, 15, 30], id: \.self) { amount in
                                Button { amountText = String(amount) } label: {
                                    Text("\(amount) min").font(.subheadline.weight(.semibold))
                                        .foregroundStyle(palette.accent)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 15))
                                }
                                .buttonStyle(RilovaPressStyle())
                                .accessibilityLabel("Set amount to \(amount) minutes")
                                .accessibilityIdentifier("attentionUsageForm.preset.\(amount)")
                            }
                        }
                        Text("Choose an amount, then Save to add it.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    }
                } header: { Text(unitSectionTitle) } footer: {
                    Text("Enter 0–1,440 minutes. Logging 0 explicitly reports no usage; leaving a day unlogged means unknown.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
