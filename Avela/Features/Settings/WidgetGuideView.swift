import SwiftUI

struct WidgetGuideView: View {
    var body: some View {
        List {
            Section {
                Label("Log from your Home Screen", systemImage: "checkmark.circle")
                    .font(.headline)
                Text("Quick Log lets you check in without opening Avela. Adding a widget is optional and only needs to be done once.")
            }
            Section("Add Quick Log") {
                Text("1. Touch and hold an empty area of your Home Screen.")
                Text("2. Tap Edit, then Add Widget. On some iOS versions, tap the + button.")
                Text("3. Search for Avela and choose Avela Quick Log.")
                Text("4. Choose a size and tap Add Widget.")
            }
            Section("Use it") {
                Label("Tap Log to save a simple check-in here.", systemImage: "checkmark.circle")
                Label("Tap a habit name to open its details.", systemImage: "arrow.up.right")
                Label("Tap + to log an amount or duration in Avela.", systemImage: "plus.circle")
                Text("Checked rows stay in place briefly after logging. Undo and skipped-day changes are available in Avela. Your habit order follows Settings → Habit Order.")
            }
            Section("Routine widget") {
                Text("Create a routine in Avela first. Add the Routine widget, then touch and hold it → Edit Widget → choose your routine.")
                Text("It shows that routine's habits due today, in your step order. Log each step individually. Amounts and durations open Avela; a routine never logs everything at once.")
            }
            Section("Your privacy") {
                Text("Widget names and progress are visible on your Home Screen. Avoid personal names you wouldn't want others to see. The widget needs an unlocked device to log and never records audio or monitors other apps.")
                Text("After midnight, tap Refresh habits to update the list without opening Avela. If it still needs to refresh or retry, open Avela. Yesterday's snapshot cannot log today's check-in.")
            }
        }
        .navigationTitle("Home Screen Widgets")
        .navigationBarTitleDisplayMode(.inline)
        .appThemeCanvas()
        .accessibilityIdentifier("settings.widgetGuide")
    }
}
