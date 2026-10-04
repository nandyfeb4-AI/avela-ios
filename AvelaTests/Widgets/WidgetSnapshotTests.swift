import XCTest
import SwiftData
@testable import Avela

final class WidgetSnapshotTests: XCTestCase {
    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    func testAtomicSnapshotRoundTripRetainsActualManualData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directoryURL: directory)
        XCTAssertNil(try store.load())
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = WidgetSnapshot(
            localDateKey: LocalDay.key(for: date, calendar: calendar()), generatedAt: date,
            habits: [WidgetHabitSnapshot(id: UUID(), name: "Walk", iconName: "figure.walk", isCompletedToday: true, progressLabel: "Daily")],
            attentionGoals: [WidgetAttentionSnapshot(id: UUID(), name: "Social", statusLabel: "Not logged yet", hasLoggedUsage: false)]
        )
        try store.save(snapshot)
        XCTAssertEqual(try store.load(), snapshot)
        XCTAssertFalse(try XCTUnwrap(store.load()).attentionGoals[0].hasLoggedUsage)
    }

    func testPreviousLocalDaySnapshotIsUnknownAfterMidnightIncludingDST() {
        let calendar = calendar()
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0))!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
        XCTAssertEqual(nextDay.timeIntervalSince(date), 23 * 3600)
        let snapshot = WidgetSnapshot(localDateKey: LocalDay.key(for: date, calendar: calendar), generatedAt: date, habits: [], attentionGoals: [])
        XCTAssertTrue(snapshot.isCurrent(asOf: nextDay.addingTimeInterval(-1), calendar: calendar))
        XCTAssertFalse(snapshot.isCurrent(asOf: nextDay, calendar: calendar))
    }

    func testClockRollbackAndTimeZoneDateChangeCannotShowCurrentProgress() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = calendar()
        let snapshot = WidgetSnapshot(localDateKey: LocalDay.key(for: date, calendar: calendar), generatedAt: date, habits: [], attentionGoals: [])
        XCTAssertFalse(snapshot.isCurrent(asOf: date.addingTimeInterval(-120), calendar: calendar))
        var shifted = calendar
        shifted.timeZone = TimeZone(secondsFromGMT: -12 * 3600)!
        XCTAssertNotEqual(LocalDay.key(for: date, calendar: calendar), LocalDay.key(for: date, calendar: shifted))
        XCTAssertFalse(snapshot.isCurrent(asOf: date, calendar: shifted))
    }

    func testMissingSharedContainerFailsExplicitly() {
        let store = WidgetSnapshotStore(directoryURL: nil)
        XCTAssertThrowsError(try store.load())
    }

    func testPreArtworkSnapshotDecodesWithoutInventingCompanionPreferences() throws {
        let snapshot = WidgetSnapshot(localDateKey: "2026-10-04", generatedAt: Date(), habits: [], attentionGoals: [])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        legacy.removeValue(forKey: "companionAnimal")
        legacy.removeValue(forKey: "companionState")
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.companionAnimal)
        XCTAssertNil(decoded.companionState)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    @MainActor
    func testCompanionExportUsesSelectedAnimalActualLoggedStateAndDisablePreference() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let calendar = calendar()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let habits = SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar)
        let attention = SwiftDataAttentionRepository(modelContext: container.mainContext, calendar: calendar)
        let profiles = SwiftDataCompanionProfileRepository(modelContext: container.mainContext)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directoryURL: directory)
        let exporter = WidgetSnapshotExporter(store: store)
        let goal = try attention.createGoal(AttentionGoalDraft(name: "Social", appOrCategoryLabel: "Social", type: .maxDurationPerDay, targetValue: 30, unit: .minutes), at: date)

        try exporter.export(habits: habits, attention: attention, profiles: profiles, asOf: date, calendar: calendar)
        XCTAssertEqual(try store.load()?.companionState, "calm", "No usage must not fabricate a measured healthy/celebrating state")
        _ = try attention.recordUsage(goalID: goal.id, amount: 35, at: date, source: .manual)
        for animal in CompanionAnimal.allCases {
            try profiles.save(CompanionProfile(selectedAnimal: animal))
            try exporter.export(habits: habits, attention: attention, profiles: profiles, asOf: date, calendar: calendar)
            let snapshot = try XCTUnwrap(store.load())
            XCTAssertEqual(snapshot.companionAnimal, animal.rawValue)
            XCTAssertEqual(snapshot.companionState, "overloaded")
        }

        try profiles.save(CompanionProfile(selectedAnimal: .otter, companionEnabled: false))
        try exporter.export(habits: habits, attention: attention, profiles: profiles, asOf: date, calendar: calendar)
        XCTAssertNil(try store.load()?.companionAnimal)
        XCTAssertNil(try store.load()?.companionState)
        try exporter.export(habits: habits, attention: attention, asOf: date, calendar: calendar)
        XCTAssertNil(try store.load()?.companionAnimal, "Callers without profile authority do not enable a companion")
    }
}
