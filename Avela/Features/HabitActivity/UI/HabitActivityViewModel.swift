import Foundation
import Observation

@MainActor @Observable
final class HabitActivityViewModel {
    let habitID: UUID
    private let repository: HabitActivityRepository
    private let habits: HabitRepository
    private let calendar: Calendar
    private let presets: HabitQuickLogPresets
    private var presetEditUnit: HabitQuantityUnit?
    private var presetEditConfigurationID: UUID?
    private(set) var quickAmounts: [Int] = []
    private(set) var lastQuickEntry: HabitActivityEntry?
    var isShowingPresets = false
    var presetDraft = ["", "", ""]
    private(set) var presetError: String?
    private var loadedDayKey: String?
    private(set) var habit: Habit?
    private(set) var configuration: HabitActivityConfiguration?
    private(set) var entries: [HabitActivityEntry] = []
    private(set) var timer: HabitTimerState?
    private(set) var errorMessage: String?
    private(set) var correction: HabitCorrectionPreview?
    var selectedDate = Date()
    var isShowingConfiguration = false
    var quantityEnabled = false
    var targetAmount = 20
    var unit: HabitQuantityUnit = .minutes
    var smallerAction = ""
    var amount = 1
    private(set) var confirmation = ""

    init(habitID: UUID, repository: HabitActivityRepository, habits: HabitRepository, calendar: Calendar = .autoupdatingCurrent, presets: HabitQuickLogPresets? = nil) {
        self.habitID = habitID; self.repository = repository; self.habits = habits; self.calendar = calendar; self.presets = presets ?? HabitQuickLogPresets()
    }
    var total: Int { entries.filter { $0.kind == .quantity && $0.unit == configuration?.target?.unit }.reduce(0) { $0 + $1.amount } }
    var isToday: Bool { calendar.isDateInToday(selectedDate) }
    var progressLabel: String {
        guard let target = configuration?.target else { return "Check-in habit" }
        return "\(total) of \(target.amount) \(target.unit.rawValue) logged"
    }
    var hasSmallerAction: Bool { !(configuration?.smallerAction.isEmpty ?? true) }
    func load() {
        loadedDayKey = nil
        do {
            habit = try habits.fetchHabit(id: habitID)
            configuration = try repository.configuration(for: habitID, on: selectedDate)
            entries = try repository.entries(for: habitID, on: selectedDate)
            correction = try repository.correctionPreview(habitID: habitID, on: selectedDate)
            timer = isToday ? try repository.timer(for: habitID, on: selectedDate) : nil
            loadedDayKey = LocalDay.key(for: selectedDate, calendar: calendar)
            quickAmounts = configuration?.target.map { presets.amounts(for: habitID, unit: $0.unit) } ?? []
            if let lastQuickEntry, lastQuickEntry.dayKey != loadedDayKey || lastQuickEntry.configurationID != configuration?.id || !entries.contains(where: { $0.id == lastQuickEntry.id }) {
                self.lastQuickEntry = nil
            }
        } catch { fail() }
    }
    func preparePresets() {
        guard isToday, isLoadedDay(nil), let configuration, let target = configuration.target else { return }
        presetEditUnit = target.unit
        presetEditConfigurationID = configuration.id
        presetDraft = quickAmounts.map(String.init) + Array(repeating: "", count: 3 - quickAmounts.count)
        presetError = nil
        isShowingPresets = true
    }
    func cancelPresets() {
        isShowingPresets = false
        presetDraft = ["", "", ""]
        presetEditUnit = nil
        presetEditConfigurationID = nil
        presetError = nil
    }
    func savePresets(now: Date = Date()) {
        let fields = presetDraft.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let values = fields.compactMap(Int.init)
        guard !fields.isEmpty, values.count == fields.count else { presetError = "Use one to three different whole amounts from 1 to 10,000."; return }
        do {
            guard isLoadedDay(nil), LocalDay.key(for: selectedDate, calendar: calendar) == LocalDay.key(for: now, calendar: calendar),
                  let editUnit = presetEditUnit, let current = try repository.configuration(for: habitID, on: now),
                  current.id == presetEditConfigurationID, current.target?.unit == editUnit else {
                presetError = "The tracking day or target changed. Cancel, reload, and edit your quick amounts again."; return
            }
            try presets.save(values, for: habitID, unit: editUnit)
            quickAmounts = values
            cancelPresets()
        } catch { presetError = "Use one to three different whole amounts from 1 to 10,000." }
    }
    func logPreset(_ value: Int, now: Date = Date()) {
        errorMessage = nil
        guard isLoadedDay(nil), loadedDayKey == LocalDay.key(for: now, calendar: calendar),
              let configuration, let target = configuration.target,
              presets.amounts(for: habitID, unit: target.unit).contains(value) else { fail(); return }
        do {
            // Fresh IDs isolate Undo from earlier entries, including identical amounts.
            let before = Set(try repository.entries(for: habitID, on: selectedDate).map(\.id))
            try repository.log(habitID: habitID, kind: .quantity, amount: value,
                expectedConfigurationID: configuration.id, on: selectedDate, now: now)
            let inserted = try repository.entries(for: habitID, on: selectedDate).filter { !before.contains($0.id) }
            lastQuickEntry = inserted.count == 1 ? inserted.first : nil
            confirmation = "Added \(value) \(target.unit.name(for: value))."
            load()
        } catch { fail() }
    }
    func undoQuickLog(now: Date = Date()) {
        guard let entry = lastQuickEntry, isLoadedDay(nil), loadedDayKey == LocalDay.key(for: now, calendar: calendar),
              entry.dayKey == loadedDayKey else { fail(); return }
        do {
            guard let current = try repository.configuration(for: habitID, on: selectedDate),
                  current.id == entry.configurationID,
                  try repository.entries(for: habitID, on: selectedDate).contains(entry) else { fail(); return }
            try repository.removeEntry(id: entry.id, now: now)
            lastQuickEntry = nil
            confirmation = "Quick entry removed."
            load()
        } catch { fail() }
    }
    func prepareConfiguration() {
        selectedDate = Date(); load()
        quantityEnabled = configuration?.target != nil
        targetAmount = configuration?.target?.amount ?? 20
        unit = configuration?.target?.unit ?? .minutes
        smallerAction = configuration?.smallerAction ?? ""
        isShowingConfiguration = true
    }
    func saveConfiguration() {
        do {
            try repository.configure(habitID: habitID, target: quantityEnabled ? HabitQuantityTarget(amount: targetAmount, unit: unit) : nil,
                smallerAction: smallerAction, at: Date())
            isShowingConfiguration = false; load()
        } catch { errorMessage = "Couldn't save. Use a target from 1 to 10,000, keep the smaller action under 160 characters, and disconnect Apple Health before adding a manual quantity target." }
    }
    func log(_ kind: HabitActivityKind, now: Date = Date(), reviewedDate: Date? = nil) {
        errorMessage = nil
        guard isLoadedDay(reviewedDate), let configuration else { fail(); return }
        do {
            try repository.log(habitID: habitID, kind: kind, amount: amount, expectedConfigurationID: configuration.id, on: selectedDate, now: now)
            confirmation = kind == .quantity ? "Progress saved." : "Smaller action saved. Your full target stays unchanged."
            load()
        } catch { fail() }
    }
    func remove(_ entry: HabitActivityEntry) {
        do { try repository.removeEntry(id: entry.id, now: Date()); load() }
        catch { fail() }
    }
    func correct(to outcome: HabitDayCorrection, reviewedDate: Date? = nil) {
        guard isLoadedDay(reviewedDate), let correction else { fail(); return }
        do { try repository.correct(correction, to: outcome, on: selectedDate, now: Date()); confirmation = "Check-in updated."; load() }
        catch { fail() }
    }
    func toggleTimer(now: Date = Date()) {
        guard isToday else { return }
        var state = timer ?? HabitTimerState(habitID: habitID, dayKey: LocalDay.key(for: now, calendar: calendar), startedAt: nil, elapsedSeconds: 0)
        if state.startedAt != nil { state.elapsedSeconds = state.seconds(at: now); state.startedAt = nil }
        else { state.startedAt = now }
        do { try repository.saveTimer(state, now: now); timer = state }
        catch { fail() }
    }
    func logTimer(now: Date = Date()) {
        guard let timer, isToday, timer.startedAt == nil else { return }
        let minutes = timer.seconds(at: now) / 60
        guard minutes > 0 else { return }
        do { try repository.logTimer(habitID: habitID, now: now); confirmation = "Timer minutes saved."; load() }
        catch { fail() }
    }

    func resetTimer() {
        do { try repository.resetTimer(for: habitID); timer = nil }
        catch { fail() }
    }
    private func isLoadedDay(_ reviewedDate: Date?) -> Bool {
        let key = LocalDay.key(for: selectedDate, calendar: calendar)
        return loadedDayKey == key && (reviewedDate.map { LocalDay.key(for: $0, calendar: calendar) == key } ?? true)
    }
    func clearError() { errorMessage = nil }
    private func fail() { errorMessage = "Couldn't save this change. Reload and try again. Dates must be scheduled, inside tracking history and outside a pause; quantity success requires its logged target." }
}
