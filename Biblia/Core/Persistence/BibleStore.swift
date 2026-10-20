import Foundation
import SwiftData

/// Operações de escrita sobre marcações e leituras. As telas leem com @Query;
/// toda mudança passa por aqui para manter as regras num lugar só.
@MainActor
struct BibleStore {
    let context: ModelContext
    var calendar: Calendar = .current

    // MARK: Marcações

    func mark(for ref: VerseRef) -> VerseMark? {
        let key = ref.key
        var descriptor = FetchDescriptor<VerseMark>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func upsert(_ ref: VerseRef) -> VerseMark {
        if let existing = mark(for: ref) { return existing }
        let mark = VerseMark(ref: ref)
        context.insert(mark)
        return mark
    }

    private func finish(_ mark: VerseMark) {
        mark.updatedAt = .now
        if mark.isEmpty { context.delete(mark) }
    }

    func setColor(_ color: HighlightColor?, for refs: [VerseRef]) {
        for ref in refs {
            let mark = upsert(ref)
            mark.color = color
            finish(mark)
        }
        save()
    }

    /// Sublinha todos se algum ainda não estiver sublinhado; senão remove de todos.
    func toggleUnderline(for refs: [VerseRef]) {
        let shouldUnderline = refs.contains { !(mark(for: $0)?.underline ?? false) }
        for ref in refs {
            let mark = upsert(ref)
            mark.underline = shouldUnderline
            finish(mark)
        }
        save()
    }

    func toggleSaved(for refs: [VerseRef]) {
        let shouldSave = refs.contains { !(mark(for: $0)?.saved ?? false) }
        for ref in refs {
            let mark = upsert(ref)
            mark.saved = shouldSave
            finish(mark)
        }
        save()
    }

    func setNote(_ note: String?, for ref: VerseRef) {
        let mark = upsert(ref)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        mark.note = (trimmed?.isEmpty ?? true) ? nil : trimmed
        finish(mark)
        save()
    }

    // MARK: Leitura

    func entries(for ref: ChapterRef) -> [ReadingEntry] {
        let book = ref.book, chapter = ref.chapter
        let descriptor = FetchDescriptor<ReadingEntry>(predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        return (try? context.fetch(descriptor)) ?? []
    }

    func isRead(_ ref: ChapterRef, on date: Date = .now) -> Bool {
        let day = DayKey.from(date, calendar: calendar)
        return entries(for: ref).contains { $0.dayKey == day }
    }

    func markRead(_ refs: [ChapterRef], at date: Date = .now) {
        let day = DayKey.from(date, calendar: calendar)
        for ref in refs where !entries(for: ref).contains(where: { $0.dayKey == day }) {
            context.insert(ReadingEntry(chapter: ref, at: date, calendar: calendar))
        }
        save()
    }

    func unmarkRead(_ ref: ChapterRef, on date: Date = .now) {
        let day = DayKey.from(date, calendar: calendar)
        for entry in entries(for: ref) where entry.dayKey == day {
            context.delete(entry)
        }
        save()
    }

    func allEntries() -> [ReadingEntry] {
        (try? context.fetch(FetchDescriptor<ReadingEntry>())) ?? []
    }

    /// Quantos capítulos foram lidos em cada dia.
    func chaptersPerDay() -> [String: Int] {
        allEntries().reduce(into: [:]) { $0[$1.dayKey, default: 0] += 1 }
    }

    func save() {
        try? context.save()
    }
}
