import Foundation

struct WidgetSnapshotStore {
    static let appGroupID = "group.com.example.Avela"
    private let directoryURL: URL?

    init(directoryURL: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupID)) {
        self.directoryURL = directoryURL
    }

    func save(_ snapshot: WidgetSnapshot) throws {
        guard let directoryURL else { throw WidgetSnapshotError.sharedContainerUnavailable }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: directoryURL.appendingPathComponent("WidgetSnapshot.json"), options: .atomic)
    }

    func load() throws -> WidgetSnapshot? {
        guard let directoryURL else { throw WidgetSnapshotError.sharedContainerUnavailable }
        let url = directoryURL.appendingPathComponent("WidgetSnapshot.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion == 1 else { throw WidgetSnapshotError.unsupportedVersion }
        return snapshot
    }
}

enum WidgetSnapshotError: Error {
    case sharedContainerUnavailable
    case unsupportedVersion
    case projectionUnavailable
}
