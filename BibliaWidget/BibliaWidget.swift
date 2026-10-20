import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Uma entrada agora e outra à meia-noite, para "leu hoje" e a sequência virarem o dia.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let entries = [SnapshotEntry(date: now, snapshot: snapshot), SnapshotEntry(date: midnight, snapshot: snapshot)]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct StreakWidget: Widget {
    @Environment(\.widgetFamily) private var family

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BibliaSequencia", provider: SnapshotProvider()) { entry in
            StreakEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
                .widgetURL(URL(string: "biblia://progresso"))
        }
        .configurationDisplayName("Sequência de leitura")
        .description("Dias seguidos e o mapa das últimas semanas.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StreakEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        StreakWidgetView(snapshot: entry.snapshot, date: entry.date, family: family)
    }
}

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BibliaVersiculo", provider: SnapshotProvider()) { entry in
            VerseEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("Versículo do dia")
        .description("Um versículo novo a cada dia, na versão que você lê.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct VerseEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        let verse = entry.snapshot.verse(for: entry.date)
        VerseWidgetView(verse: verse, family: family)
            .widgetURL(verse.flatMap { URL(string: "biblia://versiculo/\($0.key)") })
    }
}

@main
struct BibliaWidgets: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        VerseWidget()
    }
}
