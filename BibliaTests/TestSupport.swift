import Foundation
@testable import Biblia

enum TestSupport {
    /// Versão sintética (texto fictício) com a estrutura completa do cânon.
    static func syntheticBooks(versesPerChapter: Int = 3) -> [[[String]]] {
        Canon.books.map { book in
            (1...book.chapterCount).map { chapter in
                (1...versesPerChapter).map { "\(book.abbrev) \(chapter):\($0) texto de exemplo" }
            }
        }
    }

    static func formatA(_ books: [[[String]]]) -> Data {
        let array = zip(Canon.books, books).map { book, chapters in
            ["abbrev": book.abbrev, "chapters": chapters] as [String: Any]
        }
        return try! JSONSerialization.data(withJSONObject: array)
    }

    static func formatB(_ books: [[[String]]]) -> Data {
        let array = zip(Canon.books, books).map { book, chapters in
            [
                "name": book.name,
                "chapters": chapters.enumerated().map { index, verses in
                    ["chapter": index + 1, "verses": verses.enumerated().map { ["verse": $0.offset + 1, "text": $0.element] }]
                },
            ] as [String: Any]
        }
        return try! JSONSerialization.data(withJSONObject: ["books": array])
    }

    /// Pasta Versoes/ do projeto (não versionada). Pode não existir.
    static var localVersionsFolder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Versoes")
    }
}
