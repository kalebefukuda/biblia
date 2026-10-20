import Foundation

/// Livro do cânon protestante (66 livros), na ordem tradicional.
struct BibleBook: Identifiable, Hashable, Sendable {
    /// Posição no cânon, começando em 1 (Gênesis) até 66 (Apocalipse).
    let id: Int
    let name: String
    let abbrev: String
    let chapterCount: Int

    var testament: Testament { id <= 39 ? .old : .new }
    var index: Int { id - 1 }
}

enum Testament: String, CaseIterable, Sendable {
    case old = "Antigo Testamento"
    case new = "Novo Testamento"

    var short: String { self == .old ? "AT" : "NT" }
}

/// Endereço de um capítulo (livro 1–66, capítulo começando em 1).
struct ChapterRef: Hashable, Codable, Sendable, Comparable {
    let book: Int
    let chapter: Int

    static func < (lhs: ChapterRef, rhs: ChapterRef) -> Bool {
        (lhs.book, lhs.chapter) < (rhs.book, rhs.chapter)
    }

    var bookInfo: BibleBook { Canon.book(book) }
    var title: String { "\(bookInfo.name) \(chapter)" }
    /// Posição global (0–1188) usada pelo leitor paginado.
    var globalIndex: Int { Canon.globalIndex(of: self) }
}

/// Endereço de um versículo.
struct VerseRef: Hashable, Codable, Sendable {
    let book: Int
    let chapter: Int
    let verse: Int

    var chapterRef: ChapterRef { ChapterRef(book: book, chapter: chapter) }
    /// Chave estável usada no armazenamento, ex.: "43.3.16".
    var key: String { "\(book).\(chapter).\(verse)" }
    var title: String { "\(Canon.book(book).name) \(chapter):\(verse)" }
    var shortTitle: String { "\(Canon.book(book).abbrev) \(chapter):\(verse)" }

    init(book: Int, chapter: Int, verse: Int) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
    }

    init?(key: String) {
        let parts = key.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(book: parts[0], chapter: parts[1], verse: parts[2])
    }
}

enum Canon {
    static let books: [BibleBook] = {
        let raw: [(String, String, Int)] = [
            ("Gênesis", "Gn", 50), ("Êxodo", "Êx", 40), ("Levítico", "Lv", 27),
            ("Números", "Nm", 36), ("Deuteronômio", "Dt", 34), ("Josué", "Js", 24),
            ("Juízes", "Jz", 21), ("Rute", "Rt", 4), ("1 Samuel", "1Sm", 31),
            ("2 Samuel", "2Sm", 24), ("1 Reis", "1Rs", 22), ("2 Reis", "2Rs", 25),
            ("1 Crônicas", "1Cr", 29), ("2 Crônicas", "2Cr", 36), ("Esdras", "Ed", 10),
            ("Neemias", "Ne", 13), ("Ester", "Et", 10), ("Jó", "Jó", 42),
            ("Salmos", "Sl", 150), ("Provérbios", "Pv", 31), ("Eclesiastes", "Ec", 12),
            ("Cânticos", "Ct", 8), ("Isaías", "Is", 66), ("Jeremias", "Jr", 52),
            ("Lamentações", "Lm", 5), ("Ezequiel", "Ez", 48), ("Daniel", "Dn", 12),
            ("Oseias", "Os", 14), ("Joel", "Jl", 3), ("Amós", "Am", 9),
            ("Obadias", "Ob", 1), ("Jonas", "Jn", 4), ("Miqueias", "Mq", 7),
            ("Naum", "Na", 3), ("Habacuque", "Hc", 3), ("Sofonias", "Sf", 3),
            ("Ageu", "Ag", 2), ("Zacarias", "Zc", 14), ("Malaquias", "Ml", 4),
            ("Mateus", "Mt", 28), ("Marcos", "Mc", 16), ("Lucas", "Lc", 24),
            ("João", "Jo", 21), ("Atos", "At", 28), ("Romanos", "Rm", 16),
            ("1 Coríntios", "1Co", 16), ("2 Coríntios", "2Co", 13), ("Gálatas", "Gl", 6),
            ("Efésios", "Ef", 6), ("Filipenses", "Fp", 4), ("Colossenses", "Cl", 4),
            ("1 Tessalonicenses", "1Ts", 5), ("2 Tessalonicenses", "2Ts", 3), ("1 Timóteo", "1Tm", 6),
            ("2 Timóteo", "2Tm", 4), ("Tito", "Tt", 3), ("Filemom", "Fm", 1),
            ("Hebreus", "Hb", 13), ("Tiago", "Tg", 5), ("1 Pedro", "1Pe", 5),
            ("2 Pedro", "2Pe", 3), ("1 João", "1Jo", 5), ("2 João", "2Jo", 1),
            ("3 João", "3Jo", 1), ("Judas", "Jd", 1), ("Apocalipse", "Ap", 22),
        ]
        return raw.enumerated().map { offset, item in
            BibleBook(id: offset + 1, name: item.0, abbrev: item.1, chapterCount: item.2)
        }
    }()

    /// Todos os capítulos em ordem canônica (1.189).
    static let allChapters: [ChapterRef] = books.flatMap { book in
        (1...book.chapterCount).map { ChapterRef(book: book.id, chapter: $0) }
    }

    static var totalChapters: Int { allChapters.count }

    private static let chapterOffsets: [Int] = {
        var offsets: [Int] = []
        var running = 0
        for book in books {
            offsets.append(running)
            running += book.chapterCount
        }
        return offsets
    }()

    static func book(_ id: Int) -> BibleBook {
        books[min(max(id, 1), books.count) - 1]
    }

    static func globalIndex(of ref: ChapterRef) -> Int {
        let book = Canon.book(ref.book)
        return chapterOffsets[book.index] + min(max(ref.chapter, 1), book.chapterCount) - 1
    }

    static func chapter(atGlobalIndex index: Int) -> ChapterRef {
        allChapters[min(max(index, 0), allChapters.count - 1)]
    }

    static func isValid(_ ref: ChapterRef) -> Bool {
        (1...books.count).contains(ref.book) && (1...book(ref.book).chapterCount).contains(ref.chapter)
    }
}
