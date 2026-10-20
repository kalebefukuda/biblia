import Foundation

/// Resumo que o app grava no App Group para o widget ler (o widget não abre o banco
/// nem os arquivos das versões; só este JSON pequeno).
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Verse: Codable, Equatable, Sendable {
        var key: String
        var title: String
        var text: String
        var versionID: String
    }

    var counts: [String: Int]
    var verses: [String: Verse]
    var updatedAt: Date

    static let empty = WidgetSnapshot(counts: [:], verses: [:], updatedAt: .distantPast)

    static let fileName = "widget.json"
    static var url: URL { AppGroup.containerURL.appendingPathComponent(fileName) }

    static func load(from url: URL = url) -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    func save(to url: URL = url) throws {
        try JSONEncoder().encode(self).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func verse(for date: Date, calendar: Calendar = .current) -> Verse? {
        verses[DayKey.from(date, calendar: calendar)]
    }
}

/// Referências para o "versículo do dia". Só referências; o texto vem da versão
/// que você importou.
enum VerseOfDay {
    static let references: [String] = [
        "43.3.16", "19.23.1", "20.3.5", "45.8.28", "50.4.13", "23.41.10", "40.11.28", "24.29.11",
        "6.1.9", "45.12.2", "58.11.1", "46.13.4", "62.4.19", "19.46.1", "19.119.105", "40.6.33",
        "48.2.20", "49.2.8", "60.5.7", "23.40.31", "25.3.22", "19.37.4", "45.5.8", "47.5.17",
        "43.14.6", "40.5.14", "19.27.1", "51.3.23", "58.12.1", "20.16.3", "33.6.8", "35.3.17",
        "19.91.1", "43.15.5", "45.15.13", "62.1.9", "59.1.5", "19.139.23", "50.4.6", "40.22.37",
        "19.16.11", "45.10.9", "43.11.25", "47.12.9", "19.121.1", "23.26.3", "55.1.7", "19.34.8",
        "52.5.16", "44.1.8", "40.28.19", "4.6.24", "19.103.2", "36.3.17", "43.8.32", "45.6.23",
        "61.3.9", "19.1.1", "64.1.4", "66.21.4",
    ]

    static func reference(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return references[day % references.count]
    }
}
