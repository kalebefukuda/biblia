import Foundation
import SwiftData
import Testing
@testable import Biblia

struct WordSearchTests {
    private func index(_ verses: [String]) -> SearchIndex {
        var books = TestSupport.syntheticBooks(versesPerChapter: 1)
        books[42][2] = verses
        books[39][0] = ["Bem-aventurados os pacificadores"] // Mateus 1, para o teste do NT
        return SearchIndex(text: BibleText(id: "TESTE", name: "Teste", books: books))
    }

    @Test func matchesOnlyAtWordStart() {
        let idx = index(["Deixo-vos a paz", "ele é capaz de guardar", "Tende pazes uns com os outros"])
        let found = idx.search("paz").map(\.ref.verse)
        #expect(found == [1, 3])
    }

    @Test func prefixCoversInflections() {
        let idx = index(["os amores do mundo", "amoroso é o Senhor", "clamor do povo"])
        #expect(idx.search("amor").map(\.ref.verse) == [1, 2])
    }

    @Test func hasNoResultCapByDefault() {
        let idx = index(Array(repeating: "graça e paz", count: 450))
        #expect(idx.search("graça").count == 450)
    }

    @Test func highlightRangesFollowTheSameRule() {
        let text = SearchIndex.fold("A paz do capaz")
        #expect(SearchIndex.wordStartRanges(of: "paz", in: text).count == 1)
    }
}
