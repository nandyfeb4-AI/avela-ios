import Foundation
import SwiftData

@Model
final class CompanionProfileRecord {
    @Attribute(.unique) var profileID: String
    var selectedAnimalRaw: String
    var companionEnabled: Bool
    var hapticsEnabled: Bool
    var onboardingCompleted: Bool

    init(profile: CompanionProfile) {
        profileID = "primary"
        selectedAnimalRaw = profile.selectedAnimal.rawValue
        companionEnabled = profile.companionEnabled
        hapticsEnabled = profile.hapticsEnabled
        onboardingCompleted = profile.onboardingCompleted
    }

    var domain: CompanionProfile {
        CompanionProfile(selectedAnimal: CompanionAnimal(rawValue: selectedAnimalRaw) ?? .owl,
                         companionEnabled: companionEnabled, hapticsEnabled: hapticsEnabled,
                         onboardingCompleted: onboardingCompleted)
    }
}

@MainActor
final class SwiftDataCompanionProfileRepository: CompanionProfileRepository {
    private let modelContext: ModelContext
    init(modelContext: ModelContext) { self.modelContext = modelContext }

    func profile() throws -> CompanionProfile {
        try record()?.domain ?? CompanionProfile()
    }

    func save(_ profile: CompanionProfile) throws {
        if let existing = try record() {
            existing.selectedAnimalRaw = profile.selectedAnimal.rawValue
            existing.companionEnabled = profile.companionEnabled
            existing.hapticsEnabled = profile.hapticsEnabled
            existing.onboardingCompleted = profile.onboardingCompleted
        } else { modelContext.insert(CompanionProfileRecord(profile: profile)) }
        try modelContext.save()
    }

    private func record() throws -> CompanionProfileRecord? {
        let query = FetchDescriptor<CompanionProfileRecord>(predicate: #Predicate { $0.profileID == "primary" })
        return try modelContext.fetch(query).first
    }
}
