import SwiftUI

struct OnboardingView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AccessibilityFocusState private var isStepTitleFocused: Bool
    @State private var viewModel: OnboardingViewModel
    let onFinished: () -> Void

    init(viewModel: OnboardingViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        @Bindable var model = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 6) {
                        ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                            Capsule().fill(step.rawValue <= model.step.rawValue ? palette.accent : palette.accentSoft)
                                .frame(height: 4)
                        }
                    }.accessibilityHidden(true)
                    Text("\(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(title).font(.largeTitle.weight(.semibold))
                        .accessibilityIdentifier("onboarding.title")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isStepTitleFocused)
                    Text(description).foregroundStyle(.secondary)
                    stepContent
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .appThemeCanvas()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button(model.step == .finish ? "Start My Day" : "Continue") {
                        if model.step == .finish { model.finish() } else { model.advance() }
                    }
                    .foregroundStyle(palette.prominentInk)
                    .buttonStyle(.borderedProminent)
                    .tint(palette.prominentFill)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding.continue")
                    if [.habit, .attention, .companion, .reminder].contains(model.step) {
                        Button("Skip for now") { model.advance() }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("onboarding.skip")
                    }
                }
                .frame(maxWidth: .infinity).padding(16)
                .background {
                    if reduceTransparency { palette.surface }
                    else { Rectangle().fill(.regularMaterial) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $model.isShowingHabitForm) {
            HabitFormView { model.createHabit($0) }
        }
        .sheet(isPresented: $model.isShowingAttentionForm) {
            AttentionGoalFormView { model.createAttentionGoal($0) }
        }
        .task { model.load() }
        .onChange(of: model.step) { _, _ in isStepTitleFocused = true }
        .onChange(of: model.didFinish) { _, finished in if finished { onFinished() } }
        .alert("Changes Couldn’t Be Saved", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
    }

    @ViewBuilder private var stepContent: some View {
        @Bindable var model = viewModel
        switch model.step {
        case .welcome:
            Label("Private, local-first, no account needed", systemImage: "lock.shield")
        case .habit:
            if let habit = model.firstHabit { Label(habit.name, systemImage: habit.iconName) }
            Button(model.firstHabit == nil ? "Create First Habit" : "Create Another Habit") { model.requestHabitCreation() }
                .buttonStyle(.bordered).accessibilityIdentifier("onboarding.createHabit")
        case .attention:
            if model.hasAttentionGoal { Text("Your attention goal is ready.") }
            Button(model.hasAttentionGoal ? "Create Another Goal" : "Create Attention Goal") { model.requestAttentionCreation() }
                .buttonStyle(.bordered).accessibilityIdentifier("onboarding.createAttention")
        case .companion:
            CompanionSelectionView(selectedAnimal: $model.profile.selectedAnimal)
            Toggle("Show companion", isOn: $model.profile.companionEnabled)
        case .reminder:
            if let habit = model.firstHabit, let service = model.reminderService {
                NavigationLink("Set Up a Reminder") {
                    HabitReminderView(habitID: habit.id, schedule: habit.schedule, service: service)
                }
                .accessibilityIdentifier("onboarding.setupReminder")
            } else { Text("You can add reminders from any habit's detail screen later.") }
        case .finish:
            Text("You can change your goals, companion and reminders anytime.")
        }
    }

    private var title: String {
        switch viewModel.step {
        case .welcome: return "Build habits. Make room for your attention."
        case .habit: return "Start with one small habit"
        case .attention: return "Choose an attention budget"
        case .companion: return "Choose your companion"
        case .reminder: return "A gentle nudge, if you want one"
        case .finish: return "Your day, at your pace"
        }
    }

    private var description: String {
        switch viewModel.step {
        case .welcome: return "Flexible commitments and supportive recovery, without treating a missed day as lost progress."
        case .habit: return "Choose something you'd like to build up or cut down. Daily, selected days, or a flexible weekly goal."
        case .attention: return "Set a daily limit and log time manually. Avela doesn't automatically monitor your phone usage."
        case .companion: return "A quiet reflection of your progress, with no care tasks or obligations."
        case .reminder: return "Permission is requested only when you save an enabled reminder. Reminders are optional."
        case .finish: return "Everything stays on this device. Begin small; adjust as you go."
        }
    }
}
