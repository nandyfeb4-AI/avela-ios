import Foundation
import SwiftData
import XCTest
@testable import Avela

@MainActor
final class WatchHabitLoggingServiceTests: XCTestCase {
    private var container: ModelContainer?
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Denver")!
        return value
    }
    private let now = Date(timeIntervalSince1970: 1_718_632_800)

    private func repository() throws -> SwiftDataHabitRepository {
        let value = try AppPersistence.makeContainer(inMemory: true)
        container = value
        return SwiftDataHabitRepository(modelContext: value.mainContext, calendar: calendar)
    }
    private func habit(_ repository: SwiftDataHabitRepository, schedule: HabitSchedule = .daily) throws -> Habit {
        try repository.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning,
                                              polarity: .positive, schedule: schedule), at: now)
    }
    private func request(_ habit: Habit, day: String? = nil) -> WatchHabitLogRequest {
        WatchHabitLogRequest(protocolVersion: 1, habitID: habit.id,
                             localDateKey: day ?? LocalDay.key(for: now, calendar: calendar))
    }

    func testExplicitLogIsIdempotentAndHasWatchProvenance() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: true).status, .logged)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: true).status, .alreadyLogged)
        let entries = try repository.completions(for: habit.id, in: DateInterval(start: now.addingTimeInterval(-1), duration: 2))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, .watch)
    }

    func testUnavailableProtectedPhoneDataCannotLog() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: false).status, .openPhone)
        XCTAssertFalse(try XCTUnwrap(service.snapshot(at: now).habits.first).isCompleted)
    }

    func testStaleDayCannotLogTodaysHabit() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        XCTAssertEqual(service.log(request(habit, day: "2024-06-16"), at: now, phoneAvailable: true).status, .staleDay)
        XCTAssertFalse(try XCTUnwrap(service.snapshot(at: now).habits.first).isCompleted)
    }

    func testArchivedHabitCannotBeLoggedFromOldSnapshot() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        XCTAssertEqual(try service.snapshot(at: now).habits.count, 1)
        try repository.archiveHabit(id: habit.id, at: now)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: true).status, .unavailable)
        XCTAssertTrue(try service.snapshot(at: now).habits.isEmpty)
    }

    func testNonDueAndUnknownHabitCannotLog() throws {
        let repository = try repository()
        let habit = try habit(repository, schedule: .weekdays([.sunday])) // anchor is Monday
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: true).status, .unavailable)
        XCTAssertEqual(service.log(WatchHabitLogRequest(protocolVersion: 1, habitID: UUID(),
                                                       localDateKey: LocalDay.key(for: now, calendar: calendar)),
                                   at: now, phoneAvailable: true).status, .unavailable)
        XCTAssertTrue(try service.snapshot(at: now).habits.isEmpty)
    }

    func testWatchDoesNotReplaceExcusedSkip() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        try repository.recordSkip(habitID: habit.id, on: now, reason: .planned)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: true).status, .unavailable)
        XCTAssertTrue(try service.snapshot(at: now).habits.isEmpty)
        XCTAssertEqual(try repository.skips(for: habit.id, in: DateInterval(start: now.addingTimeInterval(-86400), duration: 172800)).count, 1)
    }

    func testQuantityHabitRequiresPhoneProgressInsteadOfFakeCompletion() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar, supportsQuickLog: { _ in false })
        XCTAssertFalse(try XCTUnwrap(service.snapshot(at: now).habits.first).supportsQuickLog)
        XCTAssertEqual(service.log(request(habit), at: now, phoneAvailable: true).status, .unavailable)
        XCTAssertFalse(try XCTUnwrap(service.snapshot(at: now).habits.first).isCompleted)
    }

    func testProtocolMismatchCannotWrite() throws {
        let repository = try repository()
        let habit = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        let request = WatchHabitLogRequest(protocolVersion: 2, habitID: habit.id,
                                          localDateKey: LocalDay.key(for: now, calendar: calendar))
        XCTAssertEqual(service.log(request, at: now, phoneAvailable: true).status, .staleDay)
        XCTAssertFalse(try XCTUnwrap(service.snapshot(at: now).habits.first).isCompleted)
    }

    func testSnapshotExpiryUsesCalendarMidnightAcrossDST() throws {
        let repository = try repository()
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        // Denver spring-forward day lasts 23 elapsed hours, not 24.
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 10)))
        let snapshot = try service.snapshot(at: start)
        XCTAssertEqual(snapshot.expiresAt.timeIntervalSince(start), 23 * 3600)
        XCTAssertEqual(snapshot.localDateKey, "2024-03-10")
        XCTAssertFalse(snapshot.isCurrent(at: start.addingTimeInterval(23 * 3600)))
    }

    func testPayloadRoundTripsAndExpiresExactlyAtLocalMidnight() throws {
        let repository = try repository()
        _ = try habit(repository)
        let service = WatchHabitLoggingService(repository: repository, calendar: calendar)
        let snapshot = try service.snapshot(at: now)
        XCTAssertEqual(try JSONDecoder().decode(WatchHabitSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
        XCTAssertTrue(snapshot.isCurrent(at: snapshot.expiresAt.addingTimeInterval(-1)))
        XCTAssertFalse(snapshot.isCurrent(at: snapshot.expiresAt))
        XCTAssertEqual(calendar.component(.hour, from: snapshot.expiresAt), 0)
    }
}
