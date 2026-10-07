import SwiftUI

struct HabitLifetimeView: View {
    @State var viewModel: HabitLifetimeViewModel
    @Environment(\.appPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.habitName).font(.title2.weight(.semibold)).foregroundStyle(Color.appInk)
                if let summary = viewModel.summary {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Lifetime Check-ins", systemImage: "checkmark.circle")
                            .font(.headline)
                        Text(summary.checkInDays.formatted())
                            .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                            .accessibilityLabel("\(summary.checkInDays) successful check-in days")
                            .accessibilityIdentifier("lifetime.checkInDays")
                        Text("Successful days logged · not a streak or completed weeks.")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white).padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.heroGradient, in: RoundedRectangle(cornerRadius: 24))
                    Text("Misses don’t reset your progress. Undo and corrections update these totals.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    milestones(summary)
                    if viewModel.hasQuantityHistory {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Accumulated Progress").font(.headline).accessibilityAddTraits(.isHeader)
                            if summary.quantities.isEmpty {
                                Text("No quantities logged yet.").foregroundStyle(Color.appInkSecondary)
                            }
                            ForEach(summary.quantities) { total in
                                Label {
                                    Text("\(total.amount.formatted()) \(total.unit.name(for: total.amount)) logged")
                                        .font(.body.weight(.medium)).monospacedDigit()
                                } icon: {
                                    Image(systemName: "plus.circle").foregroundStyle(palette.accent).accessibilityHidden(true)
                                }
                                    .padding(.vertical, 4)
                                    .accessibilityIdentifier("lifetime.quantity.\(total.unit.rawValue)")
                            }
                            Text("Recorded amounts, not verified activity. Different units stay separate.")
                                .font(.footnote).foregroundStyle(Color.appInkSecondary)
                            if summary.smallerActionDays > 0 {
                                Text("Smaller actions on \(summary.smallerActionDays) \(summary.smallerActionDays == 1 ? "day" : "days")")
                                Text("Smaller actions are separate from full successes.")
                                    .font(.footnote).foregroundStyle(Color.appInkSecondary)
                            }
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Progress Unavailable", systemImage: "chart.bar", description: Text(error))
                    Button("Try Again") { viewModel.load() }.frame(minHeight: 44)
                } else { ProgressView() }
            }.padding(20)
        }
        .appThemeCanvas()
        .navigationTitle("Lifetime Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .avelaHealthDidLog)) { _ in viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .avelaShortcutDidLog)) { _ in viewModel.load() }
    }

    private func milestones(_ summary: HabitLifetimeCalculator.Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones").font(.headline).accessibilityAddTraits(.isHeader)
            if summary.achievedMilestones.isEmpty {
                Text("Your first milestone: 10 check-in days.")
                    .foregroundStyle(Color.appInkSecondary)
            } else {
                ForEach(summary.achievedMilestones, id: \.self) { threshold in
                    Label("\(threshold.formatted()) check-in days reached", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.accent)
                        .padding(.vertical, 4)
                }
            }
            if let next = summary.nextMilestone, summary.checkInDays > 0 {
                ProgressView(value: Double(summary.checkInDays), total: Double(next)).tint(palette.accent)
                    .accessibilityLabel("Next milestone")
                    .accessibilityValue("\(summary.checkInDays) of \(next) check-in days")
                Text("Next: \(next.formatted()) check-in days").font(.subheadline)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
