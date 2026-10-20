import Foundation
import SwiftData
import Testing
@testable import Biblia

@MainActor
struct BackupTests {
    @Test func exportThenRestoreRecoversEverything() throws {
        let source = try Persistence.makeContainer(inMemory: true)
        let store = BibleStore(context: source.mainContext)
        store.setColor(.verde, for: [VerseRef(book: 43, chapter: 3, verse: 16)])
        store.toggleSaved(for: [VerseRef(book: 19, chapter: 23, verse: 1)])
        store.setNote("Bom pastor", for: VerseRef(book: 19, chapter: 23, verse: 1))
        store.markRead([ChapterRef(book: 1, chapter: 1), ChapterRef(book: 1, chapter: 2)])
        source.mainContext.insert(PlanEnrollment(planID: "salmos-30-dias"))

        let data = try BackupService.encode(BackupService.makeBackup(context: source.mainContext))

        let target = try Persistence.makeContainer(inMemory: true)
        let counts = BackupService.restore(try BackupService.decode(data), into: target.mainContext)
        #expect(counts.marks == 2 && counts.readings == 2 && counts.plans == 1)

        let restored = BibleStore(context: target.mainContext)
        #expect(restored.mark(for: VerseRef(book: 43, chapter: 3, verse: 16))?.color == .verde)
        #expect(restored.mark(for: VerseRef(book: 19, chapter: 23, verse: 1))?.note == "Bom pastor")
        #expect(restored.isRead(ChapterRef(book: 1, chapter: 2)))
    }

    @Test func restoringTwiceDoesNotDuplicate() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let store = BibleStore(context: container.mainContext)
        store.markRead([ChapterRef(book: 1, chapter: 1)])
        store.setColor(.azul, for: [VerseRef(book: 1, chapter: 1, verse: 1)])
        let backup = BackupService.makeBackup(context: container.mainContext)

        BackupService.restore(backup, into: container.mainContext)
        BackupService.restore(backup, into: container.mainContext)
        #expect(store.allEntries().count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<VerseMark>()).count == 1)
    }

    @Test func restoreKeepsNewerLocalMarkAndOverwritesOlder() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let store = BibleStore(context: container.mainContext)
        let newer = VerseRef(book: 1, chapter: 1, verse: 1), older = VerseRef(book: 1, chapter: 1, verse: 2)
        store.setColor(.azul, for: [newer, older])
        store.mark(for: older)?.updatedAt = .distantPast

        let backup = Backup(
            exportedAt: .now,
            marks: [
                Backup.Mark(book: 1, chapter: 1, verse: 1, color: "rosa", underline: false, saved: false, note: nil, updatedAt: Date(timeIntervalSince1970: 0)),
                Backup.Mark(book: 1, chapter: 1, verse: 2, color: "rosa", underline: false, saved: false, note: nil, updatedAt: .now),
            ],
            readings: [],
            plans: []
        )
        BackupService.restore(backup, into: container.mainContext)
        #expect(store.mark(for: newer)?.color == .azul)
        #expect(store.mark(for: older)?.color == .rosa)
    }

    @Test func restoreDeduplicatesReadingsInsideTheFile() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let reading = Backup.Reading(dayKey: "2026-10-20", book: 1, chapter: 1, readAt: .now)
        let backup = Backup(exportedAt: .now, marks: [], readings: [reading, reading], plans: [])
        let counts = BackupService.restore(backup, into: container.mainContext)
        #expect(counts.readings == 1)
        #expect(BibleStore(context: container.mainContext).allEntries().count == 1)
    }

    @Test func longNotesSurviveSaveAndRestore() throws {
        let note = String(repeating: "Estudo de Romanos 8. ", count: 700) // ~14 mil caracteres
        let source = try Persistence.makeContainer(inMemory: true)
        BibleStore(context: source.mainContext).setNote(note, for: VerseRef(book: 45, chapter: 8, verse: 28))
        let data = try BackupService.encode(BackupService.makeBackup(context: source.mainContext))

        let target = try Persistence.makeContainer(inMemory: true)
        BackupService.restore(try BackupService.decode(data), into: target.mainContext)
        let restored = BibleStore(context: target.mainContext).mark(for: VerseRef(book: 45, chapter: 8, verse: 28))?.note
        #expect(restored == note.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test func rejectsForeignFiles() {
        #expect(throws: BackupError.self) { try BackupService.decode(Data(#"{"foo": 1}"#.utf8)) }
        #expect(throws: BackupError.self) { try BackupService.decode(Data(count: BackupService.maxSize + 1)) }
    }

    @Test func ignoresInvalidReferences() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let backup = Backup(
            exportedAt: .now,
            marks: [Backup.Mark(book: 99, chapter: 1, verse: 1, color: "verde", underline: false, saved: true, note: nil, updatedAt: .now)],
            readings: [Backup.Reading(dayKey: "lixo", book: 1, chapter: 1, readAt: .now)],
            plans: [Backup.Plan(planID: "plano-inexistente", startedAt: .now)]
        )
        let counts = BackupService.restore(backup, into: container.mainContext)
        #expect(counts.marks == 0 && counts.readings == 0 && counts.plans == 0)
    }
}
