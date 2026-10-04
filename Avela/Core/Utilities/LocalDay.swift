import Foundation

/// Local calendar-day and calendar-week helpers shared by every feature that must
/// group facts (completions, skips, usage entries) by the user's local day or week
/// rather than by raw instant. All functions take an explicit `Calendar` so callers
/// control time zone and week-start behavior, and so tests can simulate travel or
/// daylight-saving transitions deterministically.
enum LocalDay {
    /// A stable Gregorian civil `yyyy-MM-dd` key in the supplied time zone.
    /// User calendar identifiers can change (e.g. Buddhist/Gregorian); using
    /// their year/month/day values would reorder historical snapshots and
    /// reinterpret stored dates. Week boundaries still use the user calendar.
    /// Computed once at write time and persisted as-is; it must not be recomputed
    /// later under a different time zone, or historical records would silently move
    /// to a different day.
    static func key(for date: Date, calendar: Calendar) -> String {
        var civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.timeZone = calendar.timeZone
        let components = civilCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            fatalError("Calendar could not resolve year/month/day for \(date).")
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// The local calendar week containing `date`, honoring `calendar.firstWeekday`.
    /// Uses `Calendar.dateInterval(of:for:)`, which accounts for daylight-saving
    /// transitions (a transition week is shorter or longer than 7×24 hours in
    /// elapsed time, but still spans the correct local calendar days).
    static func weekInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            fatalError("Calendar could not resolve a week interval for \(date).")
        }
        return interval
    }
}
