import Foundation

enum WidgetDeepLink: Equatable {
    case today
    case habit(habitID: UUID)
    case logProgress(habitID: UUID)
    case complete(habitID: UUID, localDateKey: String)

    var url: URL {
        var components = URLComponents()
        components.scheme = "avela"
        switch self {
        case .today: components.host = "today"
        case .habit(let habitID), .logProgress(let habitID):
            components.host = self == .habit(habitID: habitID) ? "habit" : "log-progress"
            components.queryItems = [URLQueryItem(name: "habit", value: habitID.uuidString)]
        case .complete(let habitID, let key):
            components.host = "complete"
            components.queryItems = [
                URLQueryItem(name: "habit", value: habitID.uuidString),
                URLQueryItem(name: "day", value: key)
            ]
        }
        // All components above are controlled values, not arbitrary URL text.
        return components.url!
    }

    static func parse(_ url: URL) -> WidgetDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "avela",
              components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil,
              components.path.isEmpty else { return nil }
        if components.host == "today", components.queryItems == nil { return .today }
        if components.host == "habit" || components.host == "log-progress" {
            guard let query = components.queryItems, query.count == 1, query[0].name == "habit",
                  let text = query[0].value, let id = UUID(uuidString: text) else { return nil }
            return components.host == "habit" ? .habit(habitID: id) : .logProgress(habitID: id)
        }
        guard components.host == "complete",
              let query = components.queryItems, query.count == 2,
              Set(query.map(\.name)) == ["habit", "day"],
              let idText = query.first(where: { $0.name == "habit" })?.value,
              let id = UUID(uuidString: idText),
              let day = query.first(where: { $0.name == "day" })?.value,
              isDayKey(day) else { return nil }
        return .complete(habitID: id, localDateKey: day)
    }

    /// The handler must ALSO check current local day, due schedule, archive
    /// state and an existing completion before performing any app-owned write.
    private static func isDayKey(_ key: String) -> Bool {
        guard key.utf8.count == 10 else { return false }
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...9999).contains(year) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return false }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        return resolved.year == year && resolved.month == month && resolved.day == day
    }
}
