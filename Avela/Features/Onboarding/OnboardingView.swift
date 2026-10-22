import SwiftUI

struct OnboardingView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var welcomeTitleSize = 44.0
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        progress
                        introduction.id("onboarding.stepStart")
                        stepContent
                    }
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .appThemeCanvas()
                .onChange(of: model.step) { _, _ in
                    // Return to the heading after longer accessibility layouts.
                    proxy.scrollTo("onboarding.stepStart", anchor: .top)
                    isStepTitleFocused = true
                }
            }
            .safeAreaInset(edge: .bottom) { continuation }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $model.isShowingHabitForm) {
            HabitFormView { model.createHabit($0) }
        }
        .sheet(isPresented: $model.isShowingAttentionForm) {
            AttentionGoalFormView { model.createAttentionGoal($0) }
        }
        .task { model.load() }
        .onChange(of: model.didFinish) { _, finished in if finished { onFinished() } }
        .alert("Changes Couldn’t Be Saved", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your beginning")
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("\(viewModel.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption.weight(.medium)).monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }.foregroundStyle(Color.appInkSecondary)
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule().fill(step.rawValue <= viewModel.step.rawValue ? palette.accent : palette.accentSoft)
                        .frame(height: step == viewModel.step ? 5 : 3)
                }
            }.accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup step \(viewModel.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 22) {
            if viewModel.step == .welcome {
                HStack(spacing: 12) {
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rilova").font(.title2.weight(.semibold)).fontDesign(.rounded)
                            .accessibilityIdentifier("onboarding.brandName")
                        Text("Habits & Focus").font(.caption).foregroundStyle(Color.appInkSecondary)
                    }
                }
            }
            OnboardingScene(step: viewModel.step, animal: viewModel.profile.selectedAnimal,
                            showsCompanion: viewModel.profile.companionEnabled,
                            compact: dynamicTypeSize.isAccessibilitySize)
                .frame(height: sceneHeight)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 64,
                                                  bottomTrailingRadius: 28, topTrailingRadius: 28))
                .id(viewModel.step)
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(viewModel.step == .welcome
                          ? .system(size: welcomeTitleSize, weight: .bold, design: .rounded)
                          : .system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding.title").accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isStepTitleFocused)
                Text(description).font(.body).foregroundStyle(Color.appInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sceneHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return viewModel.step == .welcome ? 96 : 76 }
        return viewModel.step == .welcome || viewModel.step == .finish ? 254 : 188
    }

    private var continuation: some View {
        VStack(spacing: 12) {
            Button {
                if viewModel.step == .finish { viewModel.finish() } else { viewModel.advance() }
            } label: {
                HStack(spacing: 12) {
                    Text(viewModel.step == .finish ? "Start My Day" : "Continue")
                    Image(systemName: viewModel.step == .finish ? "arrow.up.right" : "arrow.right").accessibilityHidden(true)
                }
                .font(.headline).foregroundStyle(palette.prominentInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(palette.prominentFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(RilovaPressStyle()).accessibilityIdentifier("onboarding.continue")
            if [.habit, .attention, .companion, .reminder].contains(viewModel.step) {
                Button { viewModel.advance() } label: {
                    Text("Skip for now")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Color.appInkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RilovaPressStyle())
                .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            if reduceTransparency || contrast == .increased {
                palette.surface.ignoresSafeArea(edges: .bottom)
            } else {
                Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .bottom)
            }
        }
    }

    @ViewBuilder private var stepContent: some View {
        @Bindable var model = viewModel
        switch model.step {
        case .welcome:
            VStack(alignment: .leading, spacing: 14) {
                benefit("Make a little room", detail: "Choose what deserves your attention.", symbol: "sparkle")
                benefit("Keep the progress", detail: "A missed day doesn't erase your effort.", symbol: "arrow.counterclockwise")
                Label("Private, local-first, no account needed", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(Color.appInkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        case .habit:
            if let habit = model.firstHabit {
                readiness(habit.name, detail: "Your first habit is ready.", symbol: habit.iconName)
            }
            setupAction(model.firstHabit == nil ? "Create First Habit" : "Create Another Habit",
                        detail: "Explore ideas or make it your own.", symbol: "plus") { model.requestHabitCreation() }
                .accessibilityIdentifier("onboarding.createHabit")
        case .attention:
            if model.hasAttentionGoal {
                readiness("Your attention goal is ready.", detail: "You choose what to log.", symbol: "hourglass")
            }
            setupAction(model.hasAttentionGoal ? "Create Another Goal" : "Create Attention Goal",
                        detail: "A daily budget for something you'd like less of.", symbol: "plus") { model.requestAttentionCreation() }
                .accessibilityIdentifier("onboarding.createAttention")
        case .companion:
            CompanionSelectionView(selectedAnimal: $model.profile.selectedAnimal)
            Toggle("Show companion", isOn: $model.profile.companionEnabled)
                .padding(16).background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        case .reminder:
            if let habit = model.firstHabit, let service = model.reminderService {
                NavigationLink {
                    HabitReminderView(habitID: habit.id, schedule: habit.schedule, service: service)
                } label: {
                    actionLabel("Set Up a Reminder", detail: habit.name, symbol: "bell.badge")
                }
                .buttonStyle(RilovaPressStyle()).accessibilityIdentifier("onboarding.setupReminder")
            } else {
                benefit("Whenever it helps", detail: "Add a reminder from any habit's details later.", symbol: "bell")
            }
        case .finish:
            VStack(alignment: .leading, spacing: 14) {
                if let habit = model.firstHabit {
                    readiness(habit.name, detail: "Ready for your first check-in.", symbol: habit.iconName)
                } else {
                    benefit("Start with something small", detail: "Your first habit can be one tap away.", symbol: "plus.circle")
                }
                Text("Change your goals, companion and reminders anytime.")
                    .font(.subheadline).foregroundStyle(Color.appInkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func benefit(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3.weight(.medium)).foregroundStyle(palette.accent)
                .frame(width: 28, height: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.appInk)
                Text(detail).font(.subheadline).foregroundStyle(Color.appInkSecondary)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readiness(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(palette.accent)
                .frame(width: 40, height: 40).background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Color.appInk)
                Text(detail).font(.subheadline).foregroundStyle(Color.appInkSecondary)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.accent).accessibilityHidden(true)
        }
        .padding(18).background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func setupAction(_ title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(title, detail: detail, symbol: symbol) }.buttonStyle(RilovaPressStyle())
    }

    private func actionLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(palette.accent)
                .frame(width: 42, height: 42).background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Color.appInk)
                Text(detail).font(.subheadline).foregroundStyle(Color.appInkSecondary)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(palette.accent).accessibilityHidden(true)
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(palette.accent.opacity(0.32), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    private var title: String {
        switch viewModel.step {
        case .welcome: return "Habits that fit real life."
        case .habit: return "Start with one small habit"
        case .attention: return "Make room for what matters"
        case .companion: return "A little company, your way"
        case .reminder: return "A nudge, when it helps"
        case .finish: return "Your day, at your pace"
        }
    }

    private var description: String {
        switch viewModel.step {
        case .welcome: return "Find your rhythm. Protect your attention. Keep going, even when life interrupts."
        case .habit: return "Build up or cut down. Set a rhythm that works for you, with a simple check-in or an amount to track."
        case .attention: return "Choose a daily budget and log time manually. Rilova doesn't automatically measure phone use."
        case .companion: return "A quiet reflection of your progress. No care tasks, points or obligations. You can hide it anytime."
        case .reminder: return "Reminders are optional. Notification permission is requested only when you save an enabled reminder."
        case .finish: return "Your tracking starts on this device. Optional connections stay in your control."
        }
    }
}

/// Each stage is an illustrated setting, never a projection of user progress.
/// Entry choreography is finite; the landscape remains still while reading.
private struct OnboardingScene: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let step: OnboardingStep
    let animal: CompanionAnimal
    let showsCompanion: Bool
    let compact: Bool
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if contrast == .increased || reduceTransparency {
                    palette.heroEnd
                } else {
                    RilovaWorldArtwork(scene: step == .attention || step == .companion ? .sanctuary : .coast)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                illustration(size: geometry.size)
                    .opacity(appeared || reduceMotion ? 1 : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true).allowsHitTesting(false)
        .onAppear {
            guard !appeared else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.86)) { appeared = true }
        }
    }

    @ViewBuilder private func illustration(size: CGSize) -> some View {
        let dimension = min(size.height * 0.69, compact ? 68 : 158)
        switch step {
        case .welcome, .finish, .companion:
            let position: CGFloat = step == .welcome ? 0.68 : step == .finish ? 0.34 : 0.5
            ZStack {
                if !compact {
                    Ellipse().fill(Color(red: 0.93, green: 0.82, blue: 0.62))
                        .frame(width: dimension * 1.3, height: dimension * 0.24)
                        .overlay(Ellipse().strokeBorder(.white.opacity(0.40), lineWidth: 1))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 10)
                        .offset(y: dimension * 0.45)
                }
                if step == .finish && !showsCompanion {
                    Image("BrandIcon").resizable().scaledToFit()
                        .frame(width: dimension * 0.82, height: dimension * 0.82)
                        .clipShape(RoundedRectangle(cornerRadius: dimension * 0.22))
                } else {
                    CompanionArtwork(animal: animal.rawValue, state: "calm", size: dimension, highResolution: true)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 6)
                }
            }
            .scaleEffect(appeared || reduceMotion ? 1 : 0.90, anchor: .bottom)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .position(x: size.width * (compact ? 0.5 : position), y: size.height * (compact ? 0.5 : 0.60))
        case .habit:
            HStack(alignment: .center, spacing: compact ? 10 : 14) {
                sceneTile("book.closed.fill", tint: Color(red: 0.97, green: 0.78, blue: 0.53), angle: -12, size: dimension * 0.67)
                    .offset(y: appeared || reduceMotion ? 9 : 26)
                sceneTile("leaf.fill", tint: palette.luminousHighlight, angle: 4, size: dimension * 0.88)
                sceneTile("figure.walk", tint: Color(red: 0.76, green: 0.76, blue: 0.96), angle: 13, size: dimension * 0.67)
                    .offset(y: appeared || reduceMotion ? -5 : 14)
            }
            .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -4))
            .position(x: size.width * 0.51, y: size.height * 0.51)
        case .attention:
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 1).padding(-14)
                Circle().fill(Color(red: 0.08, green: 0.19, blue: 0.28))
                Circle().strokeBorder(Color(red: 0.87, green: 0.79, blue: 0.57), lineWidth: 3).padding(8)
                Image(systemName: "hourglass").font(.system(size: dimension * 0.35, weight: .light))
                    .foregroundStyle(palette.luminousHighlight)
            }
            .frame(width: dimension, height: dimension)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.84)
            .position(x: size.width * (compact ? 0.5 : 0.64), y: size.height * 0.50)
        case .reminder:
            sceneTile("bell.fill", tint: Color(red: 0.98, green: 0.80, blue: 0.53), angle: appeared || reduceMotion ? -8 : 8, size: dimension * 0.88)
                .offset(y: appeared || reduceMotion ? 0 : 12)
                .position(x: size.width * (compact ? 0.5 : 0.37), y: size.height * 0.49)
        }
    }

    private func sceneTile(_ symbol: String, tint: Color, angle: Double, size: CGFloat) -> some View {
        Image(systemName: symbol).font(.system(size: size * 0.40, weight: .medium))
            .foregroundStyle(Color(red: 0.06, green: 0.23, blue: 0.27)).frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.30).strokeBorder(.white.opacity(0.55), lineWidth: 1))
            .rotationEffect(.degrees(angle)).shadow(color: .black.opacity(0.13), radius: 12, y: 10)
    }
}
