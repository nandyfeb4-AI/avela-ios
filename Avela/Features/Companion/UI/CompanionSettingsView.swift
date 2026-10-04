import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class CompanionSettingsViewModel {
    var profile = CompanionProfile()
    var errorMessage: String?
    private let repository: CompanionProfileRepository
    init(repository: CompanionProfileRepository) { self.repository = repository }
    func load() {
        do { profile = try repository.profile() }
        catch { handle(error) }
    }
    func save() {
        do { try repository.save(profile) }
        catch { handle(error) }
    }
    private func handle(_ error: Error) {
        Logger(subsystem: "com.example.Avela", category: "CompanionSettings").error("Profile operation failed: \(String(describing: error), privacy: .private)")
        errorMessage = "Couldn't update your preferences. Please try again."
    }
}

struct CompanionSettingsView: View {
    @State private var viewModel: CompanionSettingsViewModel
    init(repository: CompanionProfileRepository) {
        _viewModel = State(initialValue: CompanionSettingsViewModel(repository: repository))
    }
    var body: some View {
        @Bindable var model = viewModel
        Form {
            Section("Companion") {
                Toggle("Show companion", isOn: $model.profile.companionEnabled)
                CompanionSelectionView(selectedAnimal: $model.profile.selectedAnimal)
            }
            Section("Feedback") {
                Toggle("Haptics", isOn: $model.profile.hapticsEnabled)
            }
            Button("Save Preferences") { model.save() }
                .accessibilityIdentifier("companion.savePreferences")
        }
        .navigationTitle("Companion & Feedback")
        .task { model.load() }
        .alert("Preferences Couldn’t Be Saved", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
    }
}
