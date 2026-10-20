import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Cópia de segurança das marcações, notas, leituras e planos (sem texto bíblico).
/// Com Apple ID gratuito não há iCloud; este arquivo é a forma de não perder nada.
struct Backup: Codable, Equatable {
    struct Mark: Codable, Equatable {
        var book: Int, chapter: Int, verse: Int
        var color: String?
        var underline: Bool
        var saved: Bool
        var note: String?
        var updatedAt: Date
    }

    struct Reading: Codable, Equatable {
        var dayKey: String, book: Int, chapter: Int, readAt: Date
    }

    struct Plan: Codable, Equatable {
        var planID: String, startedAt: Date
    }

    var formatVersion = 1
    var exportedAt: Date
    var marks: [Mark]
    var readings: [Reading]
    var plans: [Plan]
}

enum BackupError: LocalizedError {
    case tooLarge, invalid, unsupportedVersion, unreadable

    var errorDescription: String? {
        switch self {
        case .tooLarge: "O arquivo de cópia é grande demais."
        case .invalid: "Este arquivo não é uma cópia de segurança do app Bíblia."
        case .unsupportedVersion: "Esta cópia foi feita por uma versão mais nova do app."
        case .unreadable: "Não foi possível ler o arquivo. Se ele está no iCloud Drive, baixe-o antes de restaurar."
        }
    }
}

@MainActor
enum BackupService {
    static let maxSize = 20 * 1_048_576

    static func makeBackup(context: ModelContext) -> Backup {
        let marks = (try? context.fetch(FetchDescriptor<VerseMark>())) ?? []
        let readings = (try? context.fetch(FetchDescriptor<ReadingEntry>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<PlanEnrollment>())) ?? []
        return Backup(
            exportedAt: .now,
            marks: marks.map { Backup.Mark(book: $0.book, chapter: $0.chapter, verse: $0.verse, color: $0.colorRaw, underline: $0.underline, saved: $0.saved, note: $0.note, updatedAt: $0.updatedAt) },
            readings: readings.map { Backup.Reading(dayKey: $0.dayKey, book: $0.book, chapter: $0.chapter, readAt: $0.readAt) },
            plans: plans.map { Backup.Plan(planID: $0.planID, startedAt: $0.startedAt) }
        )
    }

    static func encode(_ backup: Backup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Lê o arquivo escolhido conferindo o tamanho antes de carregar.
    static func read(from url: URL) throws -> Backup {
        do {
            return try decode(BoundedFile.read(url, maxBytes: maxSize))
        } catch BoundedFile.ReadError.tooLarge {
            throw BackupError.tooLarge
        } catch BoundedFile.ReadError.unknownSize {
            throw BackupError.unreadable
        }
    }

    static func decode(_ data: Data) throws -> Backup {
        guard data.count <= maxSize else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(Backup.self, from: data) else { throw BackupError.invalid }
        guard backup.formatVersion <= 1 else { throw BackupError.unsupportedVersion }
        return backup
    }

    /// Junta a cópia com o que já existe: não duplica leituras e mantém a marcação mais recente.
    @discardableResult
    static func restore(_ backup: Backup, into context: ModelContext) -> (marks: Int, readings: Int, plans: Int) {
        let store = BibleStore(context: context)
        var counts = (marks: 0, readings: 0, plans: 0)

        for item in backup.marks {
            let ref = VerseRef(book: item.book, chapter: item.chapter, verse: item.verse)
            guard Canon.isValid(ref.chapterRef), item.verse >= 1 else { continue }
            let existing = store.mark(for: ref)
            if let existing, existing.updatedAt > item.updatedAt { continue }
            let mark = existing ?? VerseMark(ref: ref)
            if existing == nil { context.insert(mark) }
            mark.colorRaw = item.color.flatMap(HighlightColor.init(rawValue:))?.rawValue
            mark.underline = item.underline
            mark.saved = item.saved
            mark.note = item.note.map { String($0.prefix(BibleStore.maxNoteLength)) }
            mark.updatedAt = item.updatedAt
            if mark.isEmpty { context.delete(mark) } else { counts.marks += 1 }
        }

        var existingReadings = Set(store.allEntries().map { "\($0.dayKey)|\($0.book)|\($0.chapter)" })
        for item in backup.readings {
            let ref = ChapterRef(book: item.book, chapter: item.chapter)
            let key = "\(item.dayKey)|\(item.book)|\(item.chapter)"
            guard Canon.isValid(ref), DayKey.date(from: item.dayKey) != nil,
                  existingReadings.insert(key).inserted else { continue }
            let entry = ReadingEntry(chapter: ref, at: item.readAt)
            entry.dayKey = item.dayKey
            context.insert(entry)
            counts.readings += 1
        }

        let plans = (try? context.fetch(FetchDescriptor<PlanEnrollment>())) ?? []
        for item in backup.plans where PlanGenerator.plan(item.planID) != nil {
            if let existing = plans.first(where: { $0.planID == item.planID }) {
                existing.startedAt = min(existing.startedAt, item.startedAt)
            } else {
                context.insert(PlanEnrollment(planID: item.planID, startedAt: item.startedAt))
                counts.plans += 1
            }
        }
        try? context.save()
        return counts
    }
}

/// Documento usado pelo exportador de arquivos do sistema.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
