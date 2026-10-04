import Foundation
import SwiftData

/// Owns the canonical schema and store configuration at the composition root.
///
/// Phase 0 seeded a throwaway `ScaffoldRecord` to probe SwiftData init/reopen.
/// Phase 1 replaces that schema outright with the canonical Habit/Completion/Skip
/// models below. There is no `SchemaMigrationPlan` from the scaffold schema: no
/// release has shipped, so no device holds data worth preserving, and
/// `ScaffoldRecord` carried no product meaning to migrate. Opening a pre-Phase-1
/// dev/simulator store with this schema is unsupported; see SETUP.md for the
/// one-time reset step this requires on existing dev installs.
@MainActor
enum AppPersistence {
    static func makeContainer(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema([
            HabitReminderRecord.self,
            HabitRecord.self,
            HabitConfigurationSnapshotRecord.self,
            CompletionRecord.self,
            SkipRecord.self,
            HabitArchivePeriodRecord.self,
            AttentionGoalRecord.self,
            AttentionGoalConfigurationSnapshotRecord.self,
            AttentionUsageEntryRecord.self,
            AttentionCheckInRecord.self,
            AttentionSessionRecord.self,
            CompanionProfileRecord.self,
        ])
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
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
