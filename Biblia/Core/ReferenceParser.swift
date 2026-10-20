import Foundation

struct ParsedReference: Equatable, Sendable {
    let book: Int
    let chapter: Int
    let verse: Int?
    let verseEnd: Int?

    var chapterRef: ChapterRef { ChapterRef(book: book, chapter: chapter) }

    var title: String {
        var text = "\(Canon.book(book).name) \(chapter)"
        if let verse { text += ":\(verse)" }
        if let verseEnd { text += "-\(verseEnd)" }
        return text
    }
}

/// Entende referências digitadas como "Jo 3:16", "1 Co 13:4-7", "joao 3" ou "Sl 23".
enum ReferenceParser {
    private static let pattern = try! NSRegularExpression(
        pattern: #"^\s*([1-3])?\s*([^\d\s:.,\-][^\d:,\-]*?)\.?\s*(\d+)?\s*(?:[:.,]\s*(\d+)\s*(?:-\s*(\d+))?)?\s*$"#,
        options: [.caseInsensitive]
    )

    static func parse(_ input: String) -> ParsedReference? {
        // Referências reais são curtas; limitar evita trabalho desnecessário com texto colado.
        guard input.count <= 60 else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let match = pattern.firstMatch(in: input, range: range) else { return nil }

        func group(_ index: Int) -> String? {
            guard let r = Range(match.range(at: index), in: input) else { return nil }
            return String(input[r])
        }

        let number = group(1) ?? ""
        guard let name = group(2), let book = matchBook(number: number, name: name) else { return nil }

        let chapter = group(3).flatMap(Int.init) ?? 1
        guard Canon.isValid(ChapterRef(book: book, chapter: chapter)) else { return nil }

        let verse = group(4).flatMap(Int.init)
        let verseEnd = group(5).flatMap(Int.init)
        if let verse, verse < 1 { return nil }
        if let verse, let verseEnd, verseEnd < verse { return nil }
        return ParsedReference(book: book, chapter: chapter, verse: verse, verseEnd: verseEnd)
    }

    static func matchBook(number: String, name: String) -> Int? {
        let raw = (number + name).lowercased().filter { !$0.isWhitespace && $0 != "." }
        // "Jó" e "Jo" (João) só diferem pelo acento.
        if raw == "jó" { return 18 }

        let token = fold(raw)
        guard !token.isEmpty else { return nil }
        if let exact = aliases[token] { return exact }

        guard token.count >= 2 else { return nil }
        let candidates = Canon.books.filter { fold($0.name).hasPrefix(token) }
        return candidates.count == 1 ? candidates[0].id : nil
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .filter { !$0.isWhitespace && $0 != "." }
    }

    private static let aliases: [String: Int] = {
        var table: [String: Int] = [:]
        // Nome completo primeiro e abreviação depois: assim "jo" fica com João (abreviação),
        // e não com Jó (cujo nome sem acento também é "jo").
        for book in Canon.books { table[fold(book.name)] = book.id }
        for book in Canon.books { table[fold(book.abbrev)] = book.id }
        let extras: [String: Int] = [
            "job": 18, "salmo": 19, "sal": 19, "prov": 20, "cantares": 22, "cantico": 22,
            "canticodoscanticos": 22, "cantaresdesalomao": 22, "oseias": 28, "oséias": 28,
            "miqueias": 33, "atos": 44, "fil": 50, "apoc": 66, "1tim": 54, "2tim": 55,
        ]
        for (key, value) in extras { table[fold(key)] = value }
        return table
    }()
}
