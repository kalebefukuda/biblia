import Foundation
import SwiftData
import Testing
@testable import Biblia

struct AccessibilityTests {
    private func day(_ key: String, count: Int) -> HeatDay {
        HeatDay(date: DayKey.date(from: key)!, key: key, count: count, isFuture: false, isToday: false)
    }

    @Test func adjustableStepsThroughReadDays() {
        let days = [day("2026-10-01", count: 1), day("2026-10-05", count: 3), day("2026-10-09", count: 2)]
        #expect(HeatmapView.step(from: nil, in: days, forward: true)?.key == "2026-10-01")
        #expect(HeatmapView.step(from: nil, in: days, forward: false)?.key == "2026-10-09")
        #expect(HeatmapView.step(from: days[0], in: days, forward: true)?.key == "2026-10-05")
        #expect(HeatmapView.step(from: days[2], in: days, forward: true)?.key == "2026-10-09")
        #expect(HeatmapView.step(from: nil, in: [], forward: true) == nil)
    }

    @Test func describesDayWithCorrectPlural() {
        #expect(HeatmapView.describe(day("2026-10-01", count: 1)).hasSuffix("1 capítulo"))
        #expect(HeatmapView.describe(day("2026-10-01", count: 3)).hasSuffix("3 capítulos"))
    }

    @Test @MainActor func verseStateDescribesSelectionAndMarks() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let store = BibleStore(context: container.mainContext)
        let ref = VerseRef(book: 43, chapter: 3, verse: 16)
        store.setColor(.amarelo, for: [ref])
        store.toggleSaved(for: [ref])
        store.setNote("nota", for: ref)
        let mark = store.mark(for: ref)

        #expect(VerseRow.accessibilityState(mark: mark, isSelected: true) == "selecionado, destaque amarelo, salvo, com nota")
        #expect(VerseRow.accessibilityState(mark: nil, isSelected: false) == "")
    }
}
