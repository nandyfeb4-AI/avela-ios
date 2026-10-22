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
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: habit.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .frame(width: 24, alignment: .center)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(habit.name).font(.headline)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(model.pendingHabitID == habit.id ? "Logging…" : habit.isCompleted ? "Logged" : habit.supportsQuickLog ? "Log today" : "Progress on iPhone")
                                            .font(.caption).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .disabled(habit.isCompleted || !habit.supportsQuickLog || model.pendingHabitID != nil)
                            .accessibilityLabel(habit.name)
                            .accessibilityValue(model.pendingHabitID == habit.id ? "Logging on iPhone" : habit.isCompleted ? "Logged today" : habit.supportsQuickLog ? "Not logged" : "Review progress on iPhone")
                            .accessibilityHint(habit.supportsQuickLog ? "Records success on your paired iPhone when its protected data is available. Undo is available in Rilova on iPhone." : "Add measured progress in Rilova on your iPhone.")
                        }
                        Text("Updated \(snapshot.generatedAt, style: .time). Keep your iPhone nearby to sync.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Enable Apple Watch in Rilova Settings on your iPhone, then open Rilova on both devices.")
                    }
                }
                if let confirmation = model.confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.caption).accessibilityIdentifier("watch.confirmation")
                }
                Button(model.isRefreshing ? "Refreshing…" : "Refresh habits") { model.refresh() }
                    .disabled(model.isRefreshing || model.pendingHabitID != nil)
                Section("Simple timer") {
                    if let start = model.timerStartedAt {
                        Text(start, style: .timer).font(.title2.weight(.semibold)).fontDesign(.rounded).monospacedDigit()
                            .accessibilityLabel("Elapsed time")
                        Button("End timer", role: .destructive) { model.stopTimer() }
                    } else {
                        Button("Start timer") { model.startTimer() }
                    }
                    Text("Measures elapsed time only. No habit is completed automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Rilova")
            .tint(Color(red: 0.24, green: 0.79, blue: 0.71))
            .alert("Rilova", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                Button("OK") { model.message = nil }
            } message: { Text(model.message ?? "") }
        }
    }
}
