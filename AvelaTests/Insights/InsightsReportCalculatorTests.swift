import XCTest
@testable import Avela

final class InsightsReportCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/New_York")!
        value.locale = Locale(identifier: "en_US_POSIX")
        value.firstWeekday = 1
        return value
    }
    private func date(_ key: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: key + " 12:00")!
    }
    private var end: Date { calendar.startOfDay(for: date("2024-06-23")) }
    private var now: Date { date("2024-06-26") }
    private func habit(_ name: String, schedule: HabitSchedule = .daily, start: String = "2024-06-16") -> Habit {
        Habit(id: UUID(), name: name, iconName: "book", category: .learning, polarity: .positive,
              schedule: schedule, createdAt: date(start), updatedAt: date(start), archivedAt: nil, sortOrder: 0)
    }
    private func snapshot(_ habit: Habit, schedule: HabitSchedule? = nil, on day: String? = nil, revision: Int = 0) -> HabitConfigurationSnapshot {
        HabitConfigurationSnapshot(id: UUID(), habitID: habit.id, polarity: .positive, schedule: schedule ?? habit.schedule,
            effectiveLocalDateKey: day ?? LocalDay.key(for: habit.createdAt, calendar: calendar), revision: revision, createdAt: habit.createdAt)
    }
    private func completion(_ habit: Habit, day: String) -> Completion {
        Completion(id: UUID(), habitID: habit.id, occurredAt: date(day), localDateKey: day, source: .app, note: nil)
    }
    private func entry(_ habit: Habit, day: String, amount: Int, unit: HabitQuantityUnit?, kind: HabitActivityKind = .quantity, loggedAt: Date? = nil) -> HabitActivityEntry {
        HabitActivityEntry(id: UUID(), habitID: habit.id, configurationID: UUID(), dayKey: day, loggedAt: loggedAt ?? date(day), kind: kind, amount: amount, unit: unit, description: "")
    }
    private func report(_ habits: [Habit], snapshots: [UUID: [HabitConfigurationSnapshot]]? = nil,
                        completions: [Completion] = [], skips: [Skip] = [], entries: [HabitActivityEntry] = [],
                        sessions: [AttentionSession] = [], archives: [UUID: [HabitArchivePeriod]] = [:],
                        reviewEnd: Date? = nil) -> InsightsReportCalculator.Report {
        InsightsReportCalculator.calculate(habits: habits,
            snapshots: snapshots ?? Dictionary(uniqueKeysWithValues: habits.map { ($0.id, [snapshot($0)]) }),
            archives: archives, completions: completions, skips: skips, entries: entries, sessions: sessions,
            reviewEnd: reviewEnd ?? end, asOf: now, calendar: calendar)
    }

    func testTwelveCivilWeeksIncludeDSTAndEndExactlyAtSelectedCompletedWeek() {
        let result = report([])
        XCTAssertEqual(result.weeks.count, 12)
        XCTAssertEqual(result.weeks.last?.interval.end, end)
        XCTAssertEqual(result.weeks.first?.interval.start, calendar.date(byAdding: .weekOfYear, value: -12, to: end))
        XCTAssertTrue(result.weeks.allSatisfy { $0.consistency == nil }, "no habits is unknown, never a measured zero")
        let marchEnd = calendar.startOfDay(for: date("2024-03-17"))
        let march = report([], reviewEnd: marchEnd)
        let transitionWeek = march.weeks.last!
        XCTAssertEqual(transitionWeek.interval.duration, 7 * 86400 - 3600, "the seven civil days span spring forward")
        XCTAssertEqual(calendar.dateComponents([.day], from: transitionWeek.interval.start, to: transitionWeek.interval.end).day, 7)
    }

    func testWeeklyBarsAgreeWithExistingEqualWeightCalculatorAndDoNotPoolUnits() throws {
        let daily = habit("Read")
        let weekly = habit("Walk", schedule: .timesPerWeek(3))
        let completions = (16...22).map { completion(daily, day: "2024-06-\($0)") }
        let result = report([daily, weekly], completions: completions)
        XCTAssertEqual(try XCTUnwrap(result.weeks.last?.consistency), 0.5, accuracy: 0.00001)
        XCTAssertEqual(result.weeks.last?.eligibleHabitIDs, [daily.id, weekly.id])
        let legacy = WeeklyInsightsCalculator.weeklyInsights(habits: [daily, weekly],
            snapshotsByHabitID: [daily.id: [snapshot(daily)], weekly.id: [snapshot(weekly)]],
            completions: completions, skips: [], archivePeriodsByHabitID: [:],
            weekInterval: DateInterval(start: calendar.startOfDay(for: date("2024-06-16")), end: end),
            previousWeekInterval: DateInterval(start: calendar.startOfDay(for: date("2024-06-09")), end: calendar.startOfDay(for: date("2024-06-16"))),
            asOf: now, calendar: calendar)
        XCTAssertEqual(result.weeks.last?.consistency, legacy.overallConsistency)
    }

    func testCohortChangesAreFlaggedAndMissingWeeksStayMissing() {
        let original = habit("Read", start: "2024-06-02")
        let added = habit("Walk", start: "2024-06-16")
        let result = report([original, added])
        XCTAssertNil(result.weeks.first?.consistency)
        XCTAssertEqual(result.weeks.last?.consistency, 0)
        XCTAssertEqual(result.weeks.last?.cohortChanged, true)
        XCTAssertEqual(result.weeks.dropLast().last?.eligibleHabitIDs, [original.id])
    }

    func testWeekdayCountsExcludeWeeklyCommitmentsAndExcusedSkips() {
        let daily = habit("Read")
        let weekly = habit("Walk", schedule: .timesPerWeek(3))
        let skip = Skip(id: UUID(), habitID: daily.id, localDateKey: "2024-06-17", reason: .travel, createdAt: date("2024-06-17"))
        let result = report([daily, weekly], completions: [completion(daily, day: "2024-06-18"), completion(weekly, day: "2024-06-18")], skips: [skip])
        XCTAssertEqual(result.weekdays.reduce(0) { $0 + $1.resolved }, 6)
        XCTAssertEqual(result.weekdays.reduce(0) { $0 + $1.successes }, 1)
        XCTAssertNil(result.weekdays.first { $0.number == 2 }?.consistency, "the excused Monday has no resolved opportunity")
    }

    func testUnitChangesAndBackdatedAmountsStaySeparateAndDuplicateFactsCountOnce() throws {
        let read = habit("Read")
        let pages = entry(read, day: "2024-06-18", amount: 12, unit: .pages, loggedAt: now)
        let minutes = entry(read, day: "2024-06-18", amount: 5, unit: .minutes, loggedAt: now)
        let invalid = entry(read, day: "2024-06-18", amount: -9, unit: .pages)
        let smaller = entry(read, day: "2024-06-19", amount: 1, unit: nil, kind: .smallerAction)
        let result = report([read], entries: [pages, pages, minutes, invalid, smaller])
        XCTAssertEqual(result.quantities.count, 2)
        XCTAssertEqual(result.quantities.first { $0.unit == .pages }?.total, 12)
        XCTAssertEqual(result.quantities.first { $0.unit == .minutes }?.total, 5)
        XCTAssertEqual(result.quantities.first { $0.unit == .pages }?.weeks.last?.amount, 12, "membership uses stored civil day, not later logging timestamp")
        XCTAssertEqual(result.recordedDays, 2)
        XCTAssertEqual(try XCTUnwrap(result.activityDays.first { $0.key == "2024-06-18" }).quantityEntryCount, 2)
        XCTAssertEqual(result.weeks.last?.consistency, 0, "partial amounts and smaller actions never create full success")
    }

    func testActivityMapSeparatesRecordedExcusedPausedPreTrackingAndAfterReview() throws {
        var read = habit("Read")
        read.archivedAt = date("2024-06-20")
        let skip = Skip(id: UUID(), habitID: read.id, localDateKey: "2024-06-18", reason: nil, createdAt: date("2024-06-18"))
        let own = completion(read, day: "2024-06-17")
        let after = completion(read, day: "2024-06-24")
        let result = report([read], completions: [own, own, after], skips: [skip])
        func state(_ day: String) throws -> InsightsReportCalculator.ActivityDay.State {
            try XCTUnwrap(result.activityDays.first { $0.key == day }).state
        }
        XCTAssertEqual(try state("2024-01-01"), .beforeTracking)
        XCTAssertEqual(try state("2024-06-16"), .noRecord)
        XCTAssertEqual(try state("2024-06-17"), .recorded)
        XCTAssertEqual(try state("2024-06-18"), .skipped)
        XCTAssertEqual(try state("2024-06-21"), .paused)
        XCTAssertEqual(try state("2024-06-24"), .afterReview)
        XCTAssertEqual(result.recordedDays, 1, "later current-week activity does not enter this completed review's year total")
        XCTAssertEqual(result.activityDays.first { $0.key == "2024-06-17" }?.checkInCount, 1)
        XCTAssertEqual(result.activityDays.count, 366, "leap year is civil-calendar correct")
    }

    func testSessionCountsSeparateOutcomesAndExcludeActiveTimerMinutes() throws {
        let goal = UUID()
        func session(_ start: String, ended: Date?, outcome: AttentionCheckInOutcome?) -> AttentionSession {
            let startedAt = date(start)
            return AttentionSession(id: UUID(), attentionGoalID: goal, startedAt: startedAt, expectedEnd: startedAt.addingTimeInterval(1800), targetMinutes: 30, endedAt: ended, outcome: outcome)
        }
        let kept = session("2024-06-17", ended: date("2024-06-17").addingTimeInterval(1800), outcome: .kept)
        let interrupted = session("2024-06-18", ended: date("2024-06-18").addingTimeInterval(600), outcome: .interrupted)
        let active = session("2024-06-19", ended: nil, outcome: nil)
        let outside = session("2024-06-24", ended: nil, outcome: nil)
        let result = report([], sessions: [kept, kept, interrupted, active, outside])
        let week = try XCTUnwrap(result.sessions.last)
        XCTAssertEqual(week.started, 3)
        XCTAssertEqual(week.kept, 1)
        XCTAssertEqual(week.interrupted, 1)
        XCTAssertEqual(week.unreported, 1)
        XCTAssertEqual(week.timerMinutes, 40, accuracy: 0.001)
        XCTAssertTrue(result.hasSessions)
        XCTAssertEqual(result.recordedDays, 0, "sessions cannot manufacture habit activity")
    }

    func testStoredCivilDayIsPreservedEvenWhenTimestampFallsInAnotherLocalDay() {
        let read = habit("Read")
        let traveled = Completion(id: UUID(), habitID: read.id, occurredAt: date("2024-06-19"), localDateKey: "2024-06-18", source: .app, note: nil)
        let result = report([read], completions: [traveled])
        XCTAssertEqual(result.activityDays.first { $0.key == "2024-06-18" }?.state, .recorded)
        XCTAssertEqual(result.activityDays.first { $0.key == "2024-06-19" }?.state, .noRecord)
    }

    func testAChangedHistoricalScheduleMatchesLegacyBarAndFlagsTheChange() {
        let read = habit("Read", start: "2024-06-02")
        let snapshots = [snapshot(read), snapshot(read, schedule: .timesPerWeek(2), on: "2024-06-19", revision: 1)]
        let result = report([read], snapshots: [read.id: snapshots], completions: [completion(read, day: "2024-06-20"), completion(read, day: "2024-06-21")])
        // Three daily misses plus one met weekly unit; never seven imagined days.
        XCTAssertEqual(result.weeks.last?.consistency, 0.25)
        XCTAssertEqual(result.weeks.last?.cohortChanged, true)
        XCTAssertEqual(result.weekdays.reduce(0) { $0 + $1.resolved }, 17)
    }
    func testFutureWrittenHistoricalSkipCannotChangeAnEarlierAsOfReport() throws {
        let read = habit("Read")
        let recorded = completion(read, day: "2024-06-17")
        let futureWrittenSkip = Skip(id: UUID(), habitID: read.id, localDateKey: "2024-06-18", reason: .travel, createdAt: date("2024-06-27"))
        let earlier = report([read], completions: [recorded], skips: [futureWrittenSkip])
        let withoutFutureWrite = report([read], completions: [recorded])
        XCTAssertEqual(earlier, withoutFutureWrite, "A fact written after the evaluation instant cannot alter its commitments, weekday counts or activity map")
        XCTAssertEqual(try XCTUnwrap(earlier.weeks.last?.consistency), 1.0 / 7, accuracy: 0.00001)
        XCTAssertEqual(earlier.activityDays.first { $0.key == "2024-06-18" }?.state, .noRecord)
        let alreadyWrittenSkip = Skip(id: futureWrittenSkip.id, habitID: read.id, localDateKey: "2024-06-18", reason: .travel, createdAt: now)
        let current = report([read], completions: [recorded], skips: [alreadyWrittenSkip])
        XCTAssertEqual(try XCTUnwrap(current.weeks.last?.consistency), 1.0 / 6, accuracy: 0.00001)
        XCTAssertEqual(current.activityDays.first { $0.key == "2024-06-18" }?.state, .skipped)
    }

}
