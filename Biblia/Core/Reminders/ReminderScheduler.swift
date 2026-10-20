import Foundation
import UserNotifications

/// O que o agendador precisa da central de notificações (permite testar sem o sistema).
protocol NotificationScheduling: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingIdentifiers() async -> [String]
}

extension UNUserNotificationCenter: NotificationScheduling {
    func pendingIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }
}

struct ReminderSettings: Equatable, Sendable {
    var enabled: Bool
    var hour: Int
    var minute: Int

    static let enabledKey = "lembreteAtivo"
    static let hourKey = "lembreteHora"
    static let minuteKey = "lembreteMinuto"

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> ReminderSettings {
        ReminderSettings(
            enabled: defaults.bool(forKey: enabledKey),
            hour: defaults.object(forKey: hourKey) as? Int ?? 7,
            minute: defaults.object(forKey: minuteKey) as? Int ?? 0
        )
    }
}

/// Lembrete diário de leitura. Notificações locais não conseguem "checar"
/// na hora se você já leu, então agendamos um aviso por dia (próximas 2 semanas)
/// e removemos o de hoje quando a leitura do dia é registrada.
struct ReminderScheduler {
    static let prefix = "lembrete-"

    let center: NotificationScheduling
    var calendar: Calendar = .current
    var daysAhead = 14

    static func identifier(for date: Date, calendar: Calendar = .current) -> String {
        prefix + DayKey.from(date, calendar: calendar)
    }

    func reschedule(_ settings: ReminderSettings, readToday: Bool, streak: Int, now: Date = .now) async {
        let existing = await center.pendingIdentifiers().filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)
        guard settings.enabled else { return }

        let today = calendar.startOfDay(for: now)
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: day)
            else { continue }
            if offset == 0 && (readToday || fire <= now) { continue }

            let content = UNMutableNotificationContent()
            content.title = "Hora da leitura"
            content.body = offset == 0 && streak > 0
                ? "Você está há \(streak) \(streak == 1 ? "dia" : "dias") seguidos. Não deixe a sequência parar hoje."
                : "Você ainda não leu a Bíblia hoje. Que tal um capítulo agora?"
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.identifier(for: day, calendar: calendar), content: content, trigger: trigger))
        }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
