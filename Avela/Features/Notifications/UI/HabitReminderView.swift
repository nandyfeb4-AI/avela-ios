import SwiftUI
import UIKit

struct HabitReminderView: View {
    @State private var viewModel: HabitReminderViewModel
    let schedule: HabitSchedule
    @Environment(\.openURL) private var openURL

    init(habitID: UUID, schedule: HabitSchedule, service: HabitReminderService) {
        _viewModel = State(initialValue: HabitReminderViewModel(habitID: habitID, service: service))
        self.schedule = schedule
    }

    var body: some View {
        @Bindable var model = viewModel
        Form {
            Section {
                Toggle("Enable reminder", isOn: $model.isEnabled)
                    .disabled(model.isSaving)
                    .accessibilityIdentifier("habitReminder.enabled")
                if model.isEnabled {
                    DatePicker("Reminder time", selection: $model.time, displayedComponents: .hourAndMinute)
                        .disabled(model.isSaving)
                        .accessibilityIdentifier("habitReminder.time")
                }
            } footer: {
                Text(scheduleDescription)
            }
            Section {
                Text("Press and hold a reminder, then choose Review & log. Rilova shows the habit before you confirm success. Opening the reminder alone never logs anything.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if model.isEnabled && model.permission == .denied {
                Section {
                    Text("Notifications are turned off for Rilova. Allow notifications in Settings to receive reminders. You can keep using Rilova without them.")
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .accessibilityIdentifier("habitReminder.openSettings")
                }
            }
            Section {
                Button {
                    Task {
                        await model.save()
                        if model.didSave {
                            UIAccessibility.post(notification: .announcement, argument: "Reminder saved.")
                        }
                    }
                } label: {
                    if model.didSave {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                    } else {
                        Text(model.isSaving ? "Saving…" : "Save Reminder")
                    }
                }
                .disabled(model.isSaving)
                .accessibilityLabel(model.didSave ? "Reminder saved" : model.isSaving ? "Saving reminder" : "Save Reminder")
                .accessibilityIdentifier("habitReminder.save")
            }
        }
        .appThemeCanvas()
        .navigationTitle("Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .alert("Reminder Couldn’t Be Updated", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }

    private var scheduleDescription: String {
        switch schedule {
        case .daily: return "A gentle reminder at your chosen local time each day."
        case .weekdays: return "A reminder on this habit's scheduled weekdays, at your chosen local time."
        case .timesPerWeek: return "A daily nudge toward your flexible weekly goal. You don't need to complete it every day."
        }
    }
}
