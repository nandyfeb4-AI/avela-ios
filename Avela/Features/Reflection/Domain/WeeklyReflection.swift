import Foundation

/// Civil week identity is captured once; a private note never changes metrics.
struct ReflectionWeek: Equatable, Sendable {
    let key: String
    let start: Date
    let end: Date
    let timeZoneIdentifier: String

    static func containing(_ date: Date, calendar: Calendar) -> Self {
        let interval = LocalDay.weekInterval(containing: date, calendar: calendar)
        return Self(key: "\(LocalDay.key(for: interval.start, calendar: calendar))/\(LocalDay.key(for: interval.end, calendar: calendar))",
                    start: interval.start, end: interval.end,
                    timeZoneIdentifier: calendar.timeZone.identifier)
    }
}

struct WeeklyReflection: Identifiable, Equatable, Sendable {
    let id: UUID
    let week: ReflectionWeek
    let whatHelped: String
    let whatGotInTheWay: String
    let createdAt: Date
    let updatedAt: Date
}

struct ReflectionDraft: Equatable {
    static let characterLimit = 500
    var whatHelped = ""
    var whatGotInTheWay = ""

    var hasContent: Bool {
        !whatHelped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !whatGotInTheWay.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var isValid: Bool {
        hasContent && whatHelped.count <= Self.characterLimit && whatGotInTheWay.count <= Self.characterLimit
    }

    func validated() throws -> Self {
        guard isValid else { throw ReflectionRepositoryError.invalidDraft }
        return Self(whatHelped: whatHelped.trimmingCharacters(in: .whitespacesAndNewlines),
                    whatGotInTheWay: whatGotInTheWay.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum ReflectionRepositoryError: Error, Equatable { case invalidDraft }

@MainActor
protocol ReflectionRepository {
    func reflection(for week: ReflectionWeek) throws -> WeeklyReflection?
    @discardableResult
    func save(_ draft: ReflectionDraft, for week: ReflectionWeek, at date: Date) throws -> WeeklyReflection
    func delete(for week: ReflectionWeek) throws
}
