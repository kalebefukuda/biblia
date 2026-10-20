import Foundation

enum VerseFormatting {
    /// "João 3:16", "João 3:16-18" ou "João 3:16, 18".
    static func title(for refs: [VerseRef]) -> String {
        let sorted = refs.sorted { ($0.book, $0.chapter, $0.verse) < ($1.book, $1.chapter, $1.verse) }
        guard let first = sorted.first else { return "" }
        let numbers = sorted.filter { $0.chapterRef == first.chapterRef }.map(\.verse)
        return "\(Canon.book(first.book).name) \(first.chapter):\(ranges(numbers))"
    }

    static func ranges(_ numbers: [Int]) -> String {
        var parts: [String] = []
        var start: Int?
        var previous: Int?
        for number in numbers.sorted() {
            if let p = previous, number == p + 1 {
                previous = number
                continue
            }
            if let s = start, let p = previous { parts.append(s == p ? "\(s)" : "\(s)-\(p)") }
            start = number
            previous = number
        }
        if let s = start, let p = previous { parts.append(s == p ? "\(s)" : "\(s)-\(p)") }
        return parts.joined(separator: ", ")
    }

    /// Texto para copiar ou compartilhar.
    static func shareText(for refs: [VerseRef], in text: BibleText) -> String {
        let sorted = refs.sorted { ($0.book, $0.chapter, $0.verse) < ($1.book, $1.chapter, $1.verse) }
        let body = sorted.compactMap { text.verse($0) }.joined(separator: " ")
        return "“\(body)”\n— \(title(for: sorted)) (\(text.id))"
    }
}
