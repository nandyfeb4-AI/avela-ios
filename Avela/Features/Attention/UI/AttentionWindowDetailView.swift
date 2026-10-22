import SwiftUI
import UIKit

struct AttentionWindowDetailView: View {
    @State private var viewModel: AttentionWindowDetailViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.sessionLiveActivityService) private var liveActivityService
    @Environment(\.appProtectionModel) private var protection
    @State private var liveActivityMessage: String?
    @State private var activityAcknowledgment: ActivityAcknowledgment?
    @State private var isHidingActivity = false

    private enum ActivityAcknowledgment {
        case requested, hidden, showFailed, hideFailed
    }

    init(viewModel: AttentionWindowDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    AppIconBadge(symbol: viewModel.goalType.isTimedSession ? "moon" : "clock")
                        .accessibilityHidden(true)
                    Text(viewModel.name).font(.title2.weight(.semibold)).fontDesign(.rounded)
                        .foregroundStyle(Color.appInk)
                }.rilovaHeaderSurface()
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section("Goal") {
                if let summary = viewModel.summary {
                    Text(summary.targetLabel)
                    Text(summary.statusLabel).foregroundStyle(.secondary)
                        .accessibilityIdentifier("attentionWindow.status")
                }
                Text(viewModel.goalType == .focusSession ? "Focus on your activity. Only explicitly enabled app protection restricts your selected distractions; Rilova does not measure app usage." : "Rilova does not monitor phone use. Optional app protection is separate; results are your own check-ins.")
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
            if let protection { AppProtectionStatusView(model: protection) }
            if let session = viewModel.activeSession, let liveActivityService,
               viewModel.presentationDate < session.expectedEnd {
                Section("Live Activity") {
                    Button {
                        activityAcknowledgment = nil
                        do {
                            try liveActivityService.show(sessionID: session.id)
                            activityAcknowledgment = .requested
                            liveActivityMessage = "Session activity requested. Go Home to see the timer where supported."
                            Task { await liveActivityService.synchronize() }
                        } catch SessionLiveActivityError.disabled {
                            liveActivityMessage = "Live Activities are unavailable or disabled. Your session is still running in Rilova."
                        } catch SessionLiveActivityError.presentationChanging {
                            liveActivityMessage = "Please wait for the activity to finish updating."
                        } catch SessionLiveActivityError.unsupportedDuration {
                            liveActivityMessage = "Live Activities support sessions up to 8 hours. Your longer session still works in Rilova."
                        } catch {
                            liveActivityMessage = "Couldn't show the session right now. Tracking in Rilova is unchanged."
                        }
                        if activityAcknowledgment == nil { activityAcknowledgment = .showFailed }
                        announceActivityFeedback()
                    } label: {
                        if activityAcknowledgment == .requested {
                            Label("Activity Requested", systemImage: "checkmark.circle.fill")
                        } else if activityAcknowledgment == .showFailed {
                            Label("Try Showing Again", systemImage: "exclamationmark.circle")
                        } else {
                            Text("Show Session Activity")
                        }
                    }
                    .accessibilityLabel(activityAcknowledgment == .requested ? "Session activity requested" : "Show Session Activity")
                    .disabled(liveActivityService.isChangingPresentation || isHidingActivity)
                    .accessibilityIdentifier("attentionWindow.showLiveActivity")
                    Button {
                        activityAcknowledgment = nil
                        liveActivityMessage = nil
                        isHidingActivity = true
                        Task {
                            defer { isHidingActivity = false }
                            do {
                                try await liveActivityService.hide(sessionID: session.id)
                                guard viewModel.activeSession?.id == session.id else { return }
                                activityAcknowledgment = .hidden
                                liveActivityMessage = "Session activity hidden. Your session is still running."
                            } catch {
                                guard viewModel.activeSession?.id == session.id else { return }
                                activityAcknowledgment = .hideFailed
                                liveActivityMessage = "Please wait for the activity to finish updating."
                            }
                            announceActivityFeedback()
                        }
                    } label: {
                        if isHidingActivity {
                            HStack { ProgressView(); Text("Hiding Activity…") }
                        } else if activityAcknowledgment == .hidden {
                            Label("Activity Hidden", systemImage: "checkmark.circle.fill")
                        } else if activityAcknowledgment == .hideFailed {
                            Label("Try Hiding Again", systemImage: "exclamationmark.circle")
                        } else {
                            Text("Hide Session Activity")
                        }
                    }
                    .accessibilityLabel(isHidingActivity ? "Hiding session activity" : activityAcknowledgment == .hidden ? "Session activity hidden" : "Hide Session Activity")
                    .disabled(liveActivityService.isChangingPresentation || isHidingActivity)
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
        .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: viewModel.activeSession?.id) { _, _ in
            activityAcknowledgment = nil
            liveActivityMessage = nil
        }
    }

    private func announceActivityFeedback() {
        if let liveActivityMessage {
            UIAccessibility.post(notification: .announcement, argument: liveActivityMessage)
        }
    }
}
