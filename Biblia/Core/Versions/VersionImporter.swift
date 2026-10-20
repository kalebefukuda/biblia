import Foundation

enum VersionImportError: LocalizedError, Equatable {
    case tooLarge(bytes: Int)
    case invalidJSON
    case unknownFormat
    case invalidName
    case unreadable
    case wrongBookCount(found: Int)
    case wrongChapterCount(book: String, expected: Int, found: Int)
    case emptyChapter(book: String, chapter: Int)
    case verseTooLong(book: String, chapter: Int, verse: Int)

    var errorDescription: String? {
        switch self {
        case .tooLarge(let bytes):
            "Arquivo grande demais (\(bytes / 1_048_576) MB). O limite é \(VersionImporter.maxFileSize / 1_048_576) MB."
        case .invalidJSON:
            "O arquivo não é um JSON válido."
        case .unknownFormat:
            "Formato de JSON não reconhecido. Use uma lista de livros com \"chapters\"."
        case .unreadable:
            "Não foi possível ler o arquivo. Se ele está no iCloud Drive, baixe-o antes de importar."
        case .invalidName:
            "Nome de arquivo inválido. Use algo como ARA.json ou NVI.json."
        case .wrongBookCount(let found):
            "A versão precisa ter 66 livros, mas o arquivo tem \(found)."
        case .wrongChapterCount(let book, let expected, let found):
            "\(book) deveria ter \(expected) capítulos, mas o arquivo tem \(found)."
        case .emptyChapter(let book, let chapter):
            "\(book) \(chapter) está vazio no arquivo."
        case .verseTooLong(let book, let chapter, let verse):
            "\(book) \(chapter):\(verse) é longo demais para ser um versículo."
        }
    }
}

/// Lê e valida arquivos de versão. Aceita dois formatos de JSON:
///
/// A) `[{"abbrev": "Gn", "chapters": [["v1", "v2"], ...]}, ...]`
/// B) `{"books": [{"chapters": [{"verses": [{"text": "v1"}, ...]}, ...]}, ...]}`
///
/// O arquivo vem de fora do app, então é tratado como dado não confiável:
/// tamanho limitado, estrutura conferida contra o cânon e nada é executado.
enum VersionImporter {
    static let maxFileSize = 25 * 1_048_576
    static let maxVerseLength = 5_000

    static func parse(data: Data, id: String) throws -> BibleText {
        guard !id.isEmpty else { throw VersionImportError.invalidName }
        guard data.count <= maxFileSize else { throw VersionImportError.tooLarge(bytes: data.count) }

        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: stripBOM(data))
        } catch {
            throw VersionImportError.invalidJSON
        }

        let books: [[[String]]]
        if let array = json as? [[String: Any]] {
            books = try array.map(parseFormatA)
        } else if let object = json as? [String: Any], let array = object["books"] as? [[String: Any]] {
            books = try array.map(parseFormatB)
        } else {
            throw VersionImportError.unknownFormat
        }

        try validate(books)
        return BibleText(id: id, name: VersionInfo.displayName(for: id), books: books)
    }

    private static func stripBOM(_ data: Data) -> Data {
        data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    }

    private static func parseFormatA(_ book: [String: Any]) throws -> [[String]] {
        guard let chapters = book["chapters"] as? [[Any]] else { throw VersionImportError.unknownFormat }
        return try chapters.map { verses in
            try verses.map { verse in
                guard let text = verse as? String else { throw VersionImportError.unknownFormat }
                return clean(text)
            }
        }
    }

    private static func parseFormatB(_ book: [String: Any]) throws -> [[String]] {
        guard let chapters = book["chapters"] as? [[String: Any]] else { throw VersionImportError.unknownFormat }
        return try chapters.map { chapter in
            guard let verses = chapter["verses"] as? [[String: Any]] else { throw VersionImportError.unknownFormat }
            return try verses.map { verse in
                guard let text = verse["text"] as? String else { throw VersionImportError.unknownFormat }
                return clean(text)
            }
        }
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validate(_ books: [[[String]]]) throws {
        guard books.count == Canon.books.count else {
            throw VersionImportError.wrongBookCount(found: books.count)
        }
        for (book, chapters) in zip(Canon.books, books) {
            guard chapters.count == book.chapterCount else {
                throw VersionImportError.wrongChapterCount(book: book.name, expected: book.chapterCount, found: chapters.count)
            }
            for (chapterIndex, verses) in chapters.enumerated() {
                guard !verses.isEmpty else {
                    throw VersionImportError.emptyChapter(book: book.name, chapter: chapterIndex + 1)
                }
                if let long = verses.firstIndex(where: { $0.count > maxVerseLength }) {
                    throw VersionImportError.verseTooLong(book: book.name, chapter: chapterIndex + 1, verse: long + 1)
                }
            }
        }
    }
}
