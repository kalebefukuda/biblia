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

    /// Termos com pelo menos 2 letras; o resultado é limitado para manter a lista leve.
    func search(_ query: String, limit: Int = 300) -> [Hit] {
        let terms = Self.fold(query)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
        guard !terms.isEmpty else { return [] }

        var hits: [Hit] = []
        for index in folded.indices {
            let verse = folded[index]
            if terms.allSatisfy({ verse.range(of: $0, options: .literal) != nil }) {
                hits.append(Hit(ref: refs[index]))
                if hits.count >= limit { break }
            }
        }
        return hits
    }
}
