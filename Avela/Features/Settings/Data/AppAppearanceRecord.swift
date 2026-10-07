import Foundation
import SwiftData

/// A separate preferences record leaves existing companion/profile fields intact.
@Model
final class AppAppearanceRecord {
    @Attribute(.unique) var preferencesID: String
    var themeRaw: String
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.AppAppearanceRecordRow) {
        self.preferencesID = row.preferencesID
        self.themeRaw = row.themeRaw
    }


    init(theme: AppTheme) {
        preferencesID = "primary"
        themeRaw = theme.rawValue
    }
}

@MainActor
final class SwiftDataAppearanceRepository: AppearanceRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func theme() throws -> AppTheme {
        guard let raw = try record()?.themeRaw else { return .tidewater }
        return AppTheme(rawValue: raw) ?? .tidewater
    }

    func save(theme: AppTheme) throws {
        if let existing = try record() {
            let previous = existing.themeRaw
            existing.themeRaw = theme.rawValue
            do { try context.save() }
            catch {
                existing.themeRaw = previous
                throw error
            }
        } else {
            let inserted = AppAppearanceRecord(theme: theme)
            context.insert(inserted)
            do { try context.save() }
            catch {
                context.delete(inserted)
                throw error
            }
        }
    }

    private func record() throws -> AppAppearanceRecord? {
        let query = FetchDescriptor<AppAppearanceRecord>(predicate: #Predicate { $0.preferencesID == "primary" })
        return try context.fetch(query).first
    }
}
