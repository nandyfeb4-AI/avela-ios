import Foundation
import SwiftData

/// Owns the temporary schema and store configuration at the composition root.
@MainActor
enum AppPersistence {
    static func makeContainer(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema([ScaffoldRecord.self])
        let configuration: ModelConfiguration
        if let storeURL {
            precondition(!inMemory, "A disk URL cannot be used for an in-memory store.")
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        if try context.fetchCount(FetchDescriptor<ScaffoldRecord>()) == 0 {
            context.insert(ScaffoldRecord())
            try context.save()
        }
        return container
    }
}
