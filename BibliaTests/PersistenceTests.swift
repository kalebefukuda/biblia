import Foundation
import SwiftData
import Testing
@testable import Biblia

@MainActor
struct PersistenceTests {
    let container: ModelContainer
    let store: BibleStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        store = BibleStore(context: container.mainContext)
    }

    private var marks: [VerseMark] { (try? container.mainContext.fetch(FetchDescriptor<VerseMark>())) ?? [] }

    @Test func highlightAndRemove() {
        let refs = [VerseRef(book: 43, chapter: 3, verse: 16), VerseRef(book: 43, chapter: 3, verse: 17)]
        store.setColor(.amarelo, for: refs)
        #expect(marks.count == 2)
        #expect(store.mark(for: refs[0])?.color == .amarelo)

        store.setColor(nil, for: refs)
        #expect(marks.isEmpty)
    }

    @Test func underlineTogglesAsGroup() {
        let a = VerseRef(book: 1, chapter: 1, verse: 1), b = VerseRef(book: 1, chapter: 1, verse: 2)
        store.toggleUnderline(for: [a])
        store.toggleUnderline(for: [a, b])
        #expect(store.mark(for: a)?.underline == true)
        #expect(store.mark(for: b)?.underline == true)
        store.toggleUnderline(for: [a, b])
        #expect(marks.isEmpty)
    }

    @Test func savedAndNoteKeepMarkAlive() {
        let ref = VerseRef(book: 19, chapter: 23, verse: 1)
        store.toggleSaved(for: [ref])
        store.setNote("  Salmo do pastor  ", for: ref)
        #expect(store.mark(for: ref)?.note == "Salmo do pastor")
        store.toggleSaved(for: [ref])
        #expect(store.mark(for: ref) != nil)
        store.setNote("   ", for: ref)
        #expect(store.mark(for: ref) == nil)
    }

    @Test func readingIsOncePerChapterPerDay() {
        let ref = ChapterRef(book: 1, chapter: 1)
        let today = Date()
        store.markRead([ref], at: today)
        store.markRead([ref], at: today)
        #expect(store.allEntries().count == 1)
        #expect(store.isRead(ref, on: today))

        store.markRead([ref], at: today.addingTimeInterval(-86_400))
        #expect(store.chaptersPerDay().count == 2)

        store.unmarkRead(ref, on: today)
        #expect(!store.isRead(ref, on: today))
        #expect(store.allEntries().count == 1)
    }
}
