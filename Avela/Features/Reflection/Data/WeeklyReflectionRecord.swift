import Foundation
import SwiftData

@Model
final class WeeklyReflectionRecord {
    @Attribute(.unique) var weekKey: String
    var id: UUID
    var weekStart: Date
    var weekEnd: Date
    var timeZoneIdentifier: String
    var whatHelped: String
    var whatGotInTheWay: String
    var createdAt: Date
    var updatedAt: Date
    /// Lossless local recovery decoding; validation happens before insertion.
    init(backup row: BackupPayload.WeeklyReflectionRecordRow) {
        self.weekKey = row.weekKey
        self.id = row.id
        self.weekStart = row.weekStart
        self.weekEnd = row.weekEnd
        self.timeZoneIdentifier = row.timeZoneIdentifier
        self.whatHelped = row.whatHelped
        self.whatGotInTheWay = row.whatGotInTheWay
        self.createdAt = row.createdAt
        self.updatedAt = row.updatedAt
    }


    init(reflection: WeeklyReflection) {
        weekKey = reflection.week.key
        id = reflection.id
        weekStart = reflection.week.start
        weekEnd = reflection.week.end
        timeZoneIdentifier = reflection.week.timeZoneIdentifier
        whatHelped = reflection.whatHelped
        whatGotInTheWay = reflection.whatGotInTheWay
        createdAt = reflection.createdAt
        updatedAt = reflection.updatedAt
    }

    func domain() -> WeeklyReflection {
        WeeklyReflection(id: id, week: ReflectionWeek(key: weekKey, start: weekStart, end: weekEnd,
                                                     timeZoneIdentifier: timeZoneIdentifier),
                         whatHelped: whatHelped, whatGotInTheWay: whatGotInTheWay,
                         createdAt: createdAt, updatedAt: updatedAt)
    }
}
