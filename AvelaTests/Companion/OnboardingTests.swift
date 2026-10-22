import XCTest
import SwiftData
@testable import Avela

@MainActor
final class OnboardingTests: XCTestCase {
    func testOptionalStepsCanBeSkippedWithoutCreatingTrackingData() throws {
        let fixture = try Fixture()
        let model = fixture.model
        model.load()
        model.advance()
        XCTAssertEqual(model.step, .goal)
        model.selectGoal(.focus)
        model.skipCurrentStep()
        XCTAssertNil(model.selectedGoal)
        XCTAssertEqual(model.step, .obstacle)
        model.selectObstacle(.time)
        model.skipCurrentStep()
        XCTAssertNil(model.selectedObstacle)
        XCTAssertEqual(model.step, .habit)
        model.skipCurrentStep()
        XCTAssertEqual(model.step, .companion)
        model.profile.selectedAnimal = .fox
        model.skipCurrentStep()
        XCTAssertEqual(model.step, .finish)
        XCTAssertEqual(model.profile.selectedAnimal, .owl, "Skip must discard an unaccepted companion edit")
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<CompanionProfileRecord>()).isEmpty)
        model.finish()
        XCTAssertTrue(model.didFinish)
        XCTAssertTrue(try fixture.profiles.profile().onboardingCompleted)
        try assertNoTrackingFacts(fixture)
    }

    func testAnswersAndStarterBrowsingWriteNothingAndAreNotRestoredInANewSetupModel() throws {
        let fixture = try Fixture()
        let model = fixture.model
        model.load()
        model.selectGoal(.restart)
        model.selectObstacle(.tooBig)
        model.selectStarter("read")
        XCTAssertNotNil(model.selectedHabitDraft)
        try assertNoTrackingFacts(fixture)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<HabitActivityConfigurationRecord>()).isEmpty)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<CompanionProfileRecord>()).isEmpty)
        let fresh = OnboardingViewModel(habits: fixture.habits, profiles: fixture.profiles)
        fresh.load()
        XCTAssertNil(fresh.selectedGoal)
        XCTAssertNil(fresh.selectedObstacle)
        XCTAssertNil(fresh.selectedStarterID)
        XCTAssertNil(fresh.selectedHabitDraft)
        XCTAssertFalse(fresh.didFinish)
    }

    func testRecommendationsRespondToAnswersAndKeepEveryCatalogUnitAndSmallAction() throws {
        let fixture = try Fixture()
        let model = fixture.model
        model.selectGoal(.routine)
        XCTAssertEqual(model.suggestedStarters.map(\.id), ["water", "walk", "read"])
        model.selectObstacle(.forgetting)
        XCTAssertEqual(model.suggestedStarters.map(\.id), ["plan-day", "walk", "read"])
        model.selectGoal(.focus)
        model.selectObstacle(.distractions)
        XCTAssertEqual(model.suggestedStarters.first?.id, "phone-away")
        let goals: [OnboardingGoal?] = [nil] + OnboardingGoal.allCases.map { Optional($0) }
        let obstacles: [OnboardingObstacle?] = [nil] + OnboardingObstacle.allCases.map { Optional($0) }
        for goal in goals {
            model.selectGoal(goal)
            for obstacle in obstacles {
                model.selectObstacle(obstacle)
                let starters = model.suggestedStarters
                XCTAssertFalse(starters.isEmpty)
                XCTAssertEqual(Set(starters.map(\.id)).count, starters.count)
                for starter in starters {
                    let source = try XCTUnwrap(HabitStarter.library.first { $0.id == starter.id })
                    XCTAssertEqual(starter.draft, source.draft, "Answers cannot silently rewrite a catalog unit, target or schedule")
                    if obstacle == .time || obstacle == .tooBig {
                        XCTAssertNil(starter.draft.quantityTarget)
                        XCTAssertFalse(starter.draft.smallerAction?.isEmpty ?? true)
                    }
                }
            }
        }
        try assertNoTrackingFacts(fixture)
    }

    func testChangingAnswersPreservesAnExplicitChoiceAndUnknownStarterClearsForCustomEntry() throws {
        let fixture = try Fixture()
        let model = fixture.model
        model.selectStarter("read")
        let chosen = try XCTUnwrap(model.selectedHabitDraft)
        XCTAssertEqual(chosen.quantityTarget, .init(amount: 10, unit: .pages))
        model.selectGoal(.focus)
        model.selectObstacle(.time)
        XCTAssertFalse(model.suggestedStarters.contains { $0.id == "read" })
        XCTAssertEqual(model.selectedStarterID, "read")
        XCTAssertEqual(model.selectedHabitDraft, chosen)
        model.selectStarter("")
        XCTAssertNil(model.selectedStarterID)
        XCTAssertNil(model.selectedHabitDraft)
        model.selectStarter("water")
        XCTAssertEqual(model.selectedHabitDraft?.quantityTarget?.unit, .glasses)
        model.selectStarter("not-a-catalog-entry")
        XCTAssertNil(model.selectedStarterID)
        XCTAssertNil(model.selectedHabitDraft)
        try assertNoTrackingFacts(fixture)
    }

    func testBackAndSkipPreserveChoicesWithoutSavingOrCompletingSetup() throws {
        let fixture = try Fixture()
        let model = fixture.model
        try fixture.reachHabit()
        model.selectGoal(.focus)
        model.selectObstacle(.distractions)
        model.selectStarter("phone-away")
        model.requestHabitCreation()
        XCTAssertTrue(model.isShowingHabitForm)
        model.goBack()
        XCTAssertEqual(model.step, .obstacle)
        XCTAssertFalse(model.isShowingHabitForm)
        XCTAssertEqual(model.selectedGoal, .focus)
        XCTAssertEqual(model.selectedObstacle, .distractions)
        model.skipCurrentStep()
        XCTAssertEqual(model.step, .habit)
        XCTAssertNil(model.selectedObstacle)
        XCTAssertEqual(model.selectedStarterID, "phone-away")
        model.goBack()
        model.goBack()
        XCTAssertEqual(model.step, .goal)
        model.skipCurrentStep()
        XCTAssertNil(model.selectedGoal)
        model.goBack()
        model.goBack()
        model.goBack()
        XCTAssertEqual(model.step, .welcome)
        model.finish()
        XCTAssertFalse(model.didFinish, "Only the finish stage or explicit Explore First completes setup")
        try assertNoTrackingFacts(fixture)
    }

    func testExplicitHabitSaveAtomicallyPersistsReviewedTargetAndSmallActionThenAdvances() throws {
        let fixture = try Fixture()
        let model = fixture.model
        try fixture.reachHabit()
        model.selectStarter("read")
        var reviewed = try XCTUnwrap(model.selectedHabitDraft)
        reviewed.name = "Read for myself"
        reviewed.quantityTarget = .init(amount: 12, unit: .pages)
        model.requestHabitCreation()
        XCTAssertTrue(model.isShowingHabitForm)
        model.createHabit(reviewed, at: fixture.now)
        XCTAssertEqual(model.step, .companion)
        XCTAssertFalse(model.isShowingHabitForm)
        XCTAssertNil(model.errorMessage)
        let habit = try XCTUnwrap(model.firstHabit)
        let reopened = ModelContext(fixture.container)
        let stored = SwiftDataHabitRepository(modelContext: reopened, calendar: fixture.calendar)
        let activity = SwiftDataHabitActivityRepository(context: reopened, habits: stored, calendar: fixture.calendar)
        XCTAssertEqual(try stored.fetchHabit(id: habit.id)?.name, reviewed.name)
        XCTAssertEqual(try stored.configurationHistory(for: habit.id).count, 1)
        let configuration = try XCTUnwrap(activity.configuration(for: habit.id, on: fixture.now))
        XCTAssertEqual(configuration.target, reviewed.quantityTarget)
        XCTAssertEqual(configuration.smallerAction, reviewed.smallerAction)
        XCTAssertEqual(configuration.effectiveDayKey, LocalDay.key(for: fixture.now, calendar: fixture.calendar))
        XCTAssertTrue(try activity.entries(for: habit.id, on: fixture.now).isEmpty)
        XCTAssertTrue(try stored.completions(in: fixture.range).isEmpty)
        XCTAssertTrue(try fixture.attention.fetchGoals().isEmpty)
    }

    func testBlankCustomFormCanOpenAndCancelledDraftDoesNotCreateAnything() throws {
        let fixture = try Fixture()
        try fixture.reachHabit()
        fixture.model.requestHabitCreation()
        XCTAssertTrue(fixture.model.isShowingHabitForm)
        XCTAssertNil(fixture.model.selectedHabitDraft)
        fixture.model.isShowingHabitForm = false
        XCTAssertEqual(fixture.model.step, .habit)
        try assertNoTrackingFacts(fixture)
    }

    func testInvalidHabitSaveKeepsReviewOpenAndCommitsNoPartialConfiguration() throws {
        let fixture = try Fixture()
        try fixture.reachHabit()
        let model = fixture.model
        model.requestHabitCreation()
        var badTarget = fixture.draft
        badTarget.quantityTarget = .init(amount: 0, unit: .pages)
        var badSchedule = fixture.draft
        badSchedule.schedule = .timesPerWeek(0)
        var badSmallAction = fixture.draft
        badSmallAction.smallerAction = String(repeating: "x", count: 161)
        for draft in [badTarget, badSchedule, badSmallAction] {
            model.createHabit(draft, at: fixture.now)
            XCTAssertEqual(model.step, .habit)
            XCTAssertTrue(model.isShowingHabitForm)
            XCTAssertNil(model.firstHabit)
            XCTAssertNotNil(model.errorMessage)
            try fixture.context.save()
            try assertNoTrackingFacts(fixture)
            XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<HabitConfigurationSnapshotRecord>()).isEmpty)
            XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<HabitActivityConfigurationRecord>()).isEmpty)
        }
        model.createHabit(fixture.draft, at: fixture.now)
        XCTAssertEqual(model.step, .companion)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isShowingHabitForm)
    }

    func testCreationLimitIsCheckedAtFormRequestAndAgainAtExplicitSave() throws {
        var allowed = false
        let fixture = try Fixture(habitCreationAllowed: { _ in allowed })
        try fixture.reachHabit()
        fixture.model.requestHabitCreation()
        XCTAssertFalse(fixture.model.isShowingHabitForm)
        XCTAssertTrue(fixture.model.errorMessage?.contains("Premium") == true)
        allowed = true
        fixture.model.requestHabitCreation()
        XCTAssertTrue(fixture.model.isShowingHabitForm)
        allowed = false
        fixture.model.createHabit(fixture.draft, at: fixture.now)
        XCTAssertEqual(fixture.model.step, .habit)
        XCTAssertTrue(fixture.model.isShowingHabitForm, "A failed save must retain the user's review")
        XCTAssertNil(fixture.model.firstHabit)
        try assertNoTrackingFacts(fixture)
    }

    func testRepeatedCreateAndBackNavigationCannotCreateAnotherOnboardingHabit() throws {
        let fixture = try Fixture()
        try fixture.reachHabit()
        fixture.model.createHabit(fixture.draft, at: fixture.now)
        let id = try XCTUnwrap(fixture.model.firstHabit?.id)
        fixture.model.createHabit(fixture.draft, at: fixture.now)
        fixture.model.goBack()
        XCTAssertEqual(fixture.model.step, .habit)
        fixture.model.requestHabitCreation()
        XCTAssertFalse(fixture.model.isShowingHabitForm)
        fixture.model.createHabit(fixture.draft, at: fixture.now)
        XCTAssertEqual(try fixture.habits.fetchHabits(includeArchived: true).map(\.id), [id])
        XCTAssertEqual(try fixture.habits.configurationHistory(for: id).count, 1)
        XCTAssertEqual(fixture.model.step, .habit)
    }

    func testLoadedOrConcurrentlyCreatedHabitIsKeptWithExistingProgress() throws {
        let fixture = try Fixture()
        try fixture.reachHabit()
        fixture.model.requestHabitCreation()
        let existing = try fixture.habits.createHabit(fixture.draft, at: fixture.now)
        let completion = try fixture.habits.recordCompletion(habitID: existing.id, at: fixture.now, source: .app, note: nil)
        fixture.model.createHabit(fixture.draft, at: fixture.now)
        XCTAssertEqual(fixture.model.firstHabit?.id, existing.id)
        XCTAssertEqual(try fixture.habits.fetchHabits(includeArchived: true).count, 1)
        XCTAssertEqual(try fixture.habits.completions(in: fixture.range).map(\.id), [completion.id])
        let fresh = OnboardingViewModel(habits: fixture.habits, profiles: fixture.profiles)
        fresh.load()
        fresh.advance(); fresh.advance(); fresh.advance()
        fresh.requestHabitCreation()
        XCTAssertFalse(fresh.isShowingHabitForm)
        fresh.createHabit(fixture.draft, at: fixture.now)
        XCTAssertEqual(fresh.firstHabit?.id, existing.id)
        XCTAssertEqual(try fixture.habits.fetchHabits(includeArchived: true).count, 1)
    }

    func testCompanionContinueSavesPreferencesWhileSkipRestoresLoadedPreference() throws {
        let fixture = try Fixture()
        let saved = CompanionProfile(selectedAnimal: .otter, companionEnabled: false, hapticsEnabled: false)
        try fixture.profiles.save(saved)
        try fixture.reachHabit()
        fixture.model.skipCurrentStep()
        fixture.model.profile.selectedAnimal = .fox
        fixture.model.profile.companionEnabled = true
        fixture.model.skipCurrentStep()
        XCTAssertEqual(fixture.model.profile, saved)
        fixture.model.finish()
        var expected = saved
        expected.onboardingCompleted = true
        XCTAssertEqual(try fixture.profiles.profile(), expected)

        let next = try Fixture()
        try next.reachHabit()
        next.model.skipCurrentStep()
        next.model.profile.selectedAnimal = .fox
        next.model.profile.hapticsEnabled = false
        next.model.advance()
        XCTAssertEqual(next.model.step, .finish)
        XCTAssertEqual(try next.profiles.profile().selectedAnimal, .fox)
        next.model.finish()
        XCTAssertEqual(try next.profiles.profile(), next.model.profile)
        XCTAssertFalse(try next.profiles.profile().hapticsEnabled)
    }

    func testSuccessfulLoadDoesNotOverwriteUnacceptedCompanionDraftOnReturn() throws {
        let fixture = try Fixture()
        try fixture.reachHabit()
        fixture.model.skipCurrentStep()
        fixture.model.profile.selectedAnimal = .fox
        fixture.model.profile.companionEnabled = false
        fixture.model.load()
        XCTAssertEqual(fixture.model.step, .companion)
        XCTAssertEqual(fixture.model.profile.selectedAnimal, .fox)
        XCTAssertFalse(fixture.model.profile.companionEnabled)
        XCTAssertEqual(try fixture.profiles.profile(), CompanionProfile())
    }

    func testExploreFirstWorksAtWelcomeAndDiscardsUnacceptedCompanionChanges() throws {
        let fixture = try Fixture()
        fixture.model.load()
        fixture.model.selectGoal(.focus)
        fixture.model.selectObstacle(.distractions)
        fixture.model.selectStarter("phone-away")
        fixture.model.exploreFirst()
        XCTAssertTrue(fixture.model.didFinish)
        try assertNoTrackingFacts(fixture)

        let next = try Fixture()
        let saved = CompanionProfile(selectedAnimal: .otter, companionEnabled: false, hapticsEnabled: false)
        try next.profiles.save(saved)
        try next.reachHabit()
        next.model.skipCurrentStep()
        next.model.profile.selectedAnimal = .fox
        next.model.profile.companionEnabled = true
        next.model.exploreFirst()
        var completed = saved
        completed.onboardingCompleted = true
        XCTAssertEqual(try next.profiles.profile(), completed)
        XCTAssertEqual(next.model.profile, completed)
        try assertNoTrackingFacts(next)
    }

    func testFailedProfileReadCannotOverwritePreferencesAndCanBeRetried() throws {
        let fixture = try Fixture()
        let profiles = FailingProfiles()
        profiles.stored = CompanionProfile(selectedAnimal: .otter, companionEnabled: false)
        profiles.failReads = true
        let model = OnboardingViewModel(habits: fixture.habits, profiles: profiles)
        model.load()
        model.profile.selectedAnimal = .fox
        model.exploreFirst()
        XCTAssertFalse(model.didFinish)
        XCTAssertEqual(profiles.successfulSaves, 0)
        XCTAssertEqual(profiles.stored.selectedAnimal, .otter)
        XCTAssertNotNil(model.errorMessage)
        profiles.failReads = false
        model.exploreFirst()
        XCTAssertTrue(model.didFinish)
        XCTAssertEqual(profiles.stored.selectedAnimal, .otter)
        XCTAssertFalse(profiles.stored.companionEnabled)
        try assertNoTrackingFacts(fixture)
    }

    func testFailedCompanionSaveKeepsDraftAndSkipDoesNotCommitItLater() throws {
        let fixture = try Fixture()
        let profiles = FailingProfiles()
        let model = OnboardingViewModel(habits: fixture.habits, profiles: profiles)
        model.load()
        model.advance(); model.advance(); model.advance(); model.skipCurrentStep()
        XCTAssertEqual(model.step, .companion)
        model.profile.selectedAnimal = .fox
        profiles.failWrites = true
        model.advance()
        XCTAssertEqual(model.step, .companion)
        XCTAssertEqual(model.profile.selectedAnimal, .fox)
        XCTAssertNotNil(model.errorMessage)
        model.skipCurrentStep()
        XCTAssertEqual(model.step, .finish)
        XCTAssertEqual(model.profile.selectedAnimal, .owl)
        model.finish()
        XCTAssertFalse(model.didFinish)
        profiles.failWrites = false
        model.finish()
        XCTAssertTrue(model.didFinish)
        XCTAssertEqual(profiles.stored.selectedAnimal, .owl)
    }

    func testCompletedLoadAndRepeatedCompletionDoNotResaveOrCreateAnything() throws {
        let fixture = try Fixture()
        let profiles = FailingProfiles()
        profiles.stored = CompanionProfile(selectedAnimal: .fox, onboardingCompleted: true)
        let model = OnboardingViewModel(habits: fixture.habits, profiles: profiles)
        model.load()
        XCTAssertTrue(model.didFinish)
        XCTAssertEqual(model.step, .finish)
        model.finish(); model.exploreFirst(); model.goBack(); model.skipCurrentStep()
        model.selectGoal(.focus)
        model.createHabit(fixture.draft, at: fixture.now)
        XCTAssertEqual(profiles.successfulSaves, 0)
        XCTAssertEqual(model.step, .finish)
        XCTAssertNil(model.selectedGoal)
        try assertNoTrackingFacts(fixture)
    }

    private func assertNoTrackingFacts(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(try fixture.habits.fetchHabits(includeArchived: true).isEmpty, file: file, line: line)
        XCTAssertTrue(try fixture.habits.completions(in: fixture.range).isEmpty, file: file, line: line)
        XCTAssertTrue(try fixture.habits.skips(in: fixture.range).isEmpty, file: file, line: line)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<HabitActivityEntryRecord>()).isEmpty, file: file, line: line)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<HabitReminderRecord>()).isEmpty, file: file, line: line)
        XCTAssertTrue(try fixture.attention.fetchGoals().isEmpty, file: file, line: line)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<AttentionSessionRecord>()).isEmpty, file: file, line: line)
    }

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        let habits: SwiftDataHabitRepository
        let attention: SwiftDataAttentionRepository
        let profiles: SwiftDataCompanionProfileRepository
        let model: OnboardingViewModel
        let now = Date(timeIntervalSince1970: 1_792_544_400)
        let calendar: Calendar
        var range: DateInterval { calendar.dateInterval(of: .day, for: now)! }
        var draft: HabitDraft { .init(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily) }

        init(habitCreationAllowed: @escaping (Int) -> Bool = { _ in true }) throws {
            let store = try AppPersistence.makeContainer(inMemory: true)
            var localCalendar = Calendar(identifier: .gregorian)
            localCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
            let newHabits = SwiftDataHabitRepository(modelContext: store.mainContext, calendar: localCalendar)
            let newAttention = SwiftDataAttentionRepository(modelContext: store.mainContext, calendar: localCalendar)
            let newProfiles = SwiftDataCompanionProfileRepository(modelContext: store.mainContext)
            container = store
            calendar = localCalendar
            habits = newHabits
            attention = newAttention
            profiles = newProfiles
            model = OnboardingViewModel(habits: newHabits, profiles: newProfiles, habitCreationAllowed: habitCreationAllowed)
        }

        func reachHabit() throws {
            model.load()
            model.advance(); model.advance(); model.advance()
            XCTAssertEqual(model.step, .habit)
        }
    }
}

@MainActor
private final class FailingProfiles: CompanionProfileRepository {
    enum Failure: Error { case unavailable }
    var stored = CompanionProfile()
    var failReads = false
    var failWrites = false
    private(set) var successfulSaves = 0
    func profile() throws -> CompanionProfile {
        if failReads { throw Failure.unavailable }
        return stored
    }
    func save(_ profile: CompanionProfile) throws {
        if failWrites { throw Failure.unavailable }
        stored = profile
        successfulSaves += 1
    }
}
