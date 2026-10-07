import SwiftUI

struct MadeRoomReviewView: View {
    @Environment(\.appPalette) private var palette
    @State private var viewModel: MadeRoomReviewViewModel

    init(viewModel: MadeRoomReviewViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.weekLabel).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        .accessibilityIdentifier("madeRoom.week")
                    Text("Space for what matters").font(.title2.weight(.semibold))
                    Text("Linked sessions started this week, with independent habit check-ins.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button { viewModel.load() } label: { Text("Try Again").frame(minHeight: 44) }
                        .accessibilityIdentifier("madeRoom.retry")
                }
            } else if let review = viewModel.review {
                if review.habits.isEmpty {
                    Section {
                        Label("No Linked Sessions This Week", systemImage: "leaf")
                            .font(.headline).accessibilityIdentifier("madeRoom.empty")
                        Text("Link a session from Habit Detail → Make Room. This review is read-only.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Your intentions", systemImage: "checkmark.circle")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            Text("\(review.keptSessions) \(review.keptSessions == 1 ? "session" : "sessions") reported kept")
                                .font(.title2.weight(.semibold)).foregroundStyle(palette.accent)
                                .accessibilityIdentifier("madeRoom.keptSessions")
                            Text("\(review.interruptedSessions) \(review.interruptedSessions == 1 ? "session" : "sessions") reported interrupted")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("\(review.unreportedSessions) unfinished or unreported \(review.unreportedSessions == 1 ? "session" : "sessions")")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        Label {
                            Text("\(MadeRoomReviewViewModel.minutes(review.timerSeconds)) timer minutes")
                                .font(.body.weight(.medium))
                                .accessibilityIdentifier("madeRoom.timerMinutes")
                        } icon: {
                            Image(systemName: "timer").foregroundStyle(palette.accent)
                        }
                    } header: { Text("Recorded Session Results") } footer: {
                        Text("Ended sessions only. Timer minutes are not verified concentration, phone-free or saved time; outcomes are self-reported.")
                    }
                    Section {
                        ForEach(review.habits) { habit in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(habit.habitName).font(.headline)
                                Text("You made room for \(habit.habitName) \(habit.sessionCount) \(habit.sessionCount == 1 ? "time" : "times") this week.")
                                    .font(.subheadline)

                                if habit.isArchived { Text("Archived").font(.caption).foregroundStyle(.secondary) }
                                Text("\(habit.sessionCount) linked sessions · \(habit.keptSessions) reported kept")
                                    .font(.subheadline).foregroundStyle(palette.accent)
                                Text("\(habit.successfulCheckInDays) separate successful check-in days")
                                    .font(.subheadline)
                                Text("\(MadeRoomReviewViewModel.minutes(habit.timerSeconds)) timer minutes")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("madeRoom.habit.\(habit.id)")
                        }
                    } header: { Text("Habit Intentions") } footer: {
                        Text("Current names shown. Check-ins are independent records; sessions never complete a habit or establish what caused a check-in.")
                    }
                }
                if review.omittedLinkCount > 0 || review.omittedTimerCount > 0 {
                    Section {
                        Text("Some linked records or timer durations are unavailable or inconsistent and aren't included. These totals cover the available records only.")
                            .foregroundStyle(.secondary).accessibilityIdentifier("madeRoom.partial")
                    }
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("What I Made Room For")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }
}
