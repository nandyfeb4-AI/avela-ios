import Foundation
import Observation

@MainActor @Observable
final class CloudBackupModel {
    private let store: BackupStore
    private let provider: any CloudBackupProvider
    private let defaults: UserDefaults
    private var queuedBackup: Task<Void, Never>?
    private var generation = 0
    private var lastDigest: String?
    private(set) var isBusy = false
    private(set) var backups: [CloudBackupSummary] = []
    private(set) var preview: BackupArchive?
    private(set) var previewHabitCount = 0
    private(set) var previewGoalCount = 0
    private(set) var excludedHealthHabitCount = 0
    var message: String?
    private(set) var isEnabled: Bool
    private(set) var lastSuccessfulBackup: Date?
    var isConfigured: Bool { provider.isConfigured }
    var shouldShowSettings: Bool {
        #if DEBUG
        return true
        #else
        return isConfigured
        #endif
    }
    private(set) var canRestore = false
    private let consentKey = "avela.cloudBackup.accountConsent"
    private let successKey = "avela.cloudBackup.lastSuccess"

    init(store: BackupStore, provider: any CloudBackupProvider, defaults: UserDefaults = .standard) {
        self.store = store; self.provider = provider; self.defaults = defaults
        isEnabled = defaults.string(forKey: consentKey) != nil
        lastSuccessfulBackup = defaults.object(forKey: successKey) as? Date
        refreshRestoreEligibility()
    }
    func refreshRestoreEligibility() { canRestore = (try? store.canRestore()) == true }
    private var deviceID: String {
        if let existing = defaults.string(forKey: "avela.cloudBackup.deviceID") { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: "avela.cloudBackup.deviceID")
        return id
    }
    func setEnabled(_ enabled: Bool) async {
        if !enabled { disable(); return }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let currentGeneration = generation
        do {
            let identity = try await provider.accountIdentity()
            guard generation == currentGeneration else { return }
            defaults.set(identity, forKey: consentKey)
            isEnabled = true
            message = nil
        } catch { message = BackupError.unavailable.localizedDescription }
        if isEnabled { scheduleBackup() }
    }
    func disable() {
        generation += 1
        queuedBackup?.cancel(); queuedBackup = nil
        isEnabled = false
        defaults.removeObject(forKey: consentKey)
        defaults.removeObject(forKey: successKey)
        lastSuccessfulBackup = nil
        lastDigest = nil
        preview = nil; backups = []
        message = "Automatic backup is off. Existing iCloud backups are kept."
    }
    /// Account changes revoke consent. Never silently upload under a new account.
    func accountDidChange() {
        disable()
        message = BackupError.accountChanged.localizedDescription
    }
    func scheduleBackup() {
        guard isEnabled else { return }
        queuedBackup?.cancel()
        let remaining = lastSuccessfulBackup.map { max(0, min(600, 600 - Date().timeIntervalSince($0))) } ?? 0
        queuedBackup = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(max(15, remaining))) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.backupNow(automatic: true)
        }
    }
    private func verifiedAccount() async throws -> String {
        let identity = try await provider.accountIdentity()
        guard !Task.isCancelled else { throw CancellationError() }
        guard let consent = defaults.string(forKey: consentKey), consent == identity else {
            accountDidChange()
            throw BackupError.accountChanged
        }
        return identity
    }
    func backupNow(automatic: Bool = false, at date: Date = Date()) async {
        guard isEnabled, !isBusy else { return }
        if automatic, let lastSuccessfulBackup, date.timeIntervalSince(lastSuccessfulBackup) < 600 { return }
        isBusy = true
        defer { isBusy = false }
        let currentGeneration = generation
        do {
            _ = try await verifiedAccount()
            guard generation == currentGeneration, isEnabled else { return }
            let archive = try store.capture(at: date)
            excludedHealthHabitCount = archive.excludedHealthHabitCount
            if automatic && archive.checksum == lastDigest { return }
            try await provider.upload(archive, deviceID: deviceID)
            guard generation == currentGeneration, isEnabled else { return }
            lastSuccessfulBackup = date
            lastDigest = archive.checksum
            defaults.set(date, forKey: successKey)
            message = "Eligible tracking was backed up to your private iCloud storage."
            // Immutable snapshots are kept until the user explicitly deletes one.
            // An upload never overwrites an earlier recovery point.
        } catch is CancellationError { }
        catch { message = (error as? BackupError)?.localizedDescription ?? "Backup didn't finish. Your local progress is safe. Check iCloud and your connection, then try again." }
    }
    func loadBackups() async {
        guard !isBusy else { return }
        refreshRestoreEligibility()
        isBusy = true; defer { isBusy = false }
        let currentGeneration = generation
        do {
            _ = try await provider.accountIdentity()
            let result = try await provider.list()
            guard generation == currentGeneration else { return }
            backups = result; message = nil
        } catch { backups = []; message = "Couldn't load iCloud backups. Your local progress is unchanged." }
    }
    func prepareRestore(_ summary: CloudBackupSummary) async {
        guard !isBusy else { return }
        preview = nil
        isBusy = true; defer { isBusy = false }
        let currentGeneration = generation
        do {
            guard try store.canRestore() else { throw BackupError.existingHistory }
            _ = try await provider.accountIdentity()
            let archive = try await provider.download(id: summary.id)
            let payload = try archive.verifiedPayload()
            guard generation == currentGeneration else { return }
            previewHabitCount = payload.habitRecords.count
            previewGoalCount = payload.attentionGoalRecords.count
            preview = archive; message = nil
        } catch { message = (error as? BackupError)?.localizedDescription ?? "Couldn't verify this backup. Nothing was restored." }
    }
    @discardableResult
    func confirmRestore() -> Bool {
        guard let archive = preview, !isBusy else { return false }
        do {
            try store.restore(archive)
            refreshRestoreEligibility()
            preview = nil
            message = "Tracking history restored. Reminders need enabling again; timers are paused."
            NotificationCenter.default.post(name: .avelaPersistenceDidChange, object: nil)
            return true
        } catch { preview = nil; message = (error as? BackupError)?.localizedDescription ?? "Restore didn't finish. Your existing data is unchanged."; return false }
    }
    func cancelRestore() { preview = nil }
    func deleteBackup(_ summary: CloudBackupSummary) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        let currentGeneration = generation
        do {
            _ = try await provider.accountIdentity()
            try await provider.delete(id: summary.id)
            guard generation == currentGeneration else { return }
            backups.removeAll { $0.id == summary.id }
            if backups.isEmpty { defaults.removeObject(forKey: successKey); lastSuccessfulBackup = nil; lastDigest = nil }
            message = "This iCloud recovery point was deleted. Local tracking is unchanged."
        } catch { message = "Couldn't delete that backup. Please try again." }
    }
}
