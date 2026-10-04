import Foundation

/// Shared presentation wording for completion actions/status, polarity-aware.
/// Purely textual — no scheduling or completion logic lives here.
///
/// A `positive` ("Build Up") habit's completion is naturally described as
/// "complete." An `avoidance` ("Cut Down") habit's completion must **not**
/// assume the user means total abstinence from something — a habit like
/// "Cut down on late snacking" or "Limit social media" can be satisfied by a
/// reduced amount, not just "I didn't do it at all." "Log success" (and its
/// undo/status counterparts) stays correct for both the strict-abstinence
/// case and the reduced-amount case, whereas "Mark avoided" or "Didn't do
/// it today" would misdescribe the latter.
enum HabitPolarityFormatter {
    /// The completion button's accessible action label (and, for `positive`
    /// habits, its visible wording already shown elsewhere) when the habit is
    /// not yet resolved for the current period.
    static func completionActionLabel(habitName: String, polarity: HabitPolarity) -> String {
        switch polarity {
        case .positive:
            return "Mark \(habitName) complete"
        case .avoidance:
            return "Log success for \(habitName)"
        }
    }

    /// The same action's label once the habit has already been resolved —
    /// tapping again undoes it.
    static func undoActionLabel(habitName: String, polarity: HabitPolarity) -> String {
        switch polarity {
        case .positive:
            return "Undo completion for \(habitName)"
        case .avoidance:
            return "Undo success for \(habitName)"
        }
    }

    /// A short status word/phrase for whether the current period is already
    /// resolved, used where the completion state is shown as text rather
    /// than (or in addition to) an icon.
    static func statusLabel(isCompleted: Bool, polarity: HabitPolarity) -> String {
        switch polarity {
        case .positive:
            return isCompleted ? "Completed" : "Not completed yet"
        case .avoidance:
            return isCompleted ? "Logged" : "Not logged yet"
        }
    }

    /// The undo toast's message when a habit is newly completed — shown only
    /// at the moment of completion, never for the row's own persistent
    /// status (that's `statusLabel`).
    static func toastMessage(habitName: String, polarity: HabitPolarity) -> String {
        switch polarity {
        case .positive:
            return "\(habitName) done"
        case .avoidance:
            return "Success logged for \(habitName)"
        }
    }
}
