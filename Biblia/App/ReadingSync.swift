import Foundation
import UserNotifications

/// Mantém lembretes (e o widget) em dia com as leituras registradas.
@MainActor
enum ReadingSync {
    static func refresh(_ store: BibleStore) {
        let stats = ReadingStats(counts: store.chaptersPerDay())
        let settings = ReminderSettings.load()
        let scheduler = ReminderScheduler(center: UNUserNotificationCenter.current())
        Task {
            await scheduler.reschedule(settings, readToday: stats.readToday, streak: stats.currentStreak)
        }
    }
}
