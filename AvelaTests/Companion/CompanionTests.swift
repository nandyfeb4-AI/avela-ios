import XCTest
import SwiftData
import UIKit
@testable import Avela

@MainActor
final class CompanionTests: XCTestCase {
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
