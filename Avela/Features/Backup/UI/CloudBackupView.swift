import SwiftUI

struct CloudBackupView: View {
    @Bindable var model: CloudBackupModel
    var onRestore: () -> Void = {}
    @State private var deleteCandidate: CloudBackupSummary?
    var body: some View {
        List {
            Section {
                Text("Keep dated recovery copies in your private iCloud storage. Local tracking works offline. This is backup, not live sync between devices.")
                Toggle("Automatic iCloud backup", isOn: Binding(get: { model.isEnabled }, set: { enabled in Task { await model.setEnabled(enabled) } }))
                    .disabled(model.isBusy || !model.isConfigured)
                    .accessibilityIdentifier("backup.enabled")
                if !model.isConfigured {
                    Text("iCloud backup isn't available in this build. Your tracking remains on this device.").foregroundStyle(.secondary)
                }
                if let date = model.lastSuccessfulBackup {
                    LabeledContent("Last successful backup", value: date.formatted(date: .abbreviated, time: .shortened))
                        .accessibilityIdentifier("backup.lastSuccess")
                } else {
                    Text("No confirmed cloud backup date is available.").foregroundStyle(.secondary)
                }
                if model.isEnabled {
                    Button("Back Up Now") { Task { await model.backupNow() } }
                        .disabled(model.isBusy).accessibilityIdentifier("backup.now")
                }
            } header: {
                Text("Protect Your Progress")
            } footer: {
                Text("Runs after saved changes while Avela is active, up to once every 10 minutes. Offline, account and storage problems can delay backups. Turning it off keeps existing cloud copies; an upload already sent may finish.")
            }
            Section("What Is Included") {
                Text("Eligible habits and their history, manual attention tracking, routines and appearance preferences.")
                Text("Health-connected habits, health/fitness habits, Health-imported history and private notes (including habit reasons) stay on this device. They are excluded from Avela cloud backups.")
                Text("Keep sensitive health tracking in Health/Fitness categories; don’t use other categories to include it in cloud recovery.").foregroundStyle(.secondary)
                Text("Recovery copies are kept until you delete them and use iCloud storage. No separate Avela account or paid tier is required.")
            }
            Section("Recovery Points") {
                Button("Check iCloud Backups") { Task { await model.loadBackups() } }
                    .disabled(model.isBusy || !model.isConfigured).accessibilityIdentifier("backup.refresh")
                ForEach(model.backups) { backup in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                        Button { Task { await model.prepareRestore(backup) } } label: {
                            Text("Review Restore").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                            .disabled(model.isBusy || !model.canRestore)
                        Button(role: .destructive) { deleteCandidate = backup } label: {
                            Text("Delete Cloud Copy").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                            .disabled(model.isBusy)
                    }
                    .buttonStyle(.borderless)
                }
                if !model.canRestore {
                    Text("This installation already has tracking data. Restore won't overwrite it. Recovery is available on a new installation before you start tracking.").foregroundStyle(.secondary)
                }
            }
            if model.isBusy { ProgressView("Checking iCloud…") }
            if let message = model.message {
                Section { Text(message).accessibilityIdentifier("backup.message") }
            }
        }
        .appThemeCanvas()
        .navigationTitle("Progress Protection")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("backup.screen")
        .task { model.refreshRestoreEligibility() }
        .alert("Restore Tracking History?", isPresented: Binding(get: { model.preview != nil }, set: { presented in
            if !presented { Task { @MainActor in model.cancelRestore() } }
        })) {
            Button("Cancel", role: .cancel) { model.cancelRestore() }
            Button("Restore") { if model.confirmRestore() { onRestore() } }
        } message: {
            Text("\(model.previewHabitCount) habits and \(model.previewGoalCount) attention goals. Health tracking and private notes aren't included. Reminders remain off and timers are paused. Restore is permitted only without existing tracking history.")
        }
        .alert("Delete This Recovery Point?", isPresented: Binding(get: { deleteCandidate != nil }, set: { presented in
            if !presented { Task { @MainActor in deleteCandidate = nil } }
        })) {
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
            Button("Delete", role: .destructive) {
                if let value = deleteCandidate { Task { await model.deleteBackup(value) } }
                deleteCandidate = nil
            }
        } message: { Text("This deletes only the selected cloud copy. Your local progress and other recovery points remain.") }
    }
}
