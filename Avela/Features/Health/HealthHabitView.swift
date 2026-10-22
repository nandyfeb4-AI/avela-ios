import Observation
import SwiftUI
import UIKit

private struct HealthHabitServiceKey: EnvironmentKey {
    static let defaultValue: HealthHabitService? = nil
}
extension EnvironmentValues {
    var healthHabitService: HealthHabitService? {
        get { self[HealthHabitServiceKey.self] }
        set { self[HealthHabitServiceKey.self] = newValue }
    }
}

@MainActor @Observable
final class HealthHabitSettingsModel {
    let habitID: UUID
    let service: HealthHabitService
    private let currentDate: () -> Date
    var metric: HealthHabitMetric = .steps {
        didSet {
            if metric != oldValue {
                target = String(metric.defaultTarget)
                clearConfirmation()
            }
        }
    }
    var target = "5000" { didSet { if target != oldValue { clearConfirmation() } } }
    private(set) var connected = false
    private(set) var isSaving = false
    private(set) var isRefreshing = false
    private(set) var didSave = false
    private var refreshCompleted = false
    var didRefresh: Bool {
        refreshCompleted && service.isAvailable && !service.isRefreshing && service.refreshError == nil
            && service.completedRefreshHabitIDs.contains(habitID)
    }
    private var showsHealthFeedback = false
    private var disconnectedMessage: String?
    var feedback: String? {
        guard !isWorking, !service.isRefreshing else { return nil }
        if let disconnectedMessage { return disconnectedMessage }
        guard connected, showsHealthFeedback else { return nil }
        return service.refreshError ?? service.messages[habitID]
    }
    var errorMessage: String?
    var isWorking: Bool { isSaving || isRefreshing }

    init(habitID: UUID, service: HealthHabitService, currentDate: @escaping () -> Date = Date.init) {
        self.habitID = habitID
        self.service = service
        self.currentDate = currentDate
    }

    func load() {
        clearConfirmation()
        errorMessage = nil
        do {
            if let connection = try service.connection(for: habitID) {
                connected = true
                metric = connection.metric
                target = String(connection.target)
                showsHealthFeedback = true
            } else { connected = false }
        } catch { errorMessage = "Your connection couldn't be loaded. Try again." }
    }

    func save() async {
        guard !isWorking else { return }
        clearConfirmation()
        errorMessage = nil
        guard let amount = Double(target), amount.isFinite, amount > 0, amount <= metric.maximumTarget else {
            errorMessage = "Enter a positive target within the displayed limit."
            return
        }
        let savedMetric = metric
        let savedTarget = target
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.connect(habitID: habitID, metric: savedMetric, target: amount, at: currentDate())
            connected = true
            await service.refresh(at: currentDate())
            // Only acknowledge the configuration that actually reached storage.
            guard metric == savedMetric, target == savedTarget else { return }
            didSave = true
            showsHealthFeedback = true
        } catch let error as HealthHabitError { errorMessage = error.errorDescription }
        catch { errorMessage = "Your Health connection couldn't be saved. Manual logging still works." }
    }

    func refresh() async {
        guard connected, service.isAvailable, !isWorking, !service.isRefreshing else { return }
        refreshCompleted = false
        showsHealthFeedback = false
        errorMessage = nil
        isRefreshing = true
        defer { isRefreshing = false }
        await service.refresh(at: currentDate())
        refreshCompleted = !service.isRefreshing && service.refreshError == nil
            && service.completedRefreshHabitIDs.contains(habitID)
        showsHealthFeedback = true
    }

    func disconnect() {
        guard !isWorking else { return }
        clearConfirmation()
        errorMessage = nil
        do {
            try service.disconnect(habitID: habitID)
            connected = false
            disconnectedMessage = "Disconnected. Existing completions are kept."
        } catch { errorMessage = "Your connection couldn't be removed. Try again." }
    }

    private func clearConfirmation() {
        didSave = false
        refreshCompleted = false
        showsHealthFeedback = false
        disconnectedMessage = nil
    }
}

struct HealthHabitView: View {
    @State private var model: HealthHabitSettingsModel

    init(habitID: UUID, service: HealthHabitService) {
        _model = State(initialValue: HealthHabitSettingsModel(habitID: habitID, service: service))
    }

    var body: some View {
        Form {
            Section {
                Text("Automatically log this habit when today's Apple Health target is reached. Rilova checks when you open it or tap Refresh; background updates aren't promised.")
                Text("Only today's steps or exercise minutes are read. No data is written to Apple Health, and no health samples are stored or uploaded by Rilova.")
            }
            Section {
                Picker("Metric", selection: $model.metric) {
                    ForEach(HealthHabitMetric.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .disabled(model.isWorking)
                .accessibilityIdentifier("health.metricPicker")
                TextField("Target", text: $model.target).keyboardType(.decimalPad)
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("health.targetField")
                Text("Choose more than 0 and no more than \(model.metric.maximumTarget.formatted()) \(model.metric.label.lowercased()).")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    Task {
                        await model.save()
                        if model.didSave {
                            UIAccessibility.post(notification: .announcement, argument: "Health connection saved.")
                        }
                    }
                } label: {
                    if model.isSaving {
                        HStack { ProgressView(); Text("Saving…") }
                    } else if model.didSave {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                    } else {
                        Text(model.connected ? "Update Connection" : "Connect Apple Health")
                    }
                }
                .disabled(model.isWorking || !model.service.isAvailable)
                .accessibilityIdentifier("health.connectButton")
            } header: { Text("Your Target") } footer: {
                Text("Apple asks for read access only when you connect. No accessible data may mean no samples or limited access; Rilova cannot distinguish the two. Manual logging remains available.")
            }
            if model.connected {
                Section {
                    Button { Task { await model.refresh() } } label: {
                        if model.isRefreshing || model.service.isRefreshing {
                            HStack { ProgressView(); Text("Refreshing…") }
                        } else if model.didRefresh {
                            Label("Health Checked", systemImage: "checkmark.circle.fill")
                        } else {
                            Text("Refresh Apple Health")
                        }
                    }
                    .disabled(!model.service.isAvailable || model.service.isRefreshing || model.isWorking)
                    .accessibilityLabel(model.isRefreshing || model.service.isRefreshing ? "Refreshing Apple Health" : model.didRefresh ? "Health check finished" : "Refresh Apple Health")
                    .accessibilityIdentifier("health.refreshButton")
                    Button("Disconnect", role: .destructive) { model.disconnect() }
                        .disabled(model.isWorking)
                } header: { Text("Connection") } footer: {
                    Text("Existing completions are kept. A skipped day isn't automatically completed. Undoing an imported completion can be followed by another import while the connection is active; disconnect to stop future imports. Manage Health permissions separately in Apple Health.")
                }
            }
            if let feedback = model.feedback {
                Section { Text(feedback).accessibilityIdentifier("health.feedback") }
            }
            if !model.service.isAvailable {
                Text("Apple Health isn't available on this device. You can keep logging manually.")
            }
        }
        .appThemeCanvas()
        .navigationTitle("Apple Health").navigationBarTitleDisplayMode(.inline)
        .task { model.load() }
        .alert("Apple Health", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }
}
