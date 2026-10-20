import Foundation
import UserNotifications
import WidgetKit

/// Mantém lembretes e widget em dia com as leituras registradas.
@MainActor
enum ReadingSync {
    /// Quantos dias de histórico vão para o widget (o maior mapa mostra 15 semanas).
    static let widgetHistoryDays = 120

    static func refresh(_ store: BibleStore, text: BibleText? = nil) {
        let counts = store.chaptersPerDay()
        let stats = ReadingStats(counts: counts)
        let settings = ReminderSettings.load()
        let scheduler = ReminderScheduler(center: UNUserNotificationCenter.current())
        Task {
            await scheduler.reschedule(settings, readToday: stats.readToday, streak: stats.currentStreak)
        }
        updateWidget(counts: counts, text: text)
    }

    static func updateWidget(counts: [String: Int], text: BibleText?, now: Date = .now) {
        var snapshot = makeSnapshot(counts: counts, text: text, previous: WidgetSnapshot.load(), now: now)
        snapshot.updatedAt = now
        try? snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Mantém só o histórico recente e os versículos de hoje até daqui a 7 dias.
    static func makeSnapshot(counts: [String: Int], text: BibleText?, previous: WidgetSnapshot, now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        let cutoff = calendar.date(byAdding: .day, value: -widgetHistoryDays, to: now).map { DayKey.from($0, calendar: calendar) } ?? ""
        let recent = counts.filter { $0.key >= cutoff }

        var verses = previous.verses
        if let text {
            verses = [:]
            for offset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let key = VerseOfDay.reference(for: day, calendar: calendar)
                guard let ref = VerseRef(key: key), let verse = text.verse(ref) else { continue }
                verses[DayKey.from(day, calendar: calendar)] = WidgetSnapshot.Verse(key: key, title: ref.title, text: verse, versionID: text.id)
            }
        }
        return WidgetSnapshot(counts: recent, verses: verses, updatedAt: now)
    }
}
