import XCTest
import SwiftData
@testable import Avela

@MainActor
final class OnboardingTests: XCTestCase {
    func testOptionalStepsCanBeSkippedWithoutCreatingData() throws {
        let fixture = try Fixture()
        let model = fixture.model
        model.load()
        for expected in [OnboardingStep.habit, .attention, .companion, .reminder, .finish] {
            model.advance()
            XCTAssertEqual(model.step, expected)
        }
        model.finish()
        XCTAssertTrue(model.didFinish)
        XCTAssertTrue(try fixture.profiles.profile().onboardingCompleted)
        XCTAssertTrue(try fixture.habits.fetchHabits(includeArchived: true).isEmpty)
        XCTAssertTrue(try fixture.attention.fetchGoals().isEmpty)
    }

    func testCreatingFirstGoalsPersistsAndAdvancesSequence() throws {
        let fixture = try Fixture()
        let model = fixture.model
        model.load()
        model.advance()
        model.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily))
        XCTAssertEqual(model.step, .attention)
        XCTAssertEqual(try fixture.habits.fetchHabits(includeArchived: true).count, 1)
        model.createAttentionGoal(AttentionGoalDraft(name: "Social", appOrCategoryLabel: nil, type: .maxDurationPerDay, targetValue: 30, unit: .minutes))
        XCTAssertEqual(model.step, .companion)
        XCTAssertTrue(model.hasAttentionGoal)
        model.profile.selectedAnimal = .otter
        model.advance()
        XCTAssertEqual(try fixture.profiles.profile().selectedAnimal, .otter)
        model.advance()
        model.finish()
        XCTAssertTrue(try fixture.profiles.profile().onboardingCompleted)
    }

    func testFailedCreationDoesNotAdvanceOrDismissForm() throws {
        let fixture = try Fixture()
        fixture.model.load()
        fixture.model.advance()
        fixture.model.isShowingHabitForm = true
        fixture.model.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .timesPerWeek(0)))
        XCTAssertEqual(fixture.model.step, .habit)
        XCTAssertTrue(fixture.model.isShowingHabitForm)
        XCTAssertNotNil(fixture.model.errorMessage)
    }

    func testHabitCreationLimitIsCheckedBeforeWritingDuringOnboarding() throws {
        let fixture = try Fixture(habitCreationAllowed: { _ in false })
        fixture.model.load()
        fixture.model.advance()
        fixture.model.createHabit(HabitDraft(name: "Read", iconName: "book.fill", category: .learning, polarity: .positive, schedule: .daily))
        XCTAssertTrue(try fixture.habits.fetchHabits(includeArchived: true).isEmpty)
        XCTAssertEqual(fixture.model.step, .habit)
        XCTAssertTrue(fixture.model.errorMessage?.contains("Premium") == true)
    }

    func testAttentionCreationLimitIsCheckedBeforeWritingDuringOnboarding() throws {
        let fixture = try Fixture(attentionCreationAllowed: { _ in false })
        fixture.model.load()
        fixture.model.advance()
        fixture.model.advance()
        fixture.model.createAttentionGoal(AttentionGoalDraft(name: "Social", appOrCategoryLabel: nil, type: .maxDurationPerDay, targetValue: 30, unit: .minutes))
        XCTAssertTrue(try fixture.attention.fetchGoals().isEmpty)
        XCTAssertEqual(fixture.model.step, .attention)
        XCTAssertTrue(fixture.model.errorMessage?.contains("Premium") == true)
    }

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        let habits: SwiftDataHabitRepository
        let attention: SwiftDataAttentionRepository
        let profiles: SwiftDataCompanionProfileRepository
        let model: OnboardingViewModel
        init(habitCreationAllowed: @escaping (Int) -> Bool = { _ in true },
             attentionCreationAllowed: @escaping (Int) -> Bool = { _ in true }) throws {
            let schema = Schema([HabitRecord.self, HabitConfigurationSnapshotRecord.self, CompletionRecord.self,
                                 SkipRecord.self, HabitArchivePeriodRecord.self, AttentionGoalRecord.self,
                                 AttentionGoalConfigurationSnapshotRecord.self, AttentionUsageEntryRecord.self,
                                 CompanionProfileRecord.self])
            let newContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            let newHabits = SwiftDataHabitRepository(modelContext: newContainer.mainContext)
            let newAttention = SwiftDataAttentionRepository(modelContext: newContainer.mainContext)
            let newProfiles = SwiftDataCompanionProfileRepository(modelContext: newContainer.mainContext)
            container = newContainer
            habits = newHabits
            attention = newAttention
            profiles = newProfiles
            model = OnboardingViewModel(habits: newHabits, attention: newAttention, profiles: newProfiles,
                habitCreationAllowed: habitCreationAllowed, attentionCreationAllowed: attentionCreationAllowed)
        }
    }
}
