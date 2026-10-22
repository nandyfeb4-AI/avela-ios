import SwiftUI
import FamilyControls

struct AppProtectionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let model: AppProtectionModel
    let driver: AppleAppProtectionDriver?
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var savingError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Make space for what matters", systemImage: "hand.raised.circle")
                        .font(.headline)
                    Text("Choose distractions to restrict during a session. Other apps stay available unless you include them. Protection never logs a habit or proves you stayed focused.")
                }
                if !model.isAvailable {
                    Section { Text(AppProtectionError.unavailable.message).accessibilityIdentifier("protection.unavailable") }
                } else if !model.authorized {
                    Section {
                        Button {
                            Task { await model.authorize() }
                        } label: {
                            if model.isRequesting {
                                HStack { ProgressView(); Text("Requesting Access…") }
                            } else {
                                Text("Allow Screen Time Access")
                            }
                        }
                            .disabled(model.isRequesting)
                            .accessibilityIdentifier("protection.authorize")
                        Text("Optional access for your own device. Rilova doesn't read your app usage or send your choices anywhere.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Button("Choose Apps & Websites") { selection = driver?.selection ?? FamilyActivitySelection(); showingPicker = true }
                            .disabled(model.active != nil)
                            .accessibilityIdentifier("protection.choose")
                        Text("\(model.selectionCount) selections saved")
                        Text("Selections stay on this device. You can change them when protection is stopped.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if model.isAvailable {
                    Section("Protection controls") {
                        if let lease = model.active {
                            Text("Ends \(lease.endsAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                        Button("Stop Protection", role: .destructive) { model.stop() }
                            .accessibilityIdentifier("protection.stop")
                        Text("Stopping removes Rilova's restrictions. Other Screen Time limits may still apply; your timer and session result are unchanged.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let message = model.message { Section { Text(message) } }
                if let savingError { Section { Text(savingError) } }
                Section {
                    Text("Protected sessions support 15 minutes to 8 hours. Normal sessions remain available without this permission. You can also revoke access in Settings → Screen Time.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .appThemeCanvas()
            .navigationTitle("App Protection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingPicker) {
                NavigationStack {
                    FamilyActivityPicker(selection: $selection)
                        .navigationTitle("Choose Distractions")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingPicker = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    do {
                                        guard let driver else { throw AppProtectionError.unavailable }
                                        try driver.saveSelection(selection); model.refresh(); savingError = nil
                                    }
                                    catch { savingError = "Your choices couldn't be saved. Stop any active protection and try again." }
                                    showingPicker = false
                                }
                            }
                        }
                }
            }
            .task { model.refresh() }
        }
    }
}

struct AppProtectionStatusView: View {
    let model: AppProtectionModel
    var body: some View {
        if let lease = model.active {
            Section("App protection") {
                Label("Selected distractions restricted", systemImage: "hand.raised.fill")
                Text("Until \(lease.endsAt.formatted(date: .omitted, time: .shortened))")
                Button("Stop Protection", role: .destructive) { model.stop() }
                    .accessibilityIdentifier("protection.stop")
                Text("Your timer and self-reported progress remain separate.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        if let message = model.message {
            Section { Text(message).accessibilityIdentifier("protection.message") }
        }
    }
}

private struct AppProtectionModelKey: EnvironmentKey { static let defaultValue: AppProtectionModel? = nil }
private struct AppProtectionDriverKey: EnvironmentKey { static let defaultValue: AppleAppProtectionDriver? = nil }
extension EnvironmentValues {
    var appProtectionModel: AppProtectionModel? {
        get { self[AppProtectionModelKey.self] }
        set { self[AppProtectionModelKey.self] = newValue }
    }
    var appProtectionDriver: AppleAppProtectionDriver? {
        get { self[AppProtectionDriverKey.self] }
        set { self[AppProtectionDriverKey.self] = newValue }
    }
}
