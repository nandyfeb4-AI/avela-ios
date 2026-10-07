import SwiftUI

struct HabitAdjustmentView: View {
    @State var viewModel: HabitAdjustmentViewModel
    @State private var showingConfirmation = false
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let proposal = viewModel.proposal {
                    Section {
                        Text(viewModel.habitName).font(.headline)
                        Text("A lighter schedule can give you room to rebuild momentum. You choose what works for you.")
                        Text("\(proposal.recentMisses) unfinished commitments in the past \(proposal.windowDays) days.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section {
                        Text("Current: \(HabitScheduleFormatter.description(for: proposal.currentSchedule))")
                            .accessibilityIdentifier("habitAdjustment.current")
                        Stepper(viewModel.frequencyLabel, value: $viewModel.frequency,
                                in: 1...proposal.maximumFrequency)
                            .accessibilityIdentifier("habitAdjustment.frequency")
                    } header: {
                        Text("Your Schedule")
                    } footer: {
                        Text("Starts today. Earlier completed periods and all check-ins stay intact. This week's progress may change. Apple Health targets stay as configured.")
                    }
                    Section {
                        Button("Review Change") { showingConfirmation = true }
                            .disabled(viewModel.needsReload)
                            .accessibilityIdentifier("habitAdjustment.review")
                        Button("Keep Current Schedule") { dismiss() }
                            .accessibilityIdentifier("habitAdjustment.keep")
                    }
                } else if viewModel.errorMessage == nil {
                    Section {
                        Text("No lighter schedule to suggest right now. You can still edit your habit from its detail screen.")
                    }
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                        Button("Reload") { viewModel.load() }
                            .accessibilityIdentifier("habitAdjustment.reload")
                    }
                }
            }
            .appThemeCanvas()
        .navigationTitle("Make It Easier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("habitAdjustment.cancel")
                }
            }
            .alert("Change \(viewModel.habitName)'s schedule?", isPresented: $showingConfirmation) {
                Button("Use This Schedule") {
                    if viewModel.save() { onSaved(); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Change from \(viewModel.proposal.map { HabitScheduleFormatter.description(for: $0.currentSchedule) } ?? "your current schedule") to \(viewModel.frequencyLabel), starting today?")
            }
            .task { viewModel.load() }
        }
    }
}
