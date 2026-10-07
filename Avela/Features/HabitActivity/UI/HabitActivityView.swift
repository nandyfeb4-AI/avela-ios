import SwiftUI

struct HabitActivityView: View {
    @State private var model: HabitActivityViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @State private var reviewedDate = Date()
    @State private var pendingKind: HabitActivityKind?
    @State private var pendingCorrection: HabitDayCorrection?
    @State private var pendingDeletion: HabitActivityEntry?
    private let prioritizesSmallerAction: Bool
    init(habitID: UUID, repository: HabitActivityRepository, habits: HabitRepository, prioritizesSmallerAction: Bool = false) {
        self.prioritizesSmallerAction = prioritizesSmallerAction
        _model = State(initialValue: HabitActivityViewModel(habitID: habitID, repository: repository, habits: habits))
    }
    var body: some View {
        NavigationStack {
            Form {
                if let habit = model.habit {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: habit.iconName)
                                .font(.title3.weight(.semibold)).foregroundStyle(palette.accent)
                                .frame(width: 44, height: 44)
                                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityHidden(true)
                            Text(habit.name).font(.title3.weight(.semibold))
                        }.padding(.vertical, 4)
                        DatePicker("Tracking day", selection: $model.selectedDate,
                            in: min(habit.createdAt, Date())...Date(), displayedComponents: .date)
                            .accessibilityIdentifier("activity.date")
                    }
                }
                if prioritizesSmallerAction { smallerActionSection }
                if model.isToday && model.configuration?.target == nil {
                    Section("Today's check-in") {
                        Button("Log success today") { model.correct(to: .success) }.accessibilityIdentifier("activity.logSuccess")
                    }
                }
                if let target = model.configuration?.target {
                    Section("Daily Progress") {
                        Text(model.progressLabel).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit().accessibilityIdentifier("activity.progress")
                        ProgressView(value: Double(min(model.total, target.amount)), total: Double(target.amount))
                            .tint(palette.accent).accessibilityLabel(model.progressLabel)
                        if model.isToday {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))]) {
                                ForEach(model.quickAmounts, id: \.self) { increment in
                                    Button("+\(increment) \(target.unit.name(for: increment))") { model.logPreset(increment) }
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(palette.accent)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel("Add \(increment) \(target.unit.name(for: increment)) today")
                                        .accessibilityIdentifier("activity.quickPreset.\(increment)")
                                }
                            }
                            Button("Edit quick amounts") { model.preparePresets() }
                                .frame(minHeight: 44).accessibilityIdentifier("activity.editPresets")
                            if let entry = model.lastQuickEntry {
                                Button("Undo +\(entry.amount) \(entry.unit?.name(for: entry.amount) ?? "units")") { model.undoQuickLog() }
                                    .frame(minHeight: 44).accessibilityIdentifier("activity.undoQuickPreset")
                            }
                        }
                        Stepper("Add \(model.amount) \(target.unit.name(for: model.amount))", value: $model.amount, in: 1...10_000)
                        Button("Log \(model.amount) \(target.unit.name(for: model.amount))") { requestLog(.quantity) }
                            .accessibilityIdentifier("activity.logQuantity")
                        Text("Entries add up for the day. Reaching your target logs success; removing progress below it withdraws that success.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if target.unit == .minutes && model.isToday { timerSection }
                }
                if !prioritizesSmallerAction { smallerActionSection }
                if !model.entries.isEmpty {
                    Section("Recorded on this day") {
                        ForEach(model.entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.kind == .smallerAction ? "Smaller action · \(entry.description)" : "\(entry.amount) \(entry.unit?.name(for: entry.amount) ?? "units")")
                                Button("Remove entry", role: .destructive) { pendingDeletion = entry }
                                    .accessibilityLabel("Remove \(entry.kind == .quantity ? "\(entry.amount) \(entry.unit?.name(for: entry.amount) ?? "units")" : "smaller action") entry")
                            }.padding(.vertical, 4)
                        }
                    }
                }
                Section("Correct a check-in") {
                    Text("Changes require confirmation and may update streaks and Insights. Quantities and smaller actions stay separate.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Record full success") { reviewedDate = model.selectedDate; pendingCorrection = .success }.accessibilityIdentifier("activity.correctSuccess")
                    Button("Record excused skip") { reviewedDate = model.selectedDate; pendingCorrection = .skip }
                    Button("Clear success or skip", role: .destructive) { reviewedDate = model.selectedDate; pendingCorrection = .clear }
                }
                if !model.confirmation.isEmpty { Section { Text(model.confirmation).accessibilityIdentifier("activity.confirmation") } }
            }
            .appThemeCanvas().navigationTitle("Progress & History").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Configure") { model.prepareConfiguration() }.accessibilityIdentifier("activity.configure")
                }
            }
            .sheet(isPresented: $model.isShowingConfiguration) { configurationForm }
            .sheet(isPresented: $model.isShowingPresets) { presetsForm }
            .alert("Save to \(reviewedDate.formatted(date: .abbreviated, time: .omitted))?", isPresented: Binding(get: { pendingKind != nil }, set: { if !$0 { pendingKind = nil } })) {
                Button("Save") { if let kind = pendingKind { model.log(kind, reviewedDate: reviewedDate) }; pendingKind = nil }
                Button("Cancel", role: .cancel) { pendingKind = nil }
            } message: { Text("This is a backdated entry and may update historical progress.") }
            .alert("Update \(reviewedDate.formatted(date: .abbreviated, time: .omitted))?", isPresented: Binding(get: { pendingCorrection != nil }, set: { if !$0 { pendingCorrection = nil } })) {
                Button("Confirm change") { if let outcome = pendingCorrection { model.correct(to: outcome, reviewedDate: reviewedDate) }; pendingCorrection = nil }
                Button("Cancel", role: .cancel) { pendingCorrection = nil }
            } message: { Text("This replaces success/skip check-ins on the selected day. Your original schedule and quantity entries are kept. Metrics may change.") }
            .alert("Remove this entry?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
                Button("Remove", role: .destructive) { if let entry = pendingDeletion { model.remove(entry) }; pendingDeletion = nil }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { Text("Removing quantity progress can withdraw the day's quantity-generated success.") }
            .alert("Unable to Save", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.clearError() } })) {
                Button("Reload") { model.clearError(); model.load() }
                Button("OK", role: .cancel) { model.clearError() }
            } message: { Text(model.errorMessage ?? "") }
            .onChange(of: model.selectedDate) { _, _ in model.load() }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in model.selectedDate = Date(); model.load() }
            .task { model.load() }
        }
    }
    @ViewBuilder
    private var smallerActionSection: some View {
                if model.hasSmallerAction {
                    Section("A smaller action") {
                        Text(model.configuration?.smallerAction ?? "")
                        Button("I did the smaller action") { requestLog(.smallerAction) }
                            .disabled(model.entries.contains { $0.kind == .smallerAction })
                            .accessibilityIdentifier("activity.logSmaller")
                        Text("A separate check-in for effort. It doesn’t complete the full habit or extend a streak.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
    }
    private func requestLog(_ kind: HabitActivityKind) {
        if model.isToday { model.log(kind) } else { reviewedDate = model.selectedDate; pendingKind = kind }
    }
    private var timerSection: some View {
        Section("Activity Timer") {
            TimelineView(.periodic(from: Date(), by: 1)) { clock in
                let seconds = model.timer?.seconds(at: clock.date) ?? 0
                Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
                    .font(.largeTitle.monospacedDigit()).accessibilityLabel("\(seconds / 60) minutes, \(seconds % 60) seconds")
            }
            Button(model.timer?.startedAt == nil ? "Start timer" : "Pause timer") { model.toggleTimer() }
                .accessibilityIdentifier("activity.timerToggle")
            Button("Log whole minutes") { model.logTimer() }
                .disabled(model.timer?.startedAt != nil || (model.timer?.elapsedSeconds ?? 0) < 60)
            Button("Reset timer", role: .destructive) { model.resetTimer() }
            Text("Elapsed time, not verified activity. Pause, then log whole minutes. Leaving the app never records success.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var presetsForm: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<3, id: \.self) { index in
                        TextField("Amount \(index + 1)", text: $model.presetDraft[index])
                            .keyboardType(.numberPad).frame(minHeight: 44)
                            .accessibilityIdentifier("activity.presetAmount.\(index)")
                    }
                } header: { Text("Your quick amounts") }
                footer: { Text("Choose 1–3 different whole amounts (1–10,000). Leave unused fields blank. Only this habit’s quick buttons change; your target and history stay the same.") }
                if let error = model.presetError { Section { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("activity.presetError") } }
            }
            .appThemeCanvas().navigationTitle("Quick Amounts").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.cancelPresets() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model.savePresets() }.accessibilityIdentifier("activity.savePresets")
                }
            }
        }
    }
    private var configurationForm: some View {
        NavigationStack {
            Form {
                Section("Full target") {
                    Toggle("Track a quantity", isOn: $model.quantityEnabled).accessibilityIdentifier("activity.quantityEnabled")
                    if model.quantityEnabled {
                        if dynamicTypeSize.isAccessibilitySize {
                            Picker("Unit", selection: $model.unit) { ForEach(HabitQuantityUnit.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.inline)
                        } else {
                            Picker("Unit", selection: $model.unit) { ForEach(HabitQuantityUnit.allCases, id: \.self) { Text($0.label).tag($0) } }
                        }
                        Stepper("\(model.targetAmount) \(model.unit.name(for: model.targetAmount))", value: $model.targetAmount, in: 1...10_000)
                    }
                    Text("For Build Up habits without a Health target. Weekly schedules count successful days.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Smaller action (optional)") {
                    TextField("For example, read one page", text: $model.smallerAction, axis: .vertical)
                        .accessibilityIdentifier("activity.smallerAction")
                    Text("Up to 160 characters. A separate effort check-in, not a change to your target.").font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text("Changes apply from today. Earlier targets and recorded progress are kept.").font(.footnote) }
                if let error = model.errorMessage { Section { Text(error).foregroundStyle(.secondary) } }
            }.appThemeCanvas().navigationTitle("Progress Setup").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.isShowingConfiguration = false; model.clearError() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { model.saveConfiguration() }.accessibilityIdentifier("activity.saveConfiguration") }
                }
        }
    }
}

private struct HabitActivityRepositoryKey: EnvironmentKey { static let defaultValue: HabitActivityRepository? = nil }
extension EnvironmentValues {
    var habitActivityRepository: HabitActivityRepository? {
        get { self[HabitActivityRepositoryKey.self] }
        set { self[HabitActivityRepositoryKey.self] = newValue }
    }
}
