import EventKit
import EventKitUI
import SwiftUI

struct HabitCalendarSchedulingView: View {
    @State private var model: HabitCalendarSchedulingModel
    @Environment(\.dismiss) private var dismiss

    init(habitName: String, suggestedMinutes: Double?) {
        _model = State(initialValue: HabitCalendarSchedulingModel(habitName: habitName, suggestedMinutes: suggestedMinutes))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(model.habitName).font(.headline)
                    Text("Protect a little time for this habit. Your calendar event is a plan, not a completed habit or a running session.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    DatePicker("Start", selection: $model.start, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("calendar.start")
                    Stepper("\(model.minutes) minutes", value: $model.minutes, in: 1...180)
                        .accessibilityIdentifier("calendar.duration")
                    Button("Review in Calendar", systemImage: "calendar.badge.plus") { model.prepare() }
                        .accessibilityIdentifier("calendar.review")
                } header: { Text("Your time") } footer: {
                    Text("Choose the calendar and review the title in Apple's editor before saving. The habit name will be visible to anyone who can access that calendar. Your private reason and tracking history aren't included. Rilova doesn't read your calendar.")
                }
                if let feedback = model.feedback {
                    Section { Text(feedback).accessibilityIdentifier("calendar.saved") }
                }
            }
            .appThemeCanvas()
            .navigationTitle("Plan Time").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $model.plan) { plan in
                HabitCalendarEditor(plan: plan) { saved in model.finish(saved: saved) }
                    .ignoresSafeArea()
            }
            .alert("Check Your Plan", isPresented: Binding(get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        }
    }
}

/// The system editor saves only after the user's explicit action. On iOS 17+
/// this UI needs no calendar authorization and grants Avela no calendar read access.
private struct HabitCalendarEditor: UIViewControllerRepresentable {
    let plan: HabitCalendarPlan
    let finished: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let editor = EKEventEditViewController()
        editor.eventStore = context.coordinator.store
        let event = EKEvent(eventStore: context.coordinator.store)
        event.title = plan.title
        event.startDate = plan.start
        event.endDate = plan.end
        editor.event = event
        editor.editViewDelegate = context.coordinator
        return editor
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let store = EKEventStore()
        let finished: (Bool) -> Void
        init(finished: @escaping (Bool) -> Void) { self.finished = finished }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            finished(action == .saved)
        }
    }
}
