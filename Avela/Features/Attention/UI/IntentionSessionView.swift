import SwiftUI
import UIKit

struct IntentionSessionView: View {
    @State private var viewModel: IntentionSessionViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.rilovaCompanionProfile) private var companionProfile
    @ScaledMetric(relativeTo: .largeTitle) private var stageFontSize = 48.0
    @Environment(\.sessionLiveActivityService) private var liveActivityService
    @Environment(\.habitActivityRepository) private var activityRepository
    @Environment(\.attentionGoalCreationAllowed) private var creationAllowed
    @Environment(\.appProtectionModel) private var protection
    @Environment(\.appProtectionDriver) private var protectionDriver
    @State private var showingProtection = false
    @State private var showingCreateGoal = false
    @State private var showingCalendar = false
    @State private var showingHabitLog = false
    @State private var showsInIsland = false
    @State private var activityMessage: String?
    @State private var acknowledgedStartID: UUID?
    @State private var newGoalMinutes: Double = 30
    @State private var newGoalType: AttentionGoalType = .focusSession
    @State private var stageArrived = false

    init(viewModel: IntentionSessionViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        List {
            Section {
                composerHero
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
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
                    if dynamicTypeSize.isAccessibilitySize {
                        newGoalTypePicker.pickerStyle(.menu)
                    } else {
                        newGoalTypePicker.pickerStyle(.segmented)
                    }
                    Text(newGoalType == .focusSession
                         ? "Use your phone if it helps your activity. Optional app restrictions are a separate choice."
                         : "An intention to step away from your phone. Apps stay available unless you choose optional restrictions.")
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                    durationStarters
                    Button("Create Session Goal", systemImage: "plus.circle") { newGoalMinutes = 30; showingCreateGoal = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("intentionSession.createGoal")
                    Text("Review and save a goal before starting. Creating a goal never starts its timer.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                }
            } else {
                Section("Choose your session") {
                    Picker("Session goal", selection: $viewModel.selectedGoalID) {
                        ForEach(viewModel.goals) { goal in Text("\(goal.name) · \(goal.type.label)").tag(Optional(goal.id)) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("intentionSession.goalPicker")
                    Text(viewModel.selectedSessionType == .focusSession ? "Without optional app protection, all your apps remain available. Elapsed time never verifies concentration or completes this habit." : "Intend to stay off your phone. Apps remain available unless you enable optional protection; elapsed time never proves you stayed phone-free.")
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("intentionSession.explanation")
                    if liveActivityService != nil {
                        Toggle("Show mascot & timer in Dynamic Island", isOn: $showsInIsland)
                            .accessibilityIdentifier("intentionSession.islandToggle")
                        Text("Lock Screen too, where supported. Hide it anytime; the session keeps running.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    }
                    if let protection, protection.isAvailable {
                        Toggle("Restrict selected distractions", isOn: $viewModel.protectsSession)
                            .accessibilityIdentifier("protection.sessionToggle")
                        Button("Choose Apps & Websites") { showingProtection = true }
                            .accessibilityIdentifier("protection.setup")
                        Label(protection.selectionCount > 0 ? "\(protection.selectionCount) selections saved · optional" : "Choose distractions and allow access first",
                              systemImage: "hand.raised")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                        Text("15 minutes to 8 hours. Restrictions apply only when this switch is on at Start.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    }
                    Button(action: startSession) {
                        HStack(spacing: 12) {
                            if hasAcknowledgedRunningSession {
                                Label("Session Started", systemImage: "checkmark.circle.fill")
                            } else {
                                Image(systemName: "play.fill").accessibilityHidden(true)
                                Text(viewModel.selectedSessionType == .focusSession ? "Start Focus Session" : "Start Phone-Free Session")
                            }
                        }
                        .font(.headline).foregroundStyle(palette.prominentInk)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .padding(.horizontal, 12)
                        .background(palette.prominentFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(RilovaPressStyle())
                    .disabled(viewModel.selectedGoalID == nil || hasAcknowledgedRunningSession)
                    .accessibilityIdentifier("intentionSession.start")
                    if let activityMessage {
                        Text(activityMessage).font(.subheadline)
                            .foregroundStyle(Color.appInkSecondary)
                            .accessibilityIdentifier("intentionSession.activityMessage")
                    }
                    Button("Create Another Session Goal", systemImage: "plus.circle") { showingCreateGoal = true }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("intentionSession.createGoal")
                }
            }
            if let protection {
                if let lease = protection.active, lease.sessionID != viewModel.startedSessionID {
                    Section("App protection") {
                        Label("Protection is active for another session", systemImage: "hand.raised")
                        Text("These restrictions are separate from this habit's session choices.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                        Button("Stop Protection", role: .destructive) { protection.stop() }
                            .accessibilityIdentifier("protection.stop")
                    }
                } else {
                    AppProtectionStatusView(model: protection)
                }
                if !protection.isAvailable {
                    Section {
                        Button("App Protection Setup", systemImage: "hand.raised") { showingProtection = true }
                            .accessibilityIdentifier("protection.setup")
                    }
                }
            }
            if viewModel.habitAvailable {
                Section("Later works too") {
                    Button("Plan Time in Calendar", systemImage: "calendar.badge.plus") { showingCalendar = true }
                        .accessibilityIdentifier("intentionSession.planCalendar")
                    Text("Planning doesn't start a timer or log success.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let goalID = viewModel.startedSessionGoalID {
                Section("Your session") {
                    NavigationLink("Open Session & Check In") {
                        AttentionWindowDetailView(viewModel: viewModel.detailModel(goalID: goalID))
                    }
                    .accessibilityIdentifier("intentionSession.openStarted")
                    Text("Report how it went, then log your habit separately.")
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
            Section {
                DisclosureGroup("How sessions work") {
                    Text("A focus session allows phone use. A phone-free session is your intention to step away. Neither verifies what you do or completes the habit. Apps are restricted only when you explicitly enable optional protection before starting.")
                        .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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
        .task { viewModel.creationAllowed = creationAllowed; viewModel.protection = protection; viewModel.load(); protection?.refresh() }
        .sheet(isPresented: $showingProtection) {
            if let protection { AppProtectionSetupView(model: protection, driver: protectionDriver) }
        }
        .sheet(isPresented: $showingCalendar) {
            HabitCalendarSchedulingView(habitName: viewModel.habitName, suggestedMinutes: viewModel.selectedTargetMinutes)
        }
        .sheet(isPresented: $showingCreateGoal) {
            AttentionGoalFormView(defaultType: newGoalType,
                defaultName: "\(newGoalType == .focusSession ? "Focus" : "Phone-free time") for \(viewModel.habitName)",
                defaultTargetMinutes: newGoalMinutes, sessionOnly: true) { draft in
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
        .onChange(of: viewModel.selectedGoalID) { _, _ in
            acknowledgedStartID = nil
            activityMessage = nil
        }
        .alert("Session Update", isPresented: Binding(get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
    }

    private var composerHero: some View {
        let type = viewModel.goals.isEmpty ? newGoalType : viewModel.selectedSessionType
        let minutes = viewModel.selectedTargetMinutes ?? newGoalMinutes
        return VStack(alignment: .leading, spacing: 0) {
            if usesReadableStage {
                focusEnvironment.frame(height: 76).clipped().accessibilityHidden(true)
            } else {
                ZStack(alignment: .leading) {
                    focusEnvironment
                    HStack(alignment: .bottom, spacing: 12) {
                        ZStack {
                            Circle().fill(Color(red: 0.05, green: 0.17, blue: 0.23))
                            Circle().strokeBorder(Color(red: 0.88, green: 0.79, blue: 0.57), lineWidth: 2).padding(8)
                            Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1).padding(15)
                            VStack(spacing: 6) {
                                clockValue(minutes: minutes)
                                Text(activeSession == nil ? "minutes" : "remaining")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(palette.luminousHighlight)
                            }.padding(22)
                        }
                        .frame(width: 172, height: 172)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(activeSession == nil ? "intentionSession.targetClock" : "intentionSession.countdown")
                        .scaleEffect(stageArrived || reduceMotion ? 1 : 0.94)
                        Spacer(minLength: 0)
                        if let profile = companionProfile, profile.companionEnabled {
                            ZStack {
                                Ellipse().fill(Color(red: 0.85, green: 0.76, blue: 0.56))
                                    .frame(width: 110, height: 18).offset(y: 44)
                                CompanionArtwork(animal: profile.selectedAnimal.rawValue, state: "calm", size: 112, highResolution: true)
                                    .offset(y: -4)
                            }
                            .offset(y: stageArrived || reduceMotion ? 0 : 10)
                            .accessibilityHidden(true)
                        }
                    }.padding(22)
                }
                .frame(height: 216).clipped()
            }
            VStack(alignment: .leading, spacing: 10) {
                Label(type == .phoneFreeSession ? "Phone-free intention" : "Focus session",
                      systemImage: type == .phoneFreeSession ? "moon.stars" : "sparkle")
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
                Text(viewModel.habitName.isEmpty ? "Make a little space" : viewModel.habitName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appInk).fixedSize(horizontal: false, vertical: true)
                if usesReadableStage {
                    clockValue(minutes: minutes).foregroundStyle(Color.appInk)
                }
                Text(activeSession == nil
                     ? (viewModel.goals.isEmpty ? "\(minutes.formatted()) minutes · suggested start" : "\(minutes.formatted()) minute target")
                     : "Target timer · your habit still needs its own check-in")
                    .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfaceSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear {
            guard !stageArrived else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { stageArrived = true }
        }
    }

    private var focusEnvironment: some View {
        GeometryReader { geometry in
            if reduceTransparency || contrast == .increased {
                palette.heroEnd
            } else {
                RilovaWorldArtwork(scene: .sanctuary)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
        .accessibilityHidden(true).allowsHitTesting(false)
    }

    private var activeSession: AttentionSession? {
        viewModel.history.first {
            $0.session.isActive && $0.session.attentionGoalID == viewModel.selectedGoalID
        }?.session
    }

    // Large display numerals and live countdowns need their natural width well
    // before accessibility sizes; the fixed decorative dial is only for the
    // smaller text settings.
    private var usesReadableStage: Bool { dynamicTypeSize >= .xxLarge }

    @ViewBuilder private func clockValue(minutes: Double) -> some View {
        if let session = activeSession {
            let end = session.startedAt.addingTimeInterval(session.targetMinutes * 60)
            Text(timerInterval: session.startedAt...end,
                 pauseTime: scenePhase == .active ? nil : Date(), countsDown: true, showsHours: false)
                .font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(usesReadableStage ? Color.appInk : .white)
                .accessibilityIdentifier(usesReadableStage ? "intentionSession.countdown" : "intentionSession.clockDigits")
        } else {
            Text(minutes.formatted())
                .font(.system(size: stageFontSize, weight: .bold, design: .rounded)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(usesReadableStage ? Color.appInk : .white)
        }
    }

    private var durationStarters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start with a little time").font(.subheadline.weight(.semibold))
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach([15, 25, 45], id: \.self) { minutes in
                    Button { newGoalMinutes = Double(minutes); showingCreateGoal = true } label: {
                        Text("\(minutes) min").font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(RilovaPressStyle())
                    .accessibilityIdentifier("intentionSession.duration.\(minutes)")
                    .accessibilityLabel("Review a new \(minutes) minute session goal")
                }
            }
        }.padding(.vertical, 6)
    }

    private var newGoalTypePicker: some View {
        Picker("Session type", selection: $newGoalType) {
            Text("Focus").tag(AttentionGoalType.focusSession)
            Text("Phone-free").tag(AttentionGoalType.phoneFreeSession)
        }
        .accessibilityIdentifier("intentionSession.newGoalType")
    }

    private func startSession() {
        acknowledgedStartID = nil
        activityMessage = nil
        let started = viewModel.start()
        if started {
            acknowledgedStartID = viewModel.startedSessionID
            UIAccessibility.post(notification: .announcement, argument: "Session started. Your habit still needs its own check-in.")
        }
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

    private var hasAcknowledgedRunningSession: Bool {
        guard let acknowledgedStartID else { return false }
        return viewModel.history.contains {
            $0.id == acknowledgedStartID && $0.session.attentionGoalID == viewModel.selectedGoalID && $0.session.isActive
        }
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
