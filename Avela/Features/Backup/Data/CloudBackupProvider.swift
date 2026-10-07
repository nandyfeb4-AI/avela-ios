import Foundation
import CloudKit

struct CloudBackupSummary: Identifiable, Equatable {
    let id: String
    let createdAt: Date
}

@MainActor
protocol CloudBackupProvider {
    var isConfigured: Bool { get }
    func accountIdentity() async throws -> String
    func upload(_ archive: BackupArchive, deviceID: String) async throws
    func list() async throws -> [CloudBackupSummary]
    func download(id: String) async throws -> BackupArchive
    func delete(id: String) async throws
}

/// Explicit private-database snapshots; no public database, push subscription,
/// tracking server or automatic record merging.
@MainActor
final class CloudKitBackupProvider: CloudBackupProvider {
    private let container: CKContainer?
    var isConfigured: Bool { container != nil }
    init(identifier: String?) {
        // No CloudKit calls in placeholder or isolated UI-test builds.
        guard let identifier, identifier.hasPrefix("iCloud."), !identifier.contains("com.example") else {
            container = nil
            return
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] != nil {
            container = nil
            return
        }
        #endif
        container = CKContainer(identifier: identifier)
    }
    private func database() throws -> CKDatabase {
        guard let container else { throw BackupError.unavailable }
        return container.privateCloudDatabase
    }
    func accountIdentity() async throws -> String {
        guard let container, try await container.accountStatus() == .available else { throw BackupError.unavailable }
        return try await container.userRecordID().recordName
    }
    func upload(_ archive: BackupArchive, deviceID: String) async throws {
        _ = try archive.verifiedPayload()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("snapshot.json")
        try JSONEncoder().encode(archive).write(to: url, options: [.atomic, .completeFileProtection])
        let row = CKRecord(recordType: "AvelaRecoverySnapshot", recordID: .init(recordName: archive.id.uuidString))
        row["payload"] = CKAsset(fileURL: url)
        row["snapshotDate"] = archive.createdAt as CKRecordValue
        row["deviceID"] = deviceID as CKRecordValue
        _ = try await database().save(row)
    }
    func list() async throws -> [CloudBackupSummary] {
        let database = try database()
        // Paginate before sorting. No custom sort index or partial-list claims.
        var result = try await database.records(matching: CKQuery(recordType: "AvelaRecoverySnapshot", predicate: NSPredicate(value: true)), desiredKeys: ["snapshotDate"], resultsLimit: 100)
        var rows: [CloudBackupSummary] = []
        while true {
            for (_, value) in result.matchResults {
                let row = try value.get()
                guard let date = row["snapshotDate"] as? Date else { throw BackupError.invalidFile }
                rows.append(.init(id: row.recordID.recordName, createdAt: date))
            }
            guard let cursor = result.queryCursor else { break }
            result = try await database.records(continuingMatchFrom: cursor, desiredKeys: ["snapshotDate"], resultsLimit: 100)
        }
        return rows.sorted { $0.createdAt > $1.createdAt }
    }
    func download(id: String) async throws -> BackupArchive {
        let row = try await database().record(for: .init(recordName: id))
        guard let asset = row["payload"] as? CKAsset, let url = asset.fileURL,
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= BackupArchive.maximumBytes * 2 else { throw BackupError.invalidFile }
        let archive = try BackupArchive.decode(Data(contentsOf: url))
        guard archive.id.uuidString == id else { throw BackupError.invalidFile }
        return archive
    }
    func delete(id: String) async throws {
        _ = try await database().deleteRecord(withID: .init(recordName: id))
    }
}

@MainActor enum CloudBackupProviders {
    static func make() throws -> any CloudBackupProvider {
        #if DEBUG
        if ProcessInfo.processInfo.environment["AVELA_UI_TEST_STORE_PATH"] != nil,
           ProcessInfo.processInfo.environment["AVELA_UI_TEST_SEED_FIXTURE"] == "cloudBackupRecovery" {
            return try DebugCloudBackupProvider()
        }
        #endif
        return CloudKitBackupProvider(identifier: Bundle.main.object(forInfoDictionaryKey: "AvelaCloudBackupContainer") as? String)
    }
}

#if DEBUG
import SwiftData

/// Only reachable with BOTH existing UI-test isolation variables. Never reads
/// a user's store or calls CloudKit; absent from Release binaries.
@MainActor private final class DebugCloudBackupProvider: CloudBackupProvider {
    let isConfigured = true
    private var archives: [BackupArchive]
    init() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let repository = SwiftDataHabitRepository(modelContext: container.mainContext)
        let date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let habit = try repository.createHabit(.init(name: "Recovered Reading", iconName: "book.fill",
            category: .learning, polarity: .positive, schedule: .daily), at: date)
        try repository.recordCompletion(habitID: habit.id, at: date, source: .app, note: nil)
        try SwiftDataCompanionProfileRepository(modelContext: container.mainContext).save(.init(onboardingCompleted: true))
        archives = [try BackupStore(context: container.mainContext).capture()]
    }
    func accountIdentity() async throws -> String { "isolated-test-account" }
    func upload(_ archive: BackupArchive, deviceID: String) async throws { archives.append(archive) }
    func list() async throws -> [CloudBackupSummary] { archives.map { .init(id: $0.id.uuidString, createdAt: $0.createdAt) } }
    func download(id: String) async throws -> BackupArchive {
        guard let row = archives.first(where: { $0.id.uuidString == id }) else { throw BackupError.invalidFile }
        return row
    }
    func delete(id: String) async throws { archives.removeAll { $0.id.uuidString == id } }
}
#endif
