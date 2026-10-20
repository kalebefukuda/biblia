import Foundation
import SwiftUI
import Testing
import WidgetKit
@testable import Biblia

@MainActor
struct WidgetTests {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9))!

    private func sampleCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for offset in 0..<200 where offset % 3 != 1 {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: now)!
            counts[DayKey.from(day)] = offset % 7 + 1
        }
        return counts
    }

    private var sampleText: BibleText {
        BibleText(id: "TESTE", name: "Teste", books: TestSupport.syntheticBooks(versesPerChapter: 200))
    }

    @Test func snapshotKeepsRecentHistoryAndAWeekOfVerses() {
        let snapshot = ReadingSync.makeSnapshot(counts: sampleCounts(), text: sampleText, previous: .empty, now: now)
        #expect(snapshot.counts.count < sampleCounts().count)
        #expect(snapshot.counts[DayKey.from(now)] != nil)
        #expect(snapshot.verses.count == 8)
        #expect(snapshot.verse(for: now)?.versionID == "TESTE")
    }

    @Test func snapshotWithoutTextKeepsPreviousVerses() {
        let first = ReadingSync.makeSnapshot(counts: [:], text: sampleText, previous: .empty, now: now)
        let second = ReadingSync.makeSnapshot(counts: ["2026-10-20": 1], text: nil, previous: first, now: now)
        #expect(second.verses == first.verses)
    }

    @Test func snapshotRoundTripsOnDisk() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        let snapshot = ReadingSync.makeSnapshot(counts: sampleCounts(), text: sampleText, previous: .empty, now: now)
        try snapshot.save(to: url)
        #expect(WidgetSnapshot.load(from: url) == snapshot)
        #expect(WidgetSnapshot.load(from: url.appendingPathExtension("x")) == .empty)
    }

    @Test func verseOfDayReferencesAreValid() {
        for key in VerseOfDay.references {
            let ref = VerseRef(key: key)
            #expect(ref != nil && Canon.isValid(ref!.chapterRef), "\(key)")
        }
    }

    /// Renderiza os widgets em PNG para conferência visual (pasta definida por WIDGET_RENDER_DIR).
    @Test func rendersWidgetPreviews() throws {
        let snapshot = ReadingSync.makeSnapshot(counts: sampleCounts(), text: sampleText, previous: .empty, now: now)
        let views: [(String, AnyView, CGSize)] = [
            ("sequencia-pequeno", AnyView(StreakWidgetView(snapshot: snapshot, date: now, family: .systemSmall)), CGSize(width: 170, height: 170)),
            ("sequencia-medio", AnyView(StreakWidgetView(snapshot: snapshot, date: now, family: .systemMedium)), CGSize(width: 364, height: 170)),
            ("versiculo-medio", AnyView(VerseWidgetView(verse: snapshot.verse(for: now), family: .systemMedium)), CGSize(width: 364, height: 170)),
        ]
        let dir = ProcessInfo.processInfo.environment["WIDGET_RENDER_DIR"].map(URL.init(fileURLWithPath:))
        for (name, view, size) in views {
            let renderer = ImageRenderer(content: view.padding(16).frame(width: size.width, height: size.height).background(Color(.systemBackground)))
            renderer.scale = 2
            let image = try #require(renderer.uiImage, "\(name) não renderizou")
            #expect(image.size.width > 0)
            if let dir, let data = image.pngData() {
                try data.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
    }
}
