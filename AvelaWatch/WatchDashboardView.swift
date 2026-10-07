import SwiftUI

struct WatchDashboardView: View {
    @Bindable var model: WatchDashboardModel

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    if let snapshot = model.snapshot, snapshot.isCurrent(at: Date()) {
                        if snapshot.habits.isEmpty { Text("No habits due today. Manage your habits on iPhone.") }
                        ForEach(snapshot.habits) { habit in
                            Button { model.log(habit) } label: {
                                HStack {
                                    Image(systemName: habit.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading) {
                                        Text(habit.name)
                                        Text(habit.isCompleted ? "Logged" : habit.supportsQuickLog ? "Log today" : "Progress on iPhone")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(habit.isCompleted || model.pendingHabitID != nil)
                            .accessibilityLabel(habit.name)
                            .accessibilityValue(habit.isCompleted ? "Logged today" : habit.supportsQuickLog ? "Not logged" : "Review progress on iPhone")
                            .accessibilityHint(habit.supportsQuickLog ? "Records success on your paired iPhone when its protected data is available. Undo is available in Avela on iPhone." : "Add measured progress in Avela on your iPhone.")
                        }
                        Text("Updated \(snapshot.generatedAt, style: .time). Keep your iPhone nearby to sync.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Enable Apple Watch in Avela Settings on your iPhone, then open Avela on both devices.")
                    }
                }
                Button(model.isRefreshing ? "Refreshing…" : "Refresh habits") { model.refresh() }
                    .disabled(model.isRefreshing || model.pendingHabitID != nil)
                Section("Simple timer") {
                    if let start = model.timerStartedAt {
                        Text(start, style: .timer).font(.title2.monospacedDigit())
                            .accessibilityLabel("Elapsed time")
                        Button("End timer", role: .destructive) { model.stopTimer() }
                    } else {
                        Button("Start timer") { model.startTimer() }
                    }
                    Text("Measures elapsed time only. No habit is completed automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Avela")
            .tint(Color(red: 0.24, green: 0.79, blue: 0.71))
            .alert("Avela", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                Button("OK") { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }
}
