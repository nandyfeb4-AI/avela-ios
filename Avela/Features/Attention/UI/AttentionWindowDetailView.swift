import SwiftUI

struct AttentionWindowDetailView: View {
    @State private var viewModel: AttentionWindowDetailViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.sessionLiveActivityService) private var liveActivityService
    @State private var liveActivityMessage: String?

    init(viewModel: AttentionWindowDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section("Goal") {
                HStack(spacing: 12) {
                    AppIconBadge(symbol: viewModel.goalType.isTimedSession ? "moon" : "clock")
                        .accessibilityHidden(true)
                    Text(viewModel.name).font(.title2.weight(.semibold))
                }.padding(.vertical, 8)
                if let summary = viewModel.summary {
                    Text(summary.targetLabel)
                    Text(summary.statusLabel).foregroundStyle(.secondary)
                        .accessibilityIdentifier("attentionWindow.status")
                }
                Text(viewModel.goalType == .focusSession ? "Focus on your activity. Using your phone is allowed; Avela does not block or monitor apps." : "Avela does not monitor or block phone use. Results are your own check-ins.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(viewModel.goalType.isTimedSession ? "Session" : "Check In") {
                if viewModel.goalType.isTimedSession && viewModel.activeSession == nil {
                    Button(viewModel.goalType == .focusSession ? "Start Focus Session" : "Start Phone-Free Session") { viewModel.startSession() }
                        .accessibilityIdentifier("attentionWindow.startSession")
                } else {
                    if let session = viewModel.activeSession {
                        Text("Started \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        Text("Target ends \(session.expectedEnd.formatted(date: .abbreviated, time: .shortened))")
                        if viewModel.presentationDate >= session.expectedEnd {
                            Text(viewModel.goalType == .focusSession ? "Time elapsed. Confirm whether you stayed focused." : "Time elapsed. Confirm whether you stayed phone-free.")
                        }
                    }
                    Button(viewModel.goalType == .focusSession ? "I Stayed Focused" : "I Kept It") { viewModel.report(.kept) }
                        .disabled(!viewModel.canReportKept(at: viewModel.presentationDate))
                        .accessibilityIdentifier("attentionWindow.kept")
                    Button("I Was Interrupted") { viewModel.report(.interrupted) }
                        .disabled(!viewModel.canReportInterrupted(at: viewModel.presentationDate))
                        .accessibilityIdentifier("attentionWindow.interrupted")
                }
            }
            if let session = viewModel.activeSession, let liveActivityService,
               viewModel.presentationDate < session.expectedEnd {
                Section("Live Activity") {
                    Button("Show Session Activity") {
                        do {
                            try liveActivityService.show(sessionID: session.id)
                            liveActivityMessage = "Session shown where supported. Tap it to return to Avela."
                            Task { await liveActivityService.synchronize() }
                        } catch SessionLiveActivityError.disabled {
                            liveActivityMessage = "Live Activities are unavailable or disabled. Your session is still running in Avela."
                        } catch SessionLiveActivityError.presentationChanging {
                            liveActivityMessage = "Please wait for the activity to finish updating."
                        } catch SessionLiveActivityError.unsupportedDuration {
                            liveActivityMessage = "Live Activities support sessions up to 8 hours. Your longer session still works in Avela."
                        } catch {
                            liveActivityMessage = "Couldn't show the session right now. Tracking in Avela is unchanged."
                        }
                    }
                    .disabled(liveActivityService.isChangingPresentation)
                    .accessibilityIdentifier("attentionWindow.showLiveActivity")
                    Button("Hide Session Activity") {
                        Task {
                            do {
                                try await liveActivityService.hide(sessionID: session.id)
                                liveActivityMessage = "Session activity hidden. Your session is still running."
                            } catch {
                                liveActivityMessage = "Please wait for the activity to finish updating."
                            }
                        }
                    }
                    .disabled(liveActivityService.isChangingPresentation)
                    .accessibilityIdentifier("attentionWindow.hideLiveActivity")
                    Text("Optional Lock Screen and Dynamic Island timer with your companion. Does not verify phone use.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let liveActivityMessage {
                        Text(liveActivityMessage).font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("attentionWindow.liveActivityMessage")
                    }
                }
            }
            if !viewModel.sessionHistory.filter({ !$0.isActive }).isEmpty {
                Section("Past Sessions") {
                    ForEach(viewModel.sessionHistory.filter { !$0.isActive }) { session in
                        VStack(alignment: .leading) {
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Text("\(session.targetMinutes.formatted()) min target · \(session.outcome == .kept ? "Kept" : "Interrupted") · reported manually")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("Attention Goal")
        .toolbar { Button("Edit") { viewModel.isEditing = true } }
        .sheet(isPresented: $viewModel.isEditing) {
            if let draft = viewModel.draft {
                AttentionGoalFormView(initialDraft: draft) { viewModel.saveEdits($0) }
            }
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "") }
        .task { viewModel.load() }
        .task(id: viewModel.presentationDate) {
            let delay = max(0, viewModel.refreshDeadline.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard !Task.isCancelled else { return }
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.load()
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
    }
}
