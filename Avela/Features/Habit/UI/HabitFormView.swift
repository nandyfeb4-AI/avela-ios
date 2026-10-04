import SwiftUI

/// Habit creation and editing form. Emits a finished `HabitDraft` via `onSave`;
/// it has no repository access of its own and performs no persistence or
/// scheduling logic — only input collection and lightweight presentation
/// validation (non-empty name, non-empty weekday selection). Passing
/// `initialDraft` switches the form into edit mode (pre-filled fields, "Edit
/// Habit" title) without changing any other behavior — the caller decides
/// whether `onSave` means create or update.
struct HabitFormView: View {
    let initialDraft: HabitDraft?
    let onSave: (HabitDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconName: String
    @State private var category: HabitCategory
    @State private var polarity: HabitPolarity
    @State private var scheduleKind: ScheduleKind
    @State private var selectedWeekdays: Set<Weekday>
    @State private var timesPerWeek: Int

    init(initialDraft: HabitDraft? = nil, onSave: @escaping (HabitDraft) -> Void) {
        self.initialDraft = initialDraft
        self.onSave = onSave
        _name = State(initialValue: initialDraft?.name ?? "")
        _category = State(initialValue: initialDraft?.category ?? .other)
        _polarity = State(initialValue: initialDraft?.polarity ?? .positive)
        _iconName = State(initialValue: initialDraft?.iconName ?? Self.iconChoices(
            for: initialDraft?.category ?? .other, polarity: initialDraft?.polarity ?? .positive
        ).first ?? "star.fill")

        switch initialDraft?.schedule {
        case .none, .some(.daily):
            _scheduleKind = State(initialValue: .daily)
        case .some(.weekdays):
            _scheduleKind = State(initialValue: .weekdays)
        case .some(.timesPerWeek):
            _scheduleKind = State(initialValue: .timesPerWeek)
        }
        if case .some(.weekdays(let days)) = initialDraft?.schedule {
            _selectedWeekdays = State(initialValue: days)
        } else {
            _selectedWeekdays = State(initialValue: [])
        }
        if case .some(.timesPerWeek(let count)) = initialDraft?.schedule {
            _timesPerWeek = State(initialValue: count)
        } else {
            _timesPerWeek = State(initialValue: 3)
        }
    }

    private var isEditing: Bool { initialDraft != nil }

    private enum ScheduleKind: String, CaseIterable, Identifiable {
        case daily, weekdays, timesPerWeek
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: "Daily"
            case .weekdays: "Selected Days"
            case .timesPerWeek: "Times per Week"
            }
        }
    }

    /// Curated per `HabitCategory`, from `design/exploration/ICON_SYSTEM.md`
    /// §2 ("Habit identity") — grouped so a category's icons stay
    /// recognizable at a glance, rather than one flat, uncategorized list.
    /// "other" has no entry in that table; it gets a small general-purpose
    /// set here, including "book.fill" so an unmodified default selection
    /// still shows a familiar icon. Avoidance habits additionally offer
    /// ICON_SYSTEM's cross-cutting "(any category)" symbols, since a Cut
    /// Down habit's natural icon (e.g. a crossed-out phone) often has
    /// nothing to do with its category.
    private static func iconChoices(for category: HabitCategory, polarity: HabitPolarity) -> [String] {
        var icons = categoryIconChoices(category)
        if polarity == .avoidance {
            icons += ["iphone.slash", "nosign", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill"]
        }
        return icons
    }

    private static func categoryIconChoices(_ category: HabitCategory) -> [String] {
        switch category {
        case .health:
            return ["drop.fill", "pills.fill", "fork.knife", "bed.double.fill", "heart.fill"]
        case .fitness:
            return ["figure.walk", "figure.run", "dumbbell.fill", "figure.yoga", "bicycle"]
        case .learning:
            return ["book.fill", "graduationcap.fill", "character.book.closed.fill", "music.note"]
        case .mindfulness:
            return ["leaf.fill", "moon.stars.fill", "pencil.line", "sparkles", "wind"]
        case .productivity:
            return ["checklist", "laptopcomputer", "tray.full.fill", "timer"]
        case .social:
            return ["person.2.fill", "phone.fill", "envelope.fill"]
        case .finance:
            return ["banknote.fill", "chart.pie.fill", "cart.fill"]
        case .other:
            return ["book.fill", "star.fill", "tag.fill", "circle.grid.2x2.fill", "checkmark.circle.fill"]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Habit name", text: $name)
                        .accessibilityIdentifier("habitForm.nameField")
                }

                Section("Icon") {
                    // `.adaptive(minimum:)` recomputes how many columns fit
                    // the available width, rather than a fixed 6-column grid
                    // whose cells would otherwise have to shrink below the
                    // 44×44pt minimum touch target to keep fitting — this
                    // also means the grid naturally reflows to fewer, larger
                    // columns as Dynamic Type grows the icons themselves.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 64), spacing: 12)], spacing: 12) {
                        ForEach(Self.iconChoices(for: category, polarity: polarity), id: \.self) { candidate in
                            Button {
                                iconName = candidate
                            } label: {
                                Image(systemName: candidate)
                                    .font(.title2)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .background(candidate == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Icon \(candidate)")
                            .accessibilityAddTraits(candidate == iconName ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                }

                Section("Type") {
                    Picker("Polarity", selection: $polarity) {
                        Text("Build Up").tag(HabitPolarity.positive)
                        Text("Cut Down").tag(HabitPolarity.avoidance)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("habitForm.polarityPicker")
                }

                Section("Schedule") {
                    Picker("Schedule", selection: $scheduleKind) {
                        ForEach(ScheduleKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("habitForm.scheduleTypePicker")

                    switch scheduleKind {
                    case .daily:
                        EmptyView()
                    case .weekdays:
                        weekdaySelector
                    case .timesPerWeek:
                        Stepper("\(timesPerWeek) times per week", value: $timesPerWeek, in: 1...7)
                            .accessibilityIdentifier("habitForm.timesPerWeekStepper")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            // Compact, centered title — not the default large-title style —
            // matching the standard iOS convention for quick-entry modal
            // sheets (Reminders' "New List", Mail's "New Message"), rather
            // than reading like a pushed, deep navigation destination.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("habitForm.cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("habitForm.saveButton")
                }
            }
        }
    }

    private var weekdaySelector: some View {
        HStack {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                let isSelected = selectedWeekdays.contains(weekday)
                Button {
                    if isSelected {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                } label: {
                    Text(Self.shortLabel(for: weekday))
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("habitForm.weekday.\(weekday.rawValue)")
                .accessibilityLabel(Self.fullLabel(for: weekday))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if scheduleKind == .weekdays && selectedWeekdays.isEmpty { return false }
        return true
    }

    private func save() {
        let schedule: HabitSchedule
        switch scheduleKind {
        case .daily: schedule = .daily
        case .weekdays: schedule = .weekdays(selectedWeekdays)
        case .timesPerWeek: schedule = .timesPerWeek(timesPerWeek)
        }
        let draft = HabitDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: iconName,
            category: category,
            polarity: polarity,
            schedule: schedule
        )
        onSave(draft)
    }

    private static func shortLabel(for weekday: Weekday) -> String {
        let symbols = Calendar(identifier: .gregorian).veryShortWeekdaySymbols
        return symbols[weekday.rawValue - 1]
    }

    private static func fullLabel(for weekday: Weekday) -> String {
        let symbols = Calendar(identifier: .gregorian).weekdaySymbols
        return symbols[weekday.rawValue - 1]
    }
}

#Preview("Create") {
    HabitFormView { _ in }
}

#Preview("Edit") {
    HabitFormView(initialDraft: HabitDraft(
        name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .timesPerWeek(3)
    )) { _ in }
}
