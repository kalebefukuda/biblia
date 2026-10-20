import Foundation
import SwiftData
import SwiftUI

enum HighlightColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case amarelo, verde, azul, rosa, laranja

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .amarelo: Color(red: 0.98, green: 0.84, blue: 0.25)
        case .verde: Color(red: 0.45, green: 0.80, blue: 0.47)
        case .azul: Color(red: 0.42, green: 0.66, blue: 0.96)
        case .rosa: Color(red: 0.96, green: 0.52, blue: 0.70)
        case .laranja: Color(red: 0.98, green: 0.62, blue: 0.30)
        }
    }

    var label: String { rawValue.capitalized }
}

/// Tudo o que o usuário marcou num versículo. Fica ligado à referência (livro,
/// capítulo, versículo), não à versão: um destaque feito na ARA aparece na NVI.
@Model
final class VerseMark {
    @Attribute(.unique) var key: String
    var book: Int
    var chapter: Int
    var verse: Int
    var colorRaw: String?
    var underline: Bool
    var saved: Bool
    var note: String?
    var updatedAt: Date

    init(ref: VerseRef) {
        key = ref.key
        book = ref.book
        chapter = ref.chapter
        verse = ref.verse
        underline = false
        saved = false
        updatedAt = .now
    }

    var ref: VerseRef { VerseRef(book: book, chapter: chapter, verse: verse) }

    var color: HighlightColor? {
        get { colorRaw.flatMap(HighlightColor.init(rawValue:)) }
        set { colorRaw = newValue?.rawValue }
    }

    var hasNote: Bool { !(note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isEmpty: Bool { colorRaw == nil && !underline && !saved && !hasNote }
}

/// Um capítulo lido num dia. Alimenta o mapa de leitura, a sequência e os planos.
@Model
final class ReadingEntry {
    var dayKey: String
    var book: Int
    var chapter: Int
    var readAt: Date

    init(chapter ref: ChapterRef, at date: Date, calendar: Calendar = .current) {
        dayKey = DayKey.from(date, calendar: calendar)
        book = ref.book
        chapter = ref.chapter
        readAt = date
    }

    var chapterRef: ChapterRef { ChapterRef(book: book, chapter: chapter) }
}

/// Plano de leitura iniciado pelo usuário.
@Model
final class PlanEnrollment {
    @Attribute(.unique) var planID: String
    var startedAt: Date

    init(planID: String, startedAt: Date = .now) {
        self.planID = planID
        self.startedAt = startedAt
    }
}

enum Persistence {
    static let storeName = "Biblia.store"
    /// O SQLite do SwiftData grava o banco em três arquivos.
    static let storeFiles = [storeName, storeName + "-shm", storeName + "-wal"]
    static let schema = Schema([VerseMark.self, ReadingEntry.self, PlanEnrollment.self])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let url = AppGroup.containerURL.appendingPathComponent(storeName)
            config = ModelConfiguration(schema: schema, url: url)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
