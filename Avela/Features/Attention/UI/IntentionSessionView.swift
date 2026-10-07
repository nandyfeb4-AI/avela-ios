import SwiftUI

struct IntentionSessionView: View {
    @State private var viewModel: IntentionSessionViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: IntentionSessionViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        List {
            Section("Make room for") {
                Text(viewModel.habitName).font(.headline)
                Text("Choose a phone-free session to make space for this habit. This captures your intention; it doesn't mark the habit complete.")
                    .foregroundStyle(.secondary)
            }
            if !viewModel.habitAvailable {
                Section { Text("This habit is unavailable or archived. Its earlier intentions remain below.") }
            } else if viewModel.goals.isEmpty {
                Section("Phone-free sessions") {
                    Text("Create a Phone-free session attention goal from Today first, then return here to choose it.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Choose your session") {
                    Picker("Session goal", selection: $viewModel.selectedGoalID) {
                        ForEach(viewModel.goals) { goal in Text(goal.name).tag(Optional(goal.id)) }
                    }
                    .pickerStyle(.inline)
                    if let minutes = viewModel.selectedTargetMinutes {
                        Text("\(minutes.formatted()) minute target")
                    }
                    Text("Opening this screen changes nothing. Start when you're ready; elapsed time never confirms that you stayed phone-free.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Start Phone-Free Session") { viewModel.start() }
                        .disabled(viewModel.selectedGoalID == nil)
                        .accessibilityIdentifier("intentionSession.start")
                }
            }
            if let goalID = viewModel.startedSessionGoalID {
                Section("Your session") {
                    NavigationLink("Open Session & Check In") {
                        AttentionWindowDetailView(viewModel: viewModel.detailModel(goalID: goalID))
                    }
                    .accessibilityIdentifier("intentionSession.openStarted")
                    Text("Optional Live Activity presentation and manual results are available in the session. Logging this habit remains a separate action.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            if !viewModel.history.isEmpty {
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
        .task { viewModel.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
        .alert("Session Update", isPresented: Binding(get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
    }
}

private struct AttentionIntentionRepositoryKey: EnvironmentKey { static let defaultValue: AttentionRepository? = nil }
private struct IntentionLinkRepositoryKey: EnvironmentKey { static let defaultValue: IntentionSessionLinkRepository? = nil }
extension EnvironmentValues {
    var attentionIntentionRepository: AttentionRepository? {
        get { self[AttentionIntentionRepositoryKey.self] }
        set { self[AttentionIntentionRepositoryKey.self] = newValue }
    }
    var intentionLinkRepository: IntentionSessionLinkRepository? {
        get { self[IntentionLinkRepositoryKey.self] }
        set { self[IntentionLinkRepositoryKey.self] = newValue }
    }
}
