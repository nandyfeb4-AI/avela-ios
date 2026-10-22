import Foundation
import Observation

struct HabitCalendarPlan: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date

    init(habitName: String, start: Date, minutes: Int, now: Date) throws {
        let name = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, minutes >= 1, minutes <= 180, start >= now else {
            throw HabitCalendarPlanError.invalidPlan
        }
        title = "Make room for \(name)"
        self.start = start
        end = start.addingTimeInterval(Double(minutes) * 60)
    }
}

enum HabitCalendarPlanError: Error { case invalidPlan }

@MainActor @Observable
final class HabitCalendarSchedulingModel {
    let habitName: String
    var start: Date { didSet { if start != oldValue { feedback = nil } } }
    var minutes: Int { didSet { if minutes != oldValue { feedback = nil } } }
    var plan: HabitCalendarPlan?
    var errorMessage: String?
    var feedback: String?

    init(habitName: String, suggestedMinutes: Double?, now: Date = Date()) {
        self.habitName = habitName
        start = now.addingTimeInterval(3600)
        let proposed = suggestedMinutes.flatMap { $0.isFinite ? $0 : nil } ?? 20
        minutes = Int(min(180, max(1, proposed)).rounded())
    }

    func prepare(now: Date = Date()) {
        feedback = nil
        plan = nil
        do {
            plan = try HabitCalendarPlan(habitName: habitName, start: start, minutes: minutes, now: now)
            errorMessage = nil
        } catch { errorMessage = "Choose a future start and a duration between 1 and 180 minutes." }
    }

    func finish(saved: Bool) {
        plan = nil
        feedback = saved ? "Added to Calendar. This is planned time; no session was started or habit logged." : nil
    }
}
