import SwiftUI

struct IntentionSessionView: View {
    @State private var viewModel: IntentionSessionViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.sessionLiveActivityService) private var liveActivityService
    @Environment(\.habitActivityRepository) private var activityRepository
    @Environment(\.attentionGoalCreationAllowed) private var creationAllowed
    @State private var showingCreateGoal = false
    @State private var showingHabitLog = false
    @State private var showsInIsland = false
    @State private var activityMessage: String?

    init(viewModel: IntentionSessionViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        List {
            Section("Make room for") {
                Text(viewModel.habitName).font(.headline)
                Text("Choose time to focus on this habit. A focus session allows phone use; a phone-free session is an intention to step away. Neither blocks apps or completes the habit.")
                    .foregroundStyle(.secondary)
            }
            if let memory = viewModel.whyMemory, viewModel.habitAvailable {
                Section("Why this matters") {
                    Text(memory).accessibilityIdentifier("intentionSession.whyMemory")
                    Button("Hide this reminder") { viewModel.hideWhyMemory() }
                        .accessibilityIdentifier("intentionSession.hideWhyMemory")
                }
            }
            if !viewModel.habitAvailable {
                Section { Text("This habit is unavailable or archived. Its earlier intentions remain below.") }
            } else if viewModel.goals.isEmpty {
                Section("Make a little space") {
                    Text("Create a focus session here. Choose a phone-free session instead if you want a break from your phone.")
                        .foregroundStyle(.secondary)
                    Button("Create Session Goal", systemImage: "plus.circle") { showingCreateGoal = true }
                        .accessibilityIdentifier("intentionSession.createGoal")
                }
            } else {
                Section("Choose your session") {
                    Picker("Session goal", selection: $viewModel.selectedGoalID) {
                        ForEach(viewModel.goals) { goal in Text("\(goal.name) · \(goal.type.label)").tag(Optional(goal.id)) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("intentionSession.goalPicker")
                    if let minutes = viewModel.selectedTargetMinutes {
                        Text("\(minutes.formatted()) minute target")
                    }
                    Text(viewModel.selectedSessionType == .focusSession ? "Using your phone is allowed. Elapsed time never verifies concentration or completes this habit." : "Intend to stay off your phone. Avela does not block or monitor other apps; elapsed time never proves you stayed phone-free.")
                        .font(.callout).foregroundStyle(.secondary)
                    if liveActivityService != nil {
                        Toggle("Show mascot & timer in Dynamic Island", isOn: $showsInIsland)
                            .accessibilityIdentifier("intentionSession.islandToggle")
                        Text("Also appears on the Lock Screen where supported. You can hide it without ending the session.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button(viewModel.selectedSessionType == .focusSession ? "Start Focus Session" : "Start Phone-Free Session") {
                        let started = viewModel.start()
                        if started, showsInIsland, let id = viewModel.startedSessionID, let liveActivityService {
                            do {
                                try liveActivityService.show(sessionID: id)
                                activityMessage = "Session activity requested. Go Home to see it where supported."
                                Task { await liveActivityService.synchronize() }
                            } catch {
                                activityMessage = "The session is saved, but its Live Activity couldn't be shown. Open Session & Check In to retry."
                            }
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.selectedGoalID == nil)
                        .accessibilityIdentifier("intentionSession.start")
                    Button("Create Another Session Goal", systemImage: "plus.circle") { showingCreateGoal = true }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("intentionSession.createGoal")
                }
            }
            if let activityMessage {
                Section { Text(activityMessage).accessibilityIdentifier("intentionSession.activityMessage") }
            }
            if let goalID = viewModel.startedSessionGoalID {
                Section("Your session") {
                    NavigationLink("Open Session & Check In") {
                        AttentionWindowDetailView(viewModel: viewModel.detailModel(goalID: goalID))
                    }
                    .accessibilityIdentifier("intentionSession.openStarted")
                    Text("Check in on your session, then log what you actually did separately. Ending the timer never supplies a habit quantity or marks success.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            if viewModel.habitAvailable, activityRepository != nil, !viewModel.history.isEmpty {
                Section("Do it, then record it") {
                    Button("Log What I Did", systemImage: "checkmark.circle") { showingHabitLog = true }
                        .accessibilityIdentifier("intentionSession.logHabit")
                    Text("Use the habit's normal check-in or quantity logger. Session time is never imported as habit progress.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !viewModel.history.isEmpty {
                if viewModel.currentWeekSessionCount > 0 {
                    Section("Time you made room") {
                        Text("You made room for \(viewModel.habitName) \(viewModel.currentWeekSessionCount) \(viewModel.currentWeekSessionCount == 1 ? "time" : "times") this week.")
                            .accessibilityIdentifier("intentionSession.weeklyConnection")
                        Text("Recorded session starts, independent of session outcomes and habit check-ins.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Linked sessions") {
                    ForEach(viewModel.history) { row in
                        NavigationLink {
                            AttentionWindowDetailView(viewModel: viewModel.detailModel(goalID: row.session.attentionGoalID))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.goalName).font(.headline)
                                Text(row.session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text("\(row.session.targetMinutes.formatted()) min target · \(row.outcomeLabel)")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("Make Room")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.creationAllowed = creationAllowed; viewModel.load() }
        .sheet(isPresented: $showingCreateGoal) {
            AttentionGoalFormView(defaultType: .focusSession, defaultName: "Focus for \(viewModel.habitName)", sessionOnly: true) { draft in
                viewModel.createSessionGoal(draft)
                showingCreateGoal = false
            }
        }
        .sheet(isPresented: $showingHabitLog, onDismiss: { viewModel.load() }) {
            if let activityRepository {
                HabitActivityView(habitID: viewModel.habitID, repository: activityRepository, habits: viewModel.habitsRepository)
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
        .alert("Session Update", isPresented: Binding(get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
    }
}

private struct AttentionGoalCreationAllowedKey: EnvironmentKey {
    static let defaultValue: (Int) -> Bool = { PremiumAccessPolicy.canCreateAttentionGoal(activeCount: $0, hasPremium: false) }
}
private struct AttentionIntentionRepositoryKey: EnvironmentKey { static let defaultValue: AttentionRepository? = nil }
private struct IntentionLinkRepositoryKey: EnvironmentKey { static let defaultValue: IntentionSessionLinkRepository? = nil }
extension EnvironmentValues {
    var attentionGoalCreationAllowed: (Int) -> Bool {
        get { self[AttentionGoalCreationAllowedKey.self] }
        set { self[AttentionGoalCreationAllowedKey.self] = newValue }
    }
    var attentionIntentionRepository: AttentionRepository? {
        get { self[AttentionIntentionRepositoryKey.self] }
        set { self[AttentionIntentionRepositoryKey.self] = newValue }
    }
    var intentionLinkRepository: IntentionSessionLinkRepository? {
        get { self[IntentionLinkRepositoryKey.self] }
        set { self[IntentionLinkRepositoryKey.self] = newValue }
    }
}
