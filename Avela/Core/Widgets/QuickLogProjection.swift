import Foundation

/// Display ordering only. The app exports scheduling and quantity decisions.
struct QuickLogProjection {
    let snapshot: WidgetSnapshot
    let date: Date

    var orderedHabits: [WidgetHabitSnapshot] {
        let pending = snapshot.habits.filter { !$0.isCompletedToday && $0.isSkippedToday != true && $0.weeklyTargetMet != true }
        let settled = snapshot.habits.filter { $0.isCompletedToday || $0.isSkippedToday == true || $0.weeklyTargetMet == true }
        let ordered = pending + settled
        guard let until = snapshot.quickLogPinUntil, date < until,
              let ids = snapshot.quickLogPinnedIDs else { return ordered }
        let pinned = ids.compactMap { id in snapshot.habits.first { $0.id == id } }
        return pinned + ordered.filter { !ids.contains($0.id) }
    }

    func rows(capacity: Int) -> [WidgetHabitSnapshot] {
        Array(orderedHabits.prefix(max(0, capacity)))
    }

    var summary: String {
        guard !snapshot.habits.isEmpty else { return "No habits due today" }
        let done = snapshot.habits.filter(\.isCompletedToday).count
        if done == snapshot.habits.count { return "All logged today" }
        let pending = snapshot.habits.filter { !$0.isCompletedToday && $0.isSkippedToday != true && $0.weeklyTargetMet != true }.count
        if pending == 0 { return "No check-ins left today" }
        return "\(pending) left today"
    }

    func canLog(_ row: WidgetHabitSnapshot) -> Bool {
        !row.isCompletedToday && row.isSkippedToday == false && row.weeklyTargetMet != true
            && row.requiresQuantityLogging == false && row.configurationRevision != nil
            && snapshot.timeZoneIdentifier != nil
    }
}

/// A routine is an ordered selection, not new completion facts. Missing,
/// archived and non-due members are absent from the canonical Today export.
struct RoutineLogProjection {
    let snapshot: WidgetSnapshot
    let routineID: UUID

    var routine: WidgetRoutineSnapshot? { snapshot.routines?.first { $0.id == routineID } }
    var selectedSnapshot: WidgetSnapshot? {
        guard let routine else { return nil }
        var selected = snapshot
        let rows = Dictionary(uniqueKeysWithValues: snapshot.habits.map { ($0.id, $0) })
        // Stable de-duplication also protects older/corrupted shared display data.
        var seen = Set<UUID>()
        let ordered = routine.habitIDs.compactMap { id -> WidgetHabitSnapshot? in
            guard seen.insert(id).inserted else { return nil }
            return rows[id]
        }
        selected = WidgetSnapshot(localDateKey: snapshot.localDateKey, generatedAt: snapshot.generatedAt,
            habits: ordered, attentionGoals: [])
        selected.timeZoneIdentifier = snapshot.timeZoneIdentifier
        selected.accentLight = snapshot.accentLight
        selected.accentDark = snapshot.accentDark
        selected.quickLogMessage = snapshot.quickLogMessage
        return selected
    }
}

/// Rich Tide uses the exported theme hue without a second theme registry.
/// Opaque colors keep text and actions legible over both gradient endpoints.
struct WidgetRichPalette {
    let start: UInt32
    let end: UInt32
    let ink: UInt32 = 0xF4FCF9
    let secondary: UInt32 = 0xD5EAE2
    let action: UInt32
    var actionInk: UInt32 { start }

    init(accent: UInt32, dark: Bool) {
        func mix(_ value: UInt32, toward target: UInt32, amount: Double) -> UInt32 {
            [16, 8, 0].reduce(UInt32(0)) { result, shift in
                let a = Double((value >> shift) & 255)
                let b = Double((target >> shift) & 255)
                return result | (UInt32((a + (b - a) * amount).rounded()) << shift)
            }
        }
        start = mix(accent, toward: 0, amount: dark ? 0.70 : 0.57)
        end = mix(accent, toward: 0, amount: dark ? 0.48 : 0.30)
        action = mix(accent, toward: 0xFFFFFF, amount: 0.87)
    }
}
