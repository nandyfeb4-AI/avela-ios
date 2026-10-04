import SwiftData
import XCTest
@testable import Avela

@MainActor
final class WidgetActionHandlerTests: XCTestCase {
    private var container: ModelContainer!

    private func fixture() throws -> (SwiftDataHabitRepository, Calendar, Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12))!
        container = try AppPersistence.makeContainer(inMemory: true)
        return (SwiftDataHabitRepository(modelContext: container.mainContext, calendar: calendar), calendar, date)
    }

    private func draft(schedule: HabitSchedule = .daily) -> HabitDraft {
        HabitDraft(name: "Walk", iconName: "figure.walk", category: .fitness, polarity: .positive, schedule: schedule)
    }

    func testCompletionIsAppOwnedIdempotentAndRetainsWidgetSource() throws {
        let (repository, calendar, date) = try fixture()
        let habit = try repository.createHabit(draft(), at: date)
        let handler = WidgetActionHandler(repository: repository, calendar: calendar)
        let url = WidgetDeepLink.complete(habitID: habit.id, localDateKey: LocalDay.key(for: date, calendar: calendar)).url
        XCTAssertEqual(try handler.handle(url, asOf: date), .completed(habit.id))
        XCTAssertEqual(try handler.handle(url, asOf: date), .alreadyCompleted(habit.id))
        let records = try repository.completions(for: habit.id, in: DateInterval(start: date.addingTimeInterval(-1), end: date.addingTimeInterval(1)))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].source, .widget)
    }

    func testStaleUnknownArchivedAndNonDueLinksDoNotWrite() throws {
        let (repository, calendar, date) = try fixture()
        let habit = try repository.createHabit(draft(), at: date)
        let nonDue = try repository.createHabit(draft(schedule: .weekdays([.monday])), at: date)
        let handler = WidgetActionHandler(repository: repository, calendar: calendar)
        let key = LocalDay.key(for: date, calendar: calendar)
        for link in [
            WidgetDeepLink.complete(habitID: habit.id, localDateKey: "2026-10-03"),
            .complete(habitID: UUID(), localDateKey: key),
            .complete(habitID: nonDue.id, localDateKey: key)
        ] {
            XCTAssertEqual(try handler.handle(link.url, asOf: date), .ignored)
        }
        try repository.archiveHabit(id: habit.id, at: date)
        XCTAssertEqual(try handler.handle(WidgetDeepLink.complete(habitID: habit.id, localDateKey: key).url, asOf: date), .ignored)
        XCTAssertTrue(try repository.completions(in: DateInterval(start: date.addingTimeInterval(-1), end: date.addingTimeInterval(1))).isEmpty)
    }

    func testExplicitWidgetCompletionReplacesSkip() throws {
        let (repository, calendar, date) = try fixture()
        let habit = try repository.createHabit(draft(), at: date)
        _ = try repository.recordSkip(habitID: habit.id, on: date, reason: nil)
        let handler = WidgetActionHandler(repository: repository, calendar: calendar)
        let key = LocalDay.key(for: date, calendar: calendar)
        XCTAssertEqual(try handler.handle(WidgetDeepLink.complete(habitID: habit.id, localDateKey: key).url, asOf: date), .completed(habit.id))
        let range = DateInterval(start: calendar.startOfDay(for: date), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!)
        XCTAssertTrue(try repository.skips(for: habit.id, in: range).isEmpty)
    }
}
