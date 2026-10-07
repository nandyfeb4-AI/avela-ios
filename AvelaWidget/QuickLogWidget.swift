import SwiftUI
import WidgetKit
import AppIntents

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry { QuickLogEntry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(entry(at: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        let current = entry(at: now)
        var entries = [current]
        if let until = current.snapshot?.quickLogPinUntil, until > now, until < midnight {
            entries.append(QuickLogEntry(date: until, snapshot: current.snapshot))
        }
        entries.append(QuickLogEntry(date: midnight, snapshot: nil))
        completion(Timeline(entries: entries, policy: .after(min(now.addingTimeInterval(900), midnight))))
    }
    private func entry(at date: Date) -> QuickLogEntry {
        let snapshot = try? WidgetSnapshotStore().load()
        return QuickLogEntry(date: date, snapshot: snapshot.flatMap { $0.isCurrent(asOf: date, calendar: .current) ? $0 : nil })
    }
}

struct QuickLogWidgetView: View {
    let entry: QuickLogEntry
    var routineTitle: String? = nil
    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.colorScheme) private var colorScheme

    private var capacity: Int {
        if textSize >= .accessibility2 { return 1 }
        if textSize.isAccessibilitySize { return family == .systemSmall ? 1 : 2 }
        return routineTitle != nil ? (family == .systemSmall ? 1 : 2) : (family == .systemSmall ? 2 : 4)
    }
    private var palette: WidgetRichPalette {
        WidgetRichPalette(accent: entry.snapshot?.accentLight ?? 0x0E7468, dark: colorScheme == .dark)
    }
    private var accent: Color { richColor(palette.action) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routineTitle ?? "Quick Log").font(.headline).lineLimit(2).accessibilityAddTraits(.isHeader)
            if let snapshot = entry.snapshot {
                let projection = QuickLogProjection(snapshot: snapshot, date: entry.date)
                Text(snapshot.quickLogMessage ?? (routineTitle != nil ? (snapshot.habits.isEmpty ? "No steps due today" : "Routine · " + projection.summary) : projection.summary))
                    .font(.caption).foregroundStyle(richColor(palette.secondary)).lineLimit(2)
                if snapshot.habits.isEmpty {
                    Spacer(minLength: 0)
                    Link(routineTitle != nil ? "Open Avela" : "Add a habit in Avela", destination: WidgetDeepLink.today.url).font(.subheadline)
                        .frame(minHeight: 44)
                    Spacer(minLength: 0)
                } else {
                    // Medium uses two columns of two 44pt rows. AX sizes use
                    // one column and fewer rows; text is never forcibly shrunk.
                    let rows = projection.rows(capacity: capacity)
                    if family == .systemMedium && !textSize.isAccessibilitySize && routineTitle == nil {
                        VStack(spacing: 0) {
                            ForEach(Array(stride(from: 0, to: rows.count, by: 2)), id: \.self) { index in
                                HStack(alignment: .top, spacing: 16) {
                                    column([rows[index]], snapshot: snapshot, projection: projection)
                                    column(index + 1 < rows.count ? [rows[index + 1]] : [], snapshot: snapshot, projection: projection)
                                }
                            }
                        }
                    } else {
                        column(rows, snapshot: snapshot, projection: projection)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 0)
                Text("Refresh today's habits").font(.subheadline).foregroundStyle(richColor(palette.secondary))
                Button(intent: RefreshQuickLogIntent()) {
                    Label("Refresh habits", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(richColor(palette.actionInk))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh today's habits without opening Avela")
                Link("Open Avela", destination: WidgetDeepLink.today.url)
                    .font(.caption).frame(minHeight: 44)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(richColor(palette.ink))
        .tint(accent)
        .containerBackground(for: .widget) { RichTideBackground(palette: palette) }
    }

    private func column(_ rows: [WidgetHabitSnapshot], snapshot: WidgetSnapshot, projection: QuickLogProjection) -> some View {
        VStack(spacing: 4) {
            ForEach(rows) { habit in
                HStack(spacing: 4) {
                    Link(destination: WidgetDeepLink.habit(habitID: habit.id).url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name).font(.subheadline.weight(.semibold)).foregroundStyle(richColor(palette.ink)).lineLimit(textSize.isAccessibilitySize ? 2 : 1)
                            Text(habit.isCompletedToday ? "Logged today" : habit.isSkippedToday == true ? "Skipped today" : habit.weeklyTargetMet == true ? "Weekly goal met" : habit.requiresQuantityLogging == true ? "Add in Avela" : habit.progressLabel)
                                .font(.caption2).foregroundStyle(richColor(palette.secondary)).lineLimit(1)
                                // Only status waits for saved data. Keep the action
                                // label and background stable during system reloads.
                                .invalidatableContent()
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityLabel("\(habit.name), \(habit.isCompletedToday ? "logged today" : habit.progressLabel). Open details")
                    if habit.isCompletedToday {
                        Image(systemName: "checkmark.circle.fill").font(.title3)
                            .foregroundStyle(accent).frame(width: 44, height: 44)
                            .accessibilityLabel("Logged today")
                    } else if projection.canLog(habit), let revision = habit.configurationRevision, let timeZone = snapshot.timeZoneIdentifier {
                        Button(intent: QuickLogHabitIntent(habitID: habit.id, dayKey: snapshot.localDateKey, timeZone: timeZone, revision: revision)) {
                            Text("Log").font(.subheadline.weight(.semibold))
                                .foregroundStyle(richColor(palette.actionInk))
                                .frame(width: 54, height: 44)
                                .background(accent, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(habit.checkInLabel ?? "Log check-in") for \(habit.name)")
                    } else {
                        Link(destination: (habit.requiresQuantityLogging == true
                            ? WidgetDeepLink.logProgress(habitID: habit.id) : .habit(habitID: habit.id)).url) {
                            Image(systemName: habit.requiresQuantityLogging == true ? "plus.circle" : "arrow.up.right.circle")
                                .font(.title3).foregroundStyle(accent).frame(width: 54, height: 44)
                                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel(habit.requiresQuantityLogging == true ? "Log progress for \(habit.name) in Avela" : "Review \(habit.name) in Avela")
                    }
                }
                .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.example.Avela.widget.quick-log", provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Log a simple check-in without opening Avela. Tap Log to save here. Habit names and quantity + open Avela.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RoutineLogEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let routineID: UUID?
}

struct RoutineLogProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RoutineLogEntry {
        RoutineLogEntry(date: Date(), snapshot: nil, routineID: nil)
    }
    func snapshot(for configuration: RoutineWidgetConfiguration, in context: Context) async -> RoutineLogEntry {
        entry(configuration, at: Date())
    }
    func timeline(for configuration: RoutineWidgetConfiguration, in context: Context) async -> Timeline<RoutineLogEntry> {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
        return Timeline(entries: [entry(configuration, at: now),
            RoutineLogEntry(date: midnight, snapshot: nil, routineID: configuration.routine?.id)],
            policy: .after(min(now.addingTimeInterval(900), midnight)))
    }
    private func entry(_ configuration: RoutineWidgetConfiguration, at date: Date) -> RoutineLogEntry {
        let snapshot = try? WidgetSnapshotStore().load()
        return RoutineLogEntry(date: date,
            snapshot: snapshot.flatMap { $0.isCurrent(asOf: date, calendar: .current) ? $0 : nil },
            routineID: configuration.routine?.id)
    }
}

struct RoutineLogWidgetView: View {
    let entry: RoutineLogEntry
    @Environment(\.colorScheme) private var colorScheme
    private var palette: WidgetRichPalette {
        WidgetRichPalette(accent: entry.snapshot?.accentLight ?? 0x0E7468, dark: colorScheme == .dark)
    }
    var body: some View {
        if let snapshot = entry.snapshot, let id = entry.routineID {
            let projection = RoutineLogProjection(snapshot: snapshot, routineID: id)
            if let routine = projection.routine, let selected = projection.selectedSnapshot {
                QuickLogWidgetView(entry: QuickLogEntry(date: entry.date, snapshot: selected), routineTitle: routine.name)
            } else {
                setup(title: "Choose a routine", message: "This routine is no longer available. Touch and hold to edit this widget.")
            }
        } else if entry.routineID != nil {
            QuickLogWidgetView(entry: QuickLogEntry(date: entry.date, snapshot: nil), routineTitle: "Routine")
        } else {
            setup(title: "Your routine", message: "Touch and hold → Edit Widget → choose a saved routine.")
        }
    }
    private func setup(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "list.bullet").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(richColor(palette.secondary))
            Spacer(minLength: 0)
            Link("Open Avela", destination: WidgetDeepLink.today.url).font(.subheadline)
                .frame(minHeight: 44)
        }
        .foregroundStyle(richColor(palette.ink))
        .tint(richColor(palette.action))
        .containerBackground(for: .widget) { RichTideBackground(palette: palette) }
    }
}

struct RoutineLogWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.example.Avela.widget.routine", intent: RoutineWidgetConfiguration.self,
                               provider: RoutineLogProvider()) { entry in
            RoutineLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Routine")
        .description("Choose a saved routine. Log its due steps individually without opening Avela.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private func richColor(_ rgb: UInt32) -> Color {
    Color(red: Double((rgb >> 16) & 255) / 255,
          green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
}

private struct RichTideBackground: View {
    let palette: WidgetRichPalette
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if contrast == .increased || reduceTransparency {
            richColor(palette.start)
        } else {
            LinearGradient(colors: [richColor(palette.start), richColor(palette.end)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .bottomTrailing) {
                    Ellipse().fill(richColor(palette.action).opacity(0.05))
                        .frame(width: 250, height: 90).offset(x: 65, y: 50)
                }.clipped()
        }
    }
}
