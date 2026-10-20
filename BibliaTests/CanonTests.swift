import Testing
@testable import Biblia

struct CanonTests {
    @Test func hasSixtySixBooksAndAllChapters() {
        #expect(Canon.books.count == 66)
        #expect(Canon.books.filter { $0.testament == .old }.count == 39)
        #expect(Canon.books.filter { $0.testament == .new }.count == 27)
        #expect(Canon.totalChapters == 1189)
        #expect(Canon.books.filter { $0.testament == .old }.reduce(0) { $0 + $1.chapterCount } == 929)
    }

    @Test func globalIndexRoundTrips() {
        #expect(Canon.globalIndex(of: ChapterRef(book: 1, chapter: 1)) == 0)
        #expect(Canon.globalIndex(of: ChapterRef(book: 66, chapter: 22)) == 1188)
        for index in [0, 49, 50, 600, 1188] {
            #expect(Canon.chapter(atGlobalIndex: index).globalIndex == index)
        }
    }

    @Test func verseKeyRoundTrips() {
        let ref = VerseRef(book: 43, chapter: 3, verse: 16)
        #expect(ref.key == "43.3.16")
        #expect(VerseRef(key: ref.key) == ref)
        #expect(VerseRef(key: "lixo") == nil)
    }
}
