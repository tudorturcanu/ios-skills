import WidgetKit
import SwiftUI

struct TideEntry: TimelineEntry {
    let date: Date
    let snapshot: TideSnapshot?
}

struct TideProvider: TimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        TideEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TideEntry) -> Void) {
        completion(TideEntry(date: .now, snapshot: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TideEntry>) -> Void) {
        let snapshot = SharedStore.load()
        let entry = TideEntry(date: .now, snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TideWidgetView: View {
    let entry: TideEntry
    var body: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading) {
                Text(s.harbor).font(.headline)
                Text(s.nextHighTide, style: .time)
                Text("\(s.heightMeters, specifier: "%.1f") m")
            }
        } else {
            Text("Open TideWatch")
        }
    }
}

@main
struct TideWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TideWidget", provider: TideProvider()) { entry in
            TideWidgetView(entry: entry)
        }
        .supportedFamilies([.systemSmall])
    }
}
