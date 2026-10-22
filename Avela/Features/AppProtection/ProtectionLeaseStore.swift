import Foundation

/// Serializes app/extension mutations across processes. Private operational
/// metadata is excluded from system backups; it is not a widget snapshot.
struct ProtectionLeaseStore {
    static let groupID = "group.com.example.Avela"
    private let directory: URL?
    init(directory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)) {
        self.directory = directory?.appendingPathComponent("AppProtection", isDirectory: true)
    }

    func read() throws -> ProtectionLease? { try update { $0 } }

    @discardableResult
    func update<T>(_ operation: (inout ProtectionLease?) throws -> T) throws -> T {
        guard let directory else { throw AppProtectionError.storageUnavailable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        let url = directory.appendingPathComponent("lease.json")
        var coordinationError: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                var lease: ProtectionLease?
                if FileManager.default.fileExists(atPath: coordinated.path) {
                    lease = try JSONDecoder().decode(ProtectionLease?.self, from: Data(contentsOf: coordinated))
                }
                let output = try operation(&lease)
                try JSONEncoder().encode(lease).write(to: coordinated,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                return output
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw AppProtectionError.storageUnavailable }
        return try result.get()
    }

    /// A corrupt state must not trap someone behind a restriction. Clearing the
    /// named ManagedSettings store is supplied by the caller before repair.
    func discard() throws {
        guard let directory else { throw AppProtectionError.storageUnavailable }
        let url = directory.appendingPathComponent("lease.json")
        var error: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &error) { coordinated in
            do { try JSONEncoder().encode(Optional<ProtectionLease>.none).write(to: coordinated,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
            catch { writeError = error }
        }
        if let error { throw error }
        if let writeError { throw writeError }
    }
}
