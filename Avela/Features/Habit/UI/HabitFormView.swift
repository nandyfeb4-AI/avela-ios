import SwiftUI

/// Habit creation and editing form. Emits a finished `HabitDraft` via `onSave`;
/// it has no repository access of its own and performs no persistence or
/// scheduling logic — only input collection and lightweight presentation
/// validation (non-empty name, non-empty weekday selection). Passing
/// `initialDraft` switches the form into edit mode (pre-filled fields, "Edit
/// Habit" title) without changing any other behavior — the caller decides
/// whether `onSave` means create or update.
struct HabitFormView: View {
    @Environment(\.appPalette) private var palette
    let initialDraft: HabitDraft?
    let onSave: (HabitDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var whyItMatters: String
    @State private var isWhyMemoryHidden: Bool
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
        _whyItMatters = State(initialValue: initialDraft?.whyItMatters ?? "")
        _isWhyMemoryHidden = State(initialValue: initialDraft?.isWhyMemoryHidden ?? false)
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
                if !isEditing {
                    Section {
                        NavigationLink {
                            HabitStarterLibraryView { applyStarter($0) }
                        } label: {
                            Label("Browse Habit Ideas", systemImage: "sparkles")
                        }
                        .accessibilityIdentifier("habitForm.ideasLink")
                    } footer: {
                        Text("Start with an editable idea, or create your own below.")
                    }
                }
                Section("Name") {
                    TextField("Habit name", text: $name)
                        .accessibilityIdentifier("habitForm.nameField")
                }

                Section {
                    TextField("A sentence for your future self", text: $whyItMatters, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("habitForm.whyMemory")
                    Text("\(whyItMatters.count) / 240 characters")
                        .font(.caption).foregroundStyle(.secondary)
                    if !whyItMatters.isEmpty {
                        Toggle("Show when I need a reminder", isOn: Binding(
                            get: { !isWhyMemoryHidden }, set: { isWhyMemoryHidden = !$0 }))
                            .accessibilityIdentifier("habitForm.showWhyMemory")
                    }
                } header: { Text("Why this matters · optional") }
                  footer: { Text("A private reason, shown during recovery or before Make Room. Stored on this device; excluded from Avela’s iCloud recovery copies. You can hide or remove it anytime.") }

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
                                HabitIconBadge(symbol: candidate)
                                    .overlay {
                                        if candidate == iconName {
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(palette.accent, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("Icon \(candidate)")
                            .accessibilityLabel(Self.iconLabel(candidate))
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
                    .modifier(AdaptiveHabitPickerStyle())
                    .accessibilityIdentifier("habitForm.polarityPicker")
                }

                Section("Schedule") {
                    Picker("Schedule", selection: $scheduleKind) {
                        ForEach(ScheduleKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .modifier(AdaptiveHabitPickerStyle())
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
            .scrollDismissesKeyboard(.interactively)
            .appThemeCanvas()
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 140 : 44), spacing: 8)], spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                let isSelected = selectedWeekdays.contains(weekday)
                Button {
                    if isSelected {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                } label: {
                    Text(dynamicTypeSize.isAccessibilitySize ? Self.fullLabel(for: weekday) : Self.shortLabel(for: weekday))
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isSelected ? palette.accent.opacity(0.25) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("habitForm.weekday.\(weekday.rawValue)")
                .accessibilityLabel(Self.fullLabel(for: weekday))
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func applyStarter(_ draft: HabitDraft) {
        name = draft.name
        iconName = draft.iconName
        category = draft.category
        polarity = draft.polarity
        switch draft.schedule {
        case .daily: scheduleKind = .daily
        case .weekdays: scheduleKind = .weekdays
        case .timesPerWeek: scheduleKind = .timesPerWeek
        }
        if case .weekdays(let days) = draft.schedule { selectedWeekdays = days }
        else { selectedWeekdays = [] }
        if case .timesPerWeek(let count) = draft.schedule { timesPerWeek = count }
        else { timesPerWeek = 3 }
    }

    private var isValid: Bool {
        guard whyItMatters.count <= 240 else { return false }
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
            schedule: schedule,
            whyItMatters: whyItMatters,
            isWhyMemoryHidden: isWhyMemoryHidden
        )
        onSave(draft)
    }

    /// Readable names for assistive technology; symbol identifiers stay internal.
    private static func iconLabel(_ symbol: String) -> String {
        let labels = [
            "drop.fill": "Water", "pills.fill": "Medication", "fork.knife": "Meal",
            "bed.double.fill": "Rest", "heart.fill": "Heart", "figure.walk": "Walking",
            "figure.run": "Running", "dumbbell.fill": "Weights", "figure.yoga": "Yoga",
            "bicycle": "Cycling", "book.fill": "Book", "graduationcap.fill": "Learning",
            "character.book.closed.fill": "Language", "music.note": "Music", "leaf.fill": "Leaf",
            "moon.stars.fill": "Night", "pencil.line": "Writing", "sparkles": "Sparkles",
            "wind": "Breathing", "checklist": "Checklist", "laptopcomputer": "Computer",
            "tray.full.fill": "Inbox", "timer": "Timer", "person.2.fill": "People",
            "phone.fill": "Phone", "envelope.fill": "Message", "banknote.fill": "Money",
            "chart.pie.fill": "Budget", "cart.fill": "Shopping", "star.fill": "Star",
            "tag.fill": "Tag", "circle.grid.2x2.fill": "Grid", "checkmark.circle.fill": "Checkmark",
            "iphone.slash": "Phone break", "nosign": "Limit",
            "cup.and.saucer.fill": "Cup", "takeoutbag.and.cup.and.straw.fill": "Takeout"
        ]
        return "\(labels[symbol] ?? "Habit") icon"
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

/// Long segmented labels must not truncate when someone requests larger text.
private struct AdaptiveHabitPickerStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.labelsHidden().pickerStyle(.inline)
        }
        else { content.pickerStyle(.segmented) }
    }
}
