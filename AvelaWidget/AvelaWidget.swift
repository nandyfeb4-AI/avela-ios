import SwiftUI
import WidgetKit

private struct AvelaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// The app exports the selected animal and evaluated state. Artwork carries
/// no additional claim about unobserved attention usage and is redacted with
/// personal widget content; Lock Screen summaries remain compact text.
private struct WidgetCompanionHeader: View {
    let snapshot: WidgetSnapshot
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Label(title, systemImage: symbol).font(.headline)
            Spacer(minLength: 0)
            if let animal = snapshot.companionAnimal, let state = snapshot.companionState {
                CompanionArtwork(animal: animal, state: state, size: 32)
                    .accessibilityHidden(true)
                    .privacySensitive()
            }
        }
    }
}

private struct AvelaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AvelaWidgetEntry {
        AvelaWidgetEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AvelaWidgetEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AvelaWidgetEntry>) -> Void) {
        let date = Date()
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(3600)
        // A scheduled midnight entry clears yesterday's claims even if the app
        // is closed. WidgetKit chooses exact refresh timing; app writes also
        // request reloads after every foreground refresh and mutation.
        let entries = [entry(at: date), AvelaWidgetEntry(date: nextDay, snapshot: nil)]
        completion(Timeline(entries: entries, policy: .after(min(date.addingTimeInterval(900), nextDay))))
    }

    private func entry(at date: Date) -> AvelaWidgetEntry {
        let snapshot = try? WidgetSnapshotStore().load()
        return AvelaWidgetEntry(
            date: date,
            snapshot: snapshot.flatMap { $0.isCurrent(asOf: date, calendar: .current) ? $0 : nil }
        )
    }
}

private struct HabitProgressWidgetView: View {
    let entry: AvelaWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading) {
                    Label("Avela habits", systemImage: "checkmark.circle")
                    if let snapshot = entry.snapshot {
                        Text("\(snapshot.habits.filter(\.isCompletedToday).count) of \(snapshot.habits.count) done today")
                    } else {
                        Text("Open Avela to refresh")
                    }
                }
            } else if let snapshot = entry.snapshot {
                if family == .systemMedium {
                    HStack(alignment: .center, spacing: 16) {
                        summary(snapshot)
                        if !snapshot.habits.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(Array(snapshot.habits.filter { !$0.isCompletedToday }.prefix(2))) { habit in
                                    Link(destination: WidgetDeepLink.complete(habitID: habit.id, localDateKey: snapshot.localDateKey).url) {
                                        HStack(spacing: 6) {
                                            Image(systemName: habit.iconName)
                                            Text(habit.name).lineLimit(1)
                                            Spacer(minLength: 0)
                                            Image(systemName: "checkmark.circle")
                                        }
                                        .font(.caption)
                                        .frame(minHeight: 44)
                                    }
                                    .accessibilityLabel("Complete \(habit.name) in Avela")
                                    .privacySensitive()
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    summary(snapshot)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Habits", systemImage: "checkmark.circle").font(.headline)
                    Text("Open Avela to refresh today's habits").font(.subheadline)
                }
            }
        }
        .widgetURL(WidgetDeepLink.today.url)
        .containerBackground(.background, for: .widget)
    }

    private func summary(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetCompanionHeader(snapshot: snapshot, title: "Habits", symbol: "checkmark.circle")
            Text("\(snapshot.habits.filter(\.isCompletedToday).count) of \(snapshot.habits.count)")
                .font(.title.bold())
            Text(snapshot.habits.isEmpty ? "Add your first habit" : "Done today")
                .font(.caption).foregroundStyle(.secondary)
            Text("Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

}

private struct AttentionBudgetWidgetView: View {
    let entry: AvelaWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if family == .systemMedium && !snapshot.attentionGoals.isEmpty {
                    HStack(alignment: .center, spacing: 16) {
                        summary(snapshot)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(snapshot.attentionGoals.prefix(2))) { goal in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(goal.name).font(.caption.weight(.semibold)).lineLimit(1)
                                    Text(goal.statusLabel).font(.caption2).lineLimit(3)
                                        .foregroundStyle(.secondary)
                                }
                                .privacySensitive()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    summary(snapshot)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Attention", systemImage: "hourglass").font(.headline)
                    Text("Open Avela to refresh").font(.caption)
                }
            }
        }
        .widgetURL(WidgetDeepLink.today.url)
        .containerBackground(.background, for: .widget)
    }

    private func summary(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .accessoryRectangular ? 2 : 6) {
            if family == .accessoryRectangular {
                Label("Avela attention", systemImage: "hourglass").font(.headline)
            } else {
                WidgetCompanionHeader(snapshot: snapshot, title: "Attention", symbol: "hourglass")
            }
            if snapshot.attentionGoals.isEmpty {
                Text("Add a daily budget").font(.caption)
            } else if family == .systemSmall, let first = snapshot.attentionGoals.first {
                Text(first.statusLabel).font(.caption).lineLimit(3).privacySensitive()
                if snapshot.attentionGoals.count > 1 {
                    Text("\(snapshot.attentionGoals.count) goals · Open Avela")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                let logged = snapshot.attentionGoals.filter(\.hasLoggedUsage).count
                Text(logged == 0 ? "Not logged yet" : "\(logged) of \(snapshot.attentionGoals.count) goals logged")
                    .font(.caption)
                Text("Logged manually").font(.caption2).foregroundStyle(.secondary)
            }
            if family != .accessoryRectangular {
                Text("Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

}

struct HabitProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.example.Avela.widget.habits", provider: AvelaWidgetProvider()) { entry in
            HabitProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Habit Progress")
        .description("Today's progress. Tap a habit in the medium widget to complete it in Avela.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct AttentionBudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.example.Avela.widget.attention", provider: AvelaWidgetProvider()) { entry in
            AttentionBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Attention Budget")
        .description("Your manually logged daily attention budgets. Open Avela to log or correct usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct AvelaWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitProgressWidget()
        AttentionBudgetWidget()
        PhoneFreeLiveActivityWidget()
    }
}
