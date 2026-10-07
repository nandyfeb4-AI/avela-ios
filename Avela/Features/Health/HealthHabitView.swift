import SwiftUI

private struct HealthHabitServiceKey: EnvironmentKey {
    static let defaultValue: HealthHabitService? = nil
}
extension EnvironmentValues {
    var healthHabitService: HealthHabitService? {
        get { self[HealthHabitServiceKey.self] }
        set { self[HealthHabitServiceKey.self] = newValue }
    }
}

struct HealthHabitView: View {
    let habitID: UUID
    @Bindable var service: HealthHabitService
    @State private var metric: HealthHabitMetric = .steps
    @State private var target = "5000"
    @State private var connected = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Automatically log this habit when today's Apple Health target is reached. Avela checks when you open it or tap Refresh; background updates aren't promised.")
                Text("Only today's steps or exercise minutes are read. No data is written to Apple Health, and no health samples are stored or uploaded by Avela.")
            }
            Section {
                Picker("Metric", selection: Binding(get: { metric }, set: {
                    metric = $0; target = String($0.defaultTarget)
                })) {
                    ForEach(HealthHabitMetric.allCases, id: \.self) { Text($0.label).tag($0) }
                }.accessibilityIdentifier("health.metricPicker")
                TextField("Target", text: $target).keyboardType(.decimalPad)
                    .accessibilityIdentifier("health.targetField")
                Text("Choose more than 0 and no more than \(metric.maximumTarget.formatted()) \(metric.label.lowercased()).")
                    .font(.caption).foregroundStyle(.secondary)
                Button(connected ? "Update Connection" : "Connect Apple Health") {
                    save()
                }
                .disabled(isSaving || !service.isAvailable)
                .accessibilityIdentifier("health.connectButton")
            } header: { Text("Your Target") } footer: {
                Text("Apple asks for read access only when you connect. No accessible data may mean no samples or limited access; Avela cannot distinguish the two. Manual logging remains available.")
            }
            if connected {
                Section {
                    Button("Refresh Apple Health") { Task { await service.refresh() } }
                        .disabled(service.isRefreshing || isSaving)
                        .accessibilityIdentifier("health.refreshButton")
                    if let error = service.refreshError { Text(error) }
                    else if let message = service.messages[habitID] { Text(message) }
                    Button("Disconnect", role: .destructive) {
                        do { try service.disconnect(habitID: habitID); connected = false }
                        catch { errorMessage = "Your connection couldn't be removed. Try again." }
                    }.disabled(isSaving)
                } header: { Text("Connection") } footer: {
                    Text("Existing completions are kept. A skipped day isn't automatically completed. Undoing an imported completion can be followed by another import while the connection is active; disconnect to stop future imports. Manage Health permissions separately in Apple Health.")
                }
            }
            if !service.isAvailable {
                Text("Apple Health isn't available on this device. You can keep logging manually.")
            }
        }
        .appThemeCanvas()
        .navigationTitle("Apple Health").navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                if let connection = try service.connection(for: habitID) {
                    connected = true; metric = connection.metric; target = String(connection.target)
                }
            } catch { errorMessage = "Your connection couldn't be loaded. Try again." }
        }
        .alert("Apple Health", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        guard let amount = Double(target), amount.isFinite, amount > 0, amount <= metric.maximumTarget else {
            errorMessage = "Enter a positive target within the displayed limit."; return
        }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await service.connect(habitID: habitID, metric: metric, target: amount)
                connected = true
                await service.refresh()
            } catch let error as HealthHabitError { errorMessage = error.errorDescription }
            catch { errorMessage = "Your Health connection couldn't be saved. Manual logging still works." }
        }
    }
}
