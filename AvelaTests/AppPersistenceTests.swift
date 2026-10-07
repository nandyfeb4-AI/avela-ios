import Foundation
import SwiftData
import XCTest
@testable import Avela

final class AppPersistenceTests: XCTestCase {
    @MainActor
    func testInMemoryContainerInitializesEmptyCanonicalSchema() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<HabitRecord>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<HabitConfigurationSnapshotRecord>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CompletionRecord>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SkipRecord>()), 0)
    }

    @MainActor
    func testDataSurvivesReopeningDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("PersistenceTest.store")

        func writeStore() throws {
            let container = try AppPersistence.makeContainer(storeURL: storeURL)
            let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
            let draft = HabitDraft(name: "Read", iconName: "book", category: .learning, polarity: .positive, schedule: .daily)
            let habit = try repository.createHabit(draft, at: Date(timeIntervalSince1970: 1_700_000_000))
            try repository.recordCompletion(
                habitID: habit.id,
                at: Date(timeIntervalSince1970: 1_700_000_100),
                source: .app,
                note: nil
            )
        }
        try writeStore()

        let reopened = try AppPersistence.makeContainer(storeURL: storeURL)
        let habits = try reopened.mainContext.fetch(FetchDescriptor<HabitRecord>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits.first?.name, "Read")
        let completions = try reopened.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(completions.count, 1)
    }
    @MainActor
    func testAddingEnrichmentModelsPreservesExistingStoreFacts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("BeforeEnrichment.store")
        let priorSchema = Schema([
            HealthHabitConnectionRecord.self, HabitReminderRecord.self, HabitRecord.self,
            HabitConfigurationSnapshotRecord.self, CompletionRecord.self, SkipRecord.self,
            HabitArchivePeriodRecord.self, AttentionGoalRecord.self,
            AttentionGoalConfigurationSnapshotRecord.self, AttentionUsageEntryRecord.self,
            AttentionCheckInRecord.self, AttentionSessionRecord.self, CompanionProfileRecord.self,
            AppAppearanceRecord.self
        ])
        let date = Date()
        var habitID: UUID!
        var completionID: UUID!
        do {
            let previous = try ModelContainer(for: priorSchema, configurations: [
                ModelConfiguration(schema: priorSchema, url: url, cloudKitDatabase: .none)])
            let habits = SwiftDataHabitRepository(modelContext: previous.mainContext)
            habitID = try habits.createHabit(HabitDraft(name: "Keep my history", iconName: "book", category: .learning,
                polarity: .positive, schedule: .daily), at: date.addingTimeInterval(-86_400)).id
            let completion = CompletionRecord(id: UUID(), habitID: habitID, occurredAt: date,
                localDateKey: LocalDay.key(for: date, calendar: .current), sourceRaw: "app", note: "Existing fact")
            completionID = completion.id
            previous.mainContext.insert(completion)
            try previous.mainContext.save()
        }
        let expanded = try AppPersistence.makeContainer(storeURL: url)
        let habits = SwiftDataHabitRepository(modelContext: expanded.mainContext)
        XCTAssertEqual(try habits.fetchHabit(id: habitID)?.name, "Keep my history")
        let saved = try expanded.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(saved.map(\.id), [completionID!])
        XCTAssertEqual(saved.first?.note, "Existing fact")
        XCTAssertEqual(saved.first?.isQuantityDerived, false)
        XCTAssertEqual(try expanded.mainContext.fetchCount(FetchDescriptor<HabitActivityEntryRecord>()), 0)
        XCTAssertEqual(try expanded.mainContext.fetchCount(FetchDescriptor<RoutineRecord>()), 0)
        XCTAssertEqual(try expanded.mainContext.fetchCount(FetchDescriptor<WeeklyReflectionRecord>()), 0)
        XCTAssertEqual(try expanded.mainContext.fetchCount(FetchDescriptor<IntentionSessionLinkRecord>()), 0)
        try SwiftDataHabitActivityRepository(context: expanded.mainContext, habits: habits).configure(
            habitID: habitID, target: .init(amount: 5, unit: .pages), smallerAction: "One paragraph", at: date)
        XCTAssertEqual(try expanded.mainContext.fetch(FetchDescriptor<CompletionRecord>()).map(\.id), [completionID!])
    }

}
