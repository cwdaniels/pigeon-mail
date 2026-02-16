import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct SendOnlyWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        #if os(iOS)
        @Environment(\.widgetFamily) var family
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            Label("Compose", systemImage: "bird.fill")
        default:
            circularView
        }
        #else
        circularView
        #endif
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "bird.fill")
                .font(.title2)
                .widgetAccentable()
        }
    }
}

@main
struct SendOnlyWidget: Widget {
    let kind: String = "SendOnlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SendOnlyWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "sendonly://compose"))
        }
        .configurationDisplayName("Pigeon Mail")
        .description("Quickly compose a new email.")
        #if os(iOS)
        .supportedFamilies([.accessoryCircular, .accessoryInline])
        #endif
    }
}
