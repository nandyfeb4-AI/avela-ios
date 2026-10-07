import SwiftUI

struct HabitMomentumView: View {
    @State var viewModel: HabitMomentumViewModel
    @Environment(\.appPalette) private var palette
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(viewModel.habitName).font(.title2.weight(.semibold))
                Text("Progress that stays with you").font(.subheadline).foregroundStyle(Color.appInkSecondary)
                if let summary = viewModel.summary {
                    card("Recent Rhythm", symbol: "chart.bar.xaxis") {
                        if let percent = summary.recentPercentage {
                            Text("\(percent)%").font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                                .foregroundStyle(palette.accent).accessibilityIdentifier("momentum.recentPercentage")
                            ProgressView(value: Double(summary.recentSuccessful), total: Double(summary.recentResolved))
                                .tint(palette.accent).accessibilityHidden(true)
                            Text("\(summary.recentSuccessful) of \(summary.recentResolved) resolved commitments kept")
                                .accessibilityIdentifier("momentum.recentCounts")
                        } else {
                            Text("Your rhythm is taking shape").font(.headline).accessibilityIdentifier("momentum.insufficient")
                        }
                        Text("Last 14 days. Open periods, skips and pauses aren't misses. A flexible weekly target counts as one commitment.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    }
                    card("Coming Back", symbol: "arrow.up.forward.circle") {
                        if summary.isRecovering {
                            Text("\(summary.recoverySuccessful) of 3 good \(summary.recoveryUnit)")
                                .font(.title3.weight(.semibold)).accessibilityIdentifier("momentum.recovery")
                            Text("A fresh start keeps your earlier progress.").font(.subheadline)
                        } else {
                            Text("No recovery run needed right now").font(.headline)
                        }
                        Text("Recovery ends after three consecutive successful commitments. Smaller actions remain separate effort.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    }
                    card("Lasting Effort", symbol: "leaf") {
                        Text("\(summary.lifetime.checkInDays.formatted()) successful check-in days")
                            .font(.title3.weight(.semibold)).accessibilityIdentifier("momentum.lifetime")
                        Text("\(summary.lifetime.smallerActionDays.formatted()) smaller-action days")
                            .accessibilityIdentifier("momentum.smallerActions")
                        ForEach(summary.lifetime.quantities) { total in
                            Text("\(total.amount.formatted()) \(total.unit.name(for: total.amount)) logged")
                        }
                        Text("Misses and pauses don't reset these totals. Undo and corrections update the surviving records.")
                            .font(.footnote).foregroundStyle(Color.appInkSecondary)
                    }
                    Text("Momentum brings these facts together; it isn't a combined score or a measure of your worth.")
                        .font(.footnote).foregroundStyle(Color.appInkSecondary)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Momentum Unavailable", systemImage: "chart.bar", description: Text(error))
                    Button("Try Again") { viewModel.load() }.frame(minHeight: 44)
                } else { ProgressView() }
            }.padding(20)
        }
        .appThemeCanvas()
        .navigationTitle("Momentum").navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .onChange(of: phase) { _, value in if value == .active { viewModel.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .avelaHealthDidLog)) { _ in viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .avelaShortcutDidLog)) { _ in viewModel.load() }
    }

    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
