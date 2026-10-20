import Foundation

/// Um quadradinho do mapa de leitura.
struct HeatDay: Hashable, Sendable {
    let date: Date
    let key: String
    let count: Int
    let isFuture: Bool
    let isToday: Bool

    var level: Int { ReadingStats.level(for: count) }
}

/// Cálculos do mapa estilo GitHub e da sequência de dias. Puro: recebe a
/// contagem de capítulos por dia ("yyyy-MM-dd" → quantidade) e a data de hoje.
struct ReadingStats: Sendable {
    let counts: [String: Int]
    var calendar: Calendar = .current
    var today: Date = .now

    var todayKey: String { DayKey.from(today, calendar: calendar) }
    var readToday: Bool { (counts[todayKey] ?? 0) > 0 }
    var daysRead: Int { counts.values.filter { $0 > 0 }.count }
    var totalChapters: Int { counts.values.reduce(0, +) }

    /// Dias seguidos com leitura. Se hoje ainda não teve leitura, a sequência
    /// de ontem continua valendo até o fim do dia.
    var currentStreak: Int {
        var day = calendar.startOfDay(for: today)
        if !readToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while (counts[DayKey.from(day, calendar: calendar)] ?? 0) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var longestStreak: Int {
        let days = counts.filter { $0.value > 0 }.keys
            .compactMap { DayKey.date(from: $0, calendar: calendar) }
            .sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// 0 = nada, 1 = 1 capítulo, 2 = 2–3, 3 = 4–6, 4 = 7 ou mais.
    static func level(for count: Int) -> Int {
        switch count {
        case ..<1: 0
        case 1: 1
        case 2...3: 2
        case 4...6: 3
        default: 4
        }
    }

    /// Colunas de semanas (domingo a sábado), terminando na semana de hoje.
    func heatmap(weeks: Int) -> [[HeatDay]] {
        let todayStart = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: todayStart) // 1 = domingo
        guard let thisSunday = calendar.date(byAdding: .day, value: -(weekday - 1), to: todayStart),
              let firstSunday = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisSunday)
        else { return [] }

        return (0..<weeks).map { week in
            (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + offset, to: firstSunday) else { return nil }
                let key = DayKey.from(date, calendar: calendar)
                return HeatDay(
                    date: date,
                    key: key,
                    count: counts[key] ?? 0,
                    isFuture: date > todayStart,
                    isToday: date == todayStart
                )
            }
        }
    }
}
