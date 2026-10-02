import Foundation
import SwiftData
import XCTest
@testable import Avela

final class AppPersistenceTests: XCTestCase {
    @MainActor
    func testInMemoryContainerInitializesTemporarySchema() async throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ScaffoldRecord>()), 1)
    }

    @MainActor
    func testRecordSurvivesReopeningDiskStoreWithoutDuplicateSeed() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("PersistenceTest.store")
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        // Return only value types so the first container/context is released before reopening.
        func writeStore() throws -> UUID {
            let container = try AppPersistence.makeContainer(storeURL: storeURL)
            let context = container.mainContext
            let seed = try XCTUnwrap(context.fetch(FetchDescriptor<ScaffoldRecord>()).first)
            let seedID = seed.id
            context.insert(ScaffoldRecord(id: id, createdAt: createdAt))
            try context.save()
            return seedID
        }
        let seedID = try writeStore()

        let reopened = try AppPersistence.makeContainer(storeURL: storeURL)
        let records = try reopened.mainContext.fetch(FetchDescriptor<ScaffoldRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.contains { $0.id == seedID })
        let saved = try XCTUnwrap(records.first { $0.id == id })
        XCTAssertEqual(saved.createdAt, createdAt)
    }
}
