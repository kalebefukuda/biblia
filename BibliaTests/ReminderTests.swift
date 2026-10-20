import Foundation
import Testing
import UserNotifications
@testable import Biblia

final class FakeCenter: NotificationScheduling {
    var requests: [String: UNNotificationRequest] = [:]

    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { identifiers.forEach { requests[$0] = nil } }
    func pendingIdentifiers() async -> [String] { Array(requests.keys) }
}

struct ReminderTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private let settings = ReminderSettings(enabled: true, hour: 20, minute: 30)

    @Test func schedulesNextFourteenDaysAtChosenTime() async throws {
        let center = FakeCenter()
        let scheduler = ReminderScheduler(center: center, calendar: calendar)
        await scheduler.reschedule(settings, readToday: false, streak: 0, now: date(20, 9))

        #expect(center.requests.count == 14)
        let first = try #require(center.requests["lembrete-2026-10-20"]?.trigger as? UNCalendarNotificationTrigger)
        #expect(first.dateComponents.hour == 20 && first.dateComponents.minute == 30 && first.dateComponents.day == 20)
        #expect(center.requests["lembrete-2026-11-02"] != nil)
    }

    @Test func readingTodayRemovesOnlyTodaysReminder() async {
        let center = FakeCenter()
        let scheduler = ReminderScheduler(center: center, calendar: calendar)
        await scheduler.reschedule(settings, readToday: false, streak: 3, now: date(20, 9))
        #expect(center.requests["lembrete-2026-10-20"]?.content.body.contains("3 dias") == true)

        await scheduler.reschedule(settings, readToday: true, streak: 4, now: date(20, 10))
        #expect(center.requests["lembrete-2026-10-20"] == nil)
        #expect(center.requests["lembrete-2026-10-21"] != nil)
        #expect(center.requests.count == 13)
    }

    @Test func skipsTodayWhenTimeAlreadyPassed() async {
        let center = FakeCenter()
        let scheduler = ReminderScheduler(center: center, calendar: calendar)
        await scheduler.reschedule(settings, readToday: false, streak: 0, now: date(20, 21))
        #expect(center.requests["lembrete-2026-10-20"] == nil)
        #expect(center.requests.count == 13)
    }

    @Test func disablingClearsEverything() async {
        let center = FakeCenter()
        let scheduler = ReminderScheduler(center: center, calendar: calendar)
        await scheduler.reschedule(settings, readToday: false, streak: 0, now: date(20, 9))
        center.requests["outra-coisa"] = UNNotificationRequest(identifier: "outra-coisa", content: UNNotificationContent(), trigger: nil)
        await scheduler.reschedule(ReminderSettings(enabled: false, hour: 20, minute: 30), readToday: false, streak: 0, now: date(20, 9))
        #expect(Array(center.requests.keys) == ["outra-coisa"])
    }
}
