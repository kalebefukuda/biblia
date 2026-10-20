import Foundation
import Testing
@testable import Biblia

struct SearchTests {
    private func makeText(_ verses: [String]) -> BibleText {
        var books = TestSupport.syntheticBooks(versesPerChapter: 1)
        books[42][2] = verses
        return BibleText(id: "TESTE", name: "Teste", books: books)
    }

    @Test func ignoresCaseAndAccents() {
        let index = SearchIndex(text: makeText(["Porque Deus amou o mundo", "Guarda o teu coração"]))
        #expect(index.search("deus").map(\.ref) == [VerseRef(book: 43, chapter: 3, verse: 1)])
        #expect(index.search("coracao").map(\.ref) == [VerseRef(book: 43, chapter: 3, verse: 2)])
        #expect(index.search("CORAÇÃO").count == 1)
    }

    @Test func requiresAllTerms() {
        let index = SearchIndex(text: makeText(["amor e fé", "amor somente"]))
        #expect(index.search("amor fé").count == 1)
        #expect(index.search("amor").count == 2)
        #expect(index.search("a").isEmpty)
    }

    @Test func respectsLimit() {
        let index = SearchIndex(text: makeText(Array(repeating: "palavra", count: 50)))
        #expect(index.search("palavra", limit: 10).count == 10)
    }

    @Test func fullBibleSearchIsFast() {
        // ~31 mil versículos de tamanho realista.
        let books = Canon.books.map { book in
            (1...book.chapterCount).map { _ in
                (1...26).map { "\($0) Então disse o Senhor ao povo que andasse nos seus caminhos com fidelidade e justiça" }
            }
        }
        let index = SearchIndex(text: BibleText(id: "TESTE", name: "Teste", books: books))
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = index.search("misericordia eterna") }
        #expect(elapsed < .milliseconds(300), "busca levou \(elapsed)")
    }
}
