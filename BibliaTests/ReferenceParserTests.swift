import Testing
@testable import Biblia

struct ReferenceParserTests {
    @Test(arguments: [
        ("Jo 3:16", 43, 3, 16 as Int?, nil as Int?),
        ("jo 3.16", 43, 3, 16, nil),
        ("joao3:16", 43, 3, 16, nil),
        ("João 3", 43, 3, nil, nil),
        ("Jó 1", 18, 1, nil, nil),
        ("1 Co 13:4-7", 46, 13, 4, 7),
        ("1co13", 46, 13, nil, nil),
        ("1 João 4:8", 62, 4, 8, nil),
        ("3 jo 1", 64, 1, nil, nil),
        ("Sl 23", 19, 23, nil, nil),
        ("salmos 23:1", 19, 23, 1, nil),
        ("Gn", 1, 1, nil, nil),
        ("Êx 20", 2, 20, nil, nil),
        ("ex 20", 2, 20, nil, nil),
        ("Fil 4:13", 50, 4, 13, nil),
        ("cantares de salomão 2", 22, 2, nil, nil),
        ("apoc 22:21", 66, 22, 21, nil),
        ("mat 5:3-12", 40, 5, 3, 12),
        ("2 Tm 3:16", 55, 3, 16, nil),
    ])
    func parsesValidReferences(input: String, book: Int, chapter: Int, verse: Int?, verseEnd: Int?) {
        #expect(ReferenceParser.parse(input) == ParsedReference(book: book, chapter: chapter, verse: verse, verseEnd: verseEnd))
    }

    @Test(arguments: ["", "3", "xyz 1", "Gn 51", "Mt 5:12-3", "amor", "deus", "fi 1", String(repeating: "a", count: 500) + " 1"])
    func rejectsInvalid(input: String) {
        #expect(ReferenceParser.parse(input) == nil)
    }
}
