import AppIntents
import SwiftUI

struct ShortcutsGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Log a habit or attention minutes with Siri, a shortcut button, or your own Apple Shortcuts automation.")
                ShortcutsLink()
            } header: { Text("Fewer Steps, Same Local Tracking") } footer: {
                Text("Create your habit or daily attention budget in Rilova first. These actions open Rilova and may ask you to unlock your device.")
            }
            Section("Try with Siri") {
                Label("Log a habit in Rilova", systemImage: "checkmark.circle")
                Text("Choose which habit when Siri asks. Success is logged for today; repeating the action won't undo it or add a duplicate.")
                Label("Log habit progress in Rilova", systemImage: "plus.circle")
                Text("Choose a quantity habit and the amount to add in its configured unit. Each run adds progress; reaching the target records one success. You can review or remove entries in Progress & History.")
                Label("Log attention in Rilova", systemImage: "hourglass")
                Text("Choose a daily budget and the minutes to add. Each run adds a separate self-reported entry. Correct an entry from that budget's detail screen.")
                    .accessibilityIdentifier("shortcuts.additiveExplanation")
            }
            Section("Make room, then do it") {
                Label("Make room for a habit in Rilova", systemImage: "timer")
                Text("Choose an existing habit and focus or phone-free session goal. The shortcut starts that session and links it to your habit. It never logs success, blocks apps or promises concentration.")
                    .accessibilityIdentifier("shortcuts.makeRoomExplanation")
                Text("In Shortcuts, you can combine Make Room with Apple's Set Focus action or run a saved shortcut with your Action button where supported. Choose your own Focus mode; it doesn't prove the habit was done.")
            }
            Section("Make Your Own Shortcut") {
                Text("In Apple Shortcuts, create a shortcut and add an Rilova action: Make Room for a Habit, Log Habit Success, Log Habit Progress or Log Attention Minutes. Select the habit or budget and save it with a name you'll remember.")
                Text("You can run your saved shortcut with Siri or add it to your Home Screen. Use Shortcuts' automation controls if you want an action to run after an event.")
            }
            Section("You're in Control") {
                Text("Voice logging is still your own report. Siri does not verify a habit or measure time spent in another app. Windows and phone-free session outcomes remain explicit check-ins inside Rilova.")
                Text("Rilova doesn't record audio. Apple handles Siri and Shortcuts. Selected goal names are available to those system features; completion feedback doesn't speak the name by default.")
            }
        }
        .appThemeCanvas()
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .task { AvelaShortcuts.updateAppShortcutParameters() }
        .accessibilityIdentifier("shortcuts.guide")
    }
}
