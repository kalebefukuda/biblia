import Foundation

/// Índice de busca por palavras de uma versão. Ignora acentos e maiúsculas
/// ("coracao" encontra "coração"); todas as palavras digitadas precisam aparecer.
final class SearchIndex: Sendable {
    struct Hit: Identifiable, Hashable, Sendable {
        let ref: VerseRef
        var id: String { ref.key }
    }

    let versionID: String
    private let refs: [VerseRef]
    private let folded: [String]

    init(text: BibleText) {
        versionID = text.id
        var refs: [VerseRef] = []
        var folded: [String] = []
        refs.reserveCapacity(31_200)
        folded.reserveCapacity(31_200)
        for (bookIndex, chapters) in text.books.enumerated() {
            for (chapterIndex, verses) in chapters.enumerated() {
                for (verseIndex, verse) in verses.enumerated() {
                    refs.append(VerseRef(book: bookIndex + 1, chapter: chapterIndex + 1, verse: verseIndex + 1))
                    folded.append(Self.fold(verse))
                }
            }
        }
        self.refs = refs
        self.folded = folded
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
    }

    /// Todos os termos (2+ letras) precisam começar alguma palavra do versículo:
    /// "paz" encontra "paz" e "pazes", mas não "capaz". Sem limite de resultados;
    /// a tela filtra por testamento para o Novo Testamento ser alcançável.
    func search(_ query: String, limit: Int? = nil) -> [Hit] {
        let terms = Self.terms(in: query)
        guard !terms.isEmpty else { return [] }

        var hits: [Hit] = []
        for index in folded.indices {
            let verse = folded[index]
            if terms.allSatisfy({ Self.hasWord(startingWith: $0, in: verse) }) {
                hits.append(Hit(ref: refs[index]))
                if let limit, hits.count >= limit { break }
            }
        }
        return hits
    }

    static func terms(in query: String) -> [String] {
        fold(query)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    /// Trechos de `text` onde `term` aparece no começo de uma palavra.
    static func wordStartRanges(of term: String, in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start = text.startIndex
        while let range = text.range(of: term, options: .literal, range: start..<text.endIndex) {
            if isWordStart(range.lowerBound, in: text) { result.append(range) }
            start = range.upperBound
        }
        return result
    }

    static func hasWord(startingWith term: String, in text: String) -> Bool {
        var start = text.startIndex
        while let range = text.range(of: term, options: .literal, range: start..<text.endIndex) {
            if isWordStart(range.lowerBound, in: text) { return true }
            start = range.upperBound
        }
        return false
    }

    private static func isWordStart(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return !previous.isLetter && !previous.isNumber
    }
}
