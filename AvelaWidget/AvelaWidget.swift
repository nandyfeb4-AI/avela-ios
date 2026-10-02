import SwiftUI
import WidgetKit

private struct ScaffoldEntry: TimelineEntry {
    let date: Date
}

private struct ScaffoldProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScaffoldEntry {
        ScaffoldEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ScaffoldEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScaffoldEntry>) -> Void) {
        completion(Timeline(entries: [ScaffoldEntry(date: Date())], policy: .never))
    }
}

private struct ScaffoldWidgetView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Avela")
                .font(.headline)
            Text("Widget scaffold")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct AvelaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.example.Avela.widget.scaffold", provider: ScaffoldProvider()) { _ in
            ScaffoldWidgetView()
        }
        .configurationDisplayName("Avela Scaffold")
        .description("Development placeholder for future Avela widgets.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct AvelaWidgetBundle: WidgetBundle {
    var body: some Widget {
        AvelaWidget()
    }
}
