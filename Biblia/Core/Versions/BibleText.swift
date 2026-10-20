import Foundation

/// Texto completo de uma versão, em memória: [livro][capítulo][versículo].
struct BibleText: Sendable {
    let id: String
    let name: String
    let books: [[[String]]]

    func verses(_ ref: ChapterRef) -> [String] {
        guard books.indices.contains(ref.book - 1) else { return [] }
        let chapters = books[ref.book - 1]
        guard chapters.indices.contains(ref.chapter - 1) else { return [] }
        return chapters[ref.chapter - 1]
    }

    func verse(_ ref: VerseRef) -> String? {
        let verses = verses(ref.chapterRef)
        return verses.indices.contains(ref.verse - 1) ? verses[ref.verse - 1] : nil
    }

    var verseCount: Int { books.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } } }
}

struct VersionInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fileURL: URL

    static let knownNames: [String: String] = [
        "ARA": "Almeida Revista e Atualizada",
        "ARC": "Almeida Revista e Corrigida",
        "ACF": "Almeida Corrigida Fiel",
        "NAA": "Nova Almeida Atualizada",
        "NVI": "Nova Versão Internacional",
        "NVT": "Nova Versão Transformadora",
        "NTLH": "Nova Tradução na Linguagem de Hoje",
        "KJA": "King James Atualizada",
        "AA": "Almeida Atualizada",
        "BLIVRE": "Bíblia Livre",
    ]

    static func displayName(for id: String) -> String {
        knownNames[id] ?? id
    }

    /// "ara.json" → "ARA". Só letras e números, até 12 caracteres.
    static func id(fromFileName fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        let cleaned = base.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return String(cleaned.prefix(12))
    }
}
