import XCTest
import SwiftData
import UIKit
@testable import Avela

@MainActor
final class CompanionTests: XCTestCase {
    func testSettingsConfirmationFollowsSaveAndClearsForEveryEditablePreference() throws {
        let repository = SettingsProfileRepository()
        repository.stored.onboardingCompleted = true
        let model = CompanionSettingsViewModel(repository: repository)
        model.load()
        XCTAssertFalse(model.didSave)

        model.profile.selectedAnimal = .fox
        XCTAssertEqual(try repository.profile().selectedAnimal, .owl, "Selection remains a draft until Save")
        model.save()
        XCTAssertTrue(model.didSave)
        XCTAssertEqual(try repository.profile(), model.profile)
        XCTAssertTrue(try repository.profile().onboardingCompleted)

        model.profile.companionEnabled = false
        XCTAssertFalse(model.didSave)
        XCTAssertTrue(try repository.profile().companionEnabled)
        model.save()
        XCTAssertTrue(model.didSave)

        model.profile.hapticsEnabled = false
        XCTAssertFalse(model.didSave)
        model.save()
        XCTAssertTrue(model.didSave)

        model.profile.selectedAnimal = .otter
        XCTAssertFalse(model.didSave)
        model.save()
        XCTAssertTrue(model.didSave)
        XCTAssertEqual(try repository.profile(), model.profile)
        XCTAssertTrue(try repository.profile().onboardingCompleted)
    }

    func testSettingsFailedSaveClearsOldConfirmationAndAllowsRetryWithDraftIntact() {
        let repository = SettingsProfileRepository()
        let model = CompanionSettingsViewModel(repository: repository)
        model.load()
        model.save()
        XCTAssertTrue(model.didSave)

        repository.failWrites = true
        model.save()
        XCTAssertFalse(model.didSave, "An earlier successful save must not mask a failed one")
        XCTAssertEqual(model.errorMessage, "Couldn't update your preferences. Please try again.")

        model.profile.selectedAnimal = .otter
        model.profile.hapticsEnabled = false
        let draft = model.profile
        model.save()
        XCTAssertFalse(model.didSave)
        XCTAssertEqual(model.profile, draft)
        XCTAssertEqual(repository.stored.selectedAnimal, .owl)

        repository.failWrites = false
        model.save()
        XCTAssertTrue(model.didSave)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(repository.stored, draft)
    }

    func testSettingsReloadFailureClearsConfirmationAndPreservesCurrentDraft() {
        let repository = SettingsProfileRepository()
        let model = CompanionSettingsViewModel(repository: repository)
        model.load()
        model.save()
        XCTAssertTrue(model.didSave)
        let draft = model.profile

        repository.failReads = true
        model.load()
        XCTAssertFalse(model.didSave)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.profile, draft)
    }

    func testFourPresentationStatesUseDistinctExistingPosesForEveryAnimal() throws {
        XCTAssertEqual(CompanionPresentationState.allCases.count, 4)
        for animal in CompanionAnimal.allCases {
            var poses = Set<Data>()
            for state in CompanionPresentationState.allCases {
                let image = try XCTUnwrap(CompanionArtwork.image(animal: animal.rawValue, state: state.artworkState.rawValue))
                poses.insert(try XCTUnwrap(image.pngData()))
            }
            XCTAssertEqual(poses.count, 4)
        }
    }

    func testPresentationProgressIsRecordedRatherThanTransientOrInferred() {
        var input = CompanionInput(meaningfulCompletion: true, hasActiveSession: true, dueHabits: 20)
        XCTAssertEqual(CompanionPresentation.state(for: input), .steady)
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("session is running"))
        input.completedHabits = 1
        input.meaningfulCompletion = false
        XCTAssertEqual(CompanionPresentation.state(for: input), .buildingMomentum)
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("1 habit logged today"))
        input.completedHabits = 2
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("2 habits logged today"))
    }

    func testPresentationKeepsBudgetFactsAndRecoveryAheadOfProgress() {
        var input = CompanionInput(loggedAttentionStates: [.exceeded], isRecovering: true, completedHabits: 2)
        XCTAssertEqual(CompanionPresentation.state(for: input), .needsSpace)
        XCTAssertEqual(CompanionPresentation.state(for: input).title, "Logged budget exceeded")
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("manually logged"))
        XCTAssertFalse(CompanionPresentation.message(for: input).contains("overloaded"))
        input.loggedAttentionStates = [.nearLimit]
        XCTAssertEqual(CompanionPresentation.state(for: input), .recovering)
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("close to a budget"))
        input.isRecovering = false
        XCTAssertEqual(CompanionPresentation.state(for: input), .buildingMomentum)
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("close to a budget"))
        input.completedHabits = 0
        XCTAssertEqual(CompanionPresentation.state(for: input), .steady)
        XCTAssertTrue(CompanionPresentation.message(for: input).contains("manually logged"))
    }

    func testMissingRecordsNeverInferOverloadOrHealthyAttention() {
        let input = CompanionInput(attentionGoalCount: 4, dueHabits: 100)
        XCTAssertEqual(CompanionPresentation.state(for: input), .steady)
        let message = CompanionPresentation.message(for: input).lowercased()
        XCTAssertTrue(message.contains("isn't fully logged"))
        for unsupportedClaim in ["healthy", "on track", "overloaded", "failed"] {
            XCTAssertFalse(message.contains(unsupportedClaim))
        }
    }

    func testEveryAnimalAndStateLoadsDistinctBundledArtwork() throws {
        for animal in CompanionAnimal.allCases {
            var poses = Set<Data>()
            for state in CompanionState.allCases {
                let image = try XCTUnwrap(CompanionArtwork.image(animal: animal.rawValue, state: state.rawValue))
                XCTAssertGreaterThan(image.size.width, 128)
                XCTAssertGreaterThan(image.size.height, 128)
                poses.insert(try XCTUnwrap(image.pngData()))
            }
            XCTAssertEqual(poses.count, 6, "Every state must have its own pose, not a reused placeholder")
        }
    }

    func testUnknownWidgetArtworkValuesFailSafely() {
        XCTAssertNil(CompanionArtwork.image(animal: "unknown", state: "calm"))
        XCTAssertNil(CompanionArtwork.image(animal: "owl", state: "unknown"))
    }

    func testLargeOnboardingArtworkKeepsCompactWidgetCacheSeparate() throws {
        for animal in CompanionAnimal.allCases {
            let compact = try XCTUnwrap(CompanionArtwork.image(animal: animal.rawValue, state: "calm"))
            let hero = try XCTUnwrap(CompanionArtwork.image(animal: animal.rawValue, state: "calm", highResolution: true))
            XCTAssertGreaterThan(hero.size.width, compact.size.width,
                                 "The onboarding hero needs a larger image than a compact widget")
            XCTAssertLessThanOrEqual(compact.size.width, 256,
                                     "Loading a hero must not enlarge extension artwork")
            XCTAssertTrue(compact === CompanionArtwork.image(animal: animal.rawValue, state: "calm"))
            XCTAssertTrue(hero === CompanionArtwork.image(animal: animal.rawValue, state: "calm", highResolution: true))
        }
        XCTAssertNil(CompanionArtwork.image(animal: "unknown", state: "calm", highResolution: true))
        XCTAssertNil(CompanionArtwork.image(animal: "owl", state: "unknown", highResolution: true))
    }

    func testStatePriorityPreservesAttentionWarningsOverCelebration() {
        var input = CompanionInput(loggedAttentionStates: [.exceeded, .nearLimit], attentionGoalCount: 2,
                                   isRecovering: true, meaningfulCompletion: true,
                                   hasActiveSession: true, completedHabits: 1, dueHabits: 2)
        XCTAssertEqual(CompanionStateEngine.state(for: input), .overloaded)
        input.loggedAttentionStates = [.nearLimit]
        XCTAssertEqual(CompanionStateEngine.state(for: input), .nearLimit)
        input.loggedAttentionStates = []
        XCTAssertEqual(CompanionStateEngine.state(for: input), .recovering)
        input.isRecovering = false
        XCTAssertEqual(CompanionStateEngine.state(for: input), .celebrating)
        input.meaningfulCompletion = false
        XCTAssertEqual(CompanionStateEngine.state(for: input), .focused)
        input.hasActiveSession = false
        XCTAssertEqual(CompanionStateEngine.state(for: input), .calm)
    }

    func testMissingAttentionDataDoesNotClaimHealthyOrOnTrack() {
        let input = CompanionInput(attentionGoalCount: 1)
        XCTAssertEqual(CompanionStateEngine.state(for: input), .calm)
        let message = CompanionStateEngine.message(for: input).lowercased()
        XCTAssertFalse(message.contains("on track"))
        XCTAssertFalse(message.contains("healthy"))
        XCTAssertTrue(message.contains("log"))
    }

    func testNoHabitDoesNotGenerateCelebration() {
        let input = CompanionInput(meaningfulCompletion: true)
        XCTAssertEqual(CompanionStateEngine.state(for: input), .calm)
    }

    func testKnownAttentionWarningsRemainVisibleEvenWithMissingGoals() {
        let input = CompanionInput(loggedAttentionStates: [.exceeded], attentionGoalCount: 3)
        XCTAssertEqual(CompanionStateEngine.state(for: input), .overloaded)
        XCTAssertTrue(CompanionStateEngine.message(for: input).contains("logged usage"))
    }

    func testProfileDefaultsAndUpdatesPreserveOneRecord() throws {
        let schema = Schema([CompanionProfileRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let repository = SwiftDataCompanionProfileRepository(modelContext: container.mainContext)
        XCTAssertFalse(try repository.profile().onboardingCompleted)
        var profile = try repository.profile()
        profile.selectedAnimal = .otter
        profile.companionEnabled = false
        profile.hapticsEnabled = false
        profile.onboardingCompleted = true
        try repository.save(profile)
        try repository.save(profile)
        XCTAssertEqual(try repository.profile(), profile)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<CompanionProfileRecord>()), 1)
    }

    func testProfileSurvivesDiskReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([CompanionProfileRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("profile.store"), cloudKitDatabase: .none)
        let expected = CompanionProfile(selectedAnimal: .fox, companionEnabled: true, hapticsEnabled: false, onboardingCompleted: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try SwiftDataCompanionProfileRepository(modelContext: container.mainContext).save(expected)
        }
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        XCTAssertEqual(try SwiftDataCompanionProfileRepository(modelContext: reopened.mainContext).profile(), expected)
    }
}

@MainActor
private final class SettingsProfileRepository: CompanionProfileRepository {
    var stored = CompanionProfile()
    var failReads = false
    var failWrites = false
    private enum Failure: Error { case unavailable }

    func profile() throws -> CompanionProfile {
        if failReads { throw Failure.unavailable }
        return stored
    }

    func save(_ profile: CompanionProfile) throws {
        if failWrites { throw Failure.unavailable }
        stored = profile
    }
}
