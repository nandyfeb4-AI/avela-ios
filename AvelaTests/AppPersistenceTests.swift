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
}
