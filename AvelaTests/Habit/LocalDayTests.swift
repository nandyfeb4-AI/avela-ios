import Foundation
import XCTest
@testable import Avela

/// Exercises `LocalDay` directly against TESTING.md's required date/time scenarios:
/// local midnight boundary, week boundary, daylight saving transition, time-zone
/// change, and month/year boundary.
final class LocalDayTests: XCTestCase {
    private func calendar(timeZoneIdentifier: String, firstWeekday: Int = 1) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    func testLocalMidnightBoundarySeparatesCalendarDays() {
        let newYork = calendar(timeZoneIdentifier: "America/New_York")
        // 2024-06-14 23:59:30 and 2024-06-15 00:00:30 America/New_York.
        let justBeforeMidnight = Date(timeIntervalSince1970: 1_718_423_970)
        let justAfterMidnight = Date(timeIntervalSince1970: 1_718_424_030)

        XCTAssertEqual(LocalDay.key(for: justBeforeMidnight, calendar: newYork), "2024-06-14")
        XCTAssertEqual(LocalDay.key(for: justAfterMidnight, calendar: newYork), "2024-06-15")
    }

    func testWeekBoundarySeparatesConsecutiveWeeks() {
        let sundayStart = calendar(timeZoneIdentifier: "America/New_York", firstWeekday: 1)
        // Saturday 2024-06-15 and Sunday 2024-06-16, America/New_York, noon each.
        let saturday = Date(timeIntervalSince1970: 1_718_467_200)
        let sunday = Date(timeIntervalSince1970: 1_718_553_600)

        let saturdayWeek = LocalDay.weekInterval(containing: saturday, calendar: sundayStart)
        let sundayWeek = LocalDay.weekInterval(containing: sunday, calendar: sundayStart)

        XCTAssertNotEqual(saturdayWeek, sundayWeek)
        XCTAssertTrue(saturdayWeek.contains(saturday))
        XCTAssertFalse(saturdayWeek.contains(sunday))
        XCTAssertTrue(sundayWeek.contains(sunday))
        XCTAssertEqual(saturdayWeek.end, sundayWeek.start)
    }

    func testDaylightSavingSpringForwardKeepsConsistentLocalDayKeys() {
        let newYork = calendar(timeZoneIdentifier: "America/New_York")
        // US spring-forward 2024-03-10: 2:00 AM local clocks jump to 3:00 AM.
        let beforeTransition = Date(timeIntervalSince1970: 1_710_051_000) // 01:10 EST
        let afterTransition = Date(timeIntervalSince1970: 1_710_054_600) // 03:10 EDT

        XCTAssertEqual(LocalDay.key(for: beforeTransition, calendar: newYork), "2024-03-10")
        XCTAssertEqual(LocalDay.key(for: afterTransition, calendar: newYork), "2024-03-10")

        // The transition day's calendar week still spans 7 local calendar days
        // even though it contains only 23 hours of elapsed time.
        let week = LocalDay.weekInterval(containing: beforeTransition, calendar: newYork)
        let daysInWeek = newYork.dateComponents([.day], from: week.start, to: week.end).day
        XCTAssertEqual(daysInWeek, 7)
        XCTAssertLessThan(week.duration, 7 * 24 * 60 * 60)
    }

    func testDaylightSavingFallBackKeepsConsistentLocalDayKeys() {
        let newYork = calendar(timeZoneIdentifier: "America/New_York")
        // US fall-back 2024-11-03: clocks repeat 1:00-2:00 AM local time.
        let firstPass = Date(timeIntervalSince1970: 1_730_611_800) // 01:30 EDT (first occurrence)
        let secondPass = Date(timeIntervalSince1970: 1_730_615_400) // 01:30 EST (repeated hour)

        XCTAssertEqual(LocalDay.key(for: firstPass, calendar: newYork), "2024-11-03")
        XCTAssertEqual(LocalDay.key(for: secondPass, calendar: newYork), "2024-11-03")

        let week = LocalDay.weekInterval(containing: firstPass, calendar: newYork)
        XCTAssertGreaterThan(week.duration, 7 * 24 * 60 * 60)
    }

    func testTimeZoneChangeCanShiftTheLocalDayForTheSameInstant() {
        let newYork = calendar(timeZoneIdentifier: "America/New_York")
        let tokyo = calendar(timeZoneIdentifier: "Asia/Tokyo")
        // 2024-06-14 23:30 EDT is already 2024-06-15 12:30 PM JST.
        let instant = Date(timeIntervalSince1970: 1_718_422_200)

        XCTAssertEqual(LocalDay.key(for: instant, calendar: newYork), "2024-06-14")
        XCTAssertEqual(LocalDay.key(for: instant, calendar: tokyo), "2024-06-15")
    }

    func testMonthAndYearBoundaryProducesCorrectKeys() {
        let utc = calendar(timeZoneIdentifier: "UTC")
        let newYearsEve = Date(timeIntervalSince1970: 1_704_024_000) // 2023-12-31 12:00 UTC
        let newYearsDay = Date(timeIntervalSince1970: 1_704_110_400) // 2024-01-01 12:00 UTC

        XCTAssertEqual(LocalDay.key(for: newYearsEve, calendar: utc), "2023-12-31")
        XCTAssertEqual(LocalDay.key(for: newYearsDay, calendar: utc), "2024-01-01")
    }
    func testCivilDayKeysRemainStableAcrossUserCalendarIdentifiers() {
        let instant = Date(timeIntervalSince1970: 1_718_632_800) // 2024-06-17 10:00 New York
        let identifiers: [Calendar.Identifier] = [.gregorian, .buddhist, .japanese, .islamicUmmAlQura]
        for identifier in identifiers {
            var calendar = Calendar(identifier: identifier)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            XCTAssertEqual(LocalDay.key(for: instant, calendar: calendar), "2024-06-17", "\(identifier)")
        }
    }

    func testCivilNormalizationPreservesTimeZoneAndUserWeekBoundaries() {
        let instant = Date(timeIntervalSince1970: 1_718_422_200) // Jun 14 23:30 New York / Jun 15 Tokyo
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "America/New_York")!
        buddhist.firstWeekday = 2
        XCTAssertEqual(LocalDay.key(for: instant, calendar: buddhist), "2024-06-14")
        XCTAssertEqual(LocalDay.weekInterval(containing: instant, calendar: buddhist),
                       buddhist.dateInterval(of: .weekOfYear, for: instant))
        buddhist.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(LocalDay.key(for: instant, calendar: buddhist), "2024-06-15")
    }

}
