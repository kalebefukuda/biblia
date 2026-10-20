import Foundation
import Testing
@testable import Biblia

struct ReadingStatsTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return c
    }()

    /// 20/10/2026 às 22h em Brasília (01h do dia 21 em UTC).
    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 22))!
    }

    private func stats(_ counts: [String: Int]) -> ReadingStats {
        ReadingStats(counts: counts, calendar: calendar, today: today)
    }

    @Test func todayUsesLocalDayNotUTC() {
        #expect(stats([:]).todayKey == "2026-10-20")
    }

    @Test func streakCountsBackFromToday() {
        let s = stats(["2026-10-20": 1, "2026-10-19": 2, "2026-10-18": 1, "2026-10-16": 1])
        #expect(s.readToday)
        #expect(s.currentStreak == 3)
        #expect(s.longestStreak == 3)
    }

    @Test func streakSurvivesUntilEndOfDay() {
        let s = stats(["2026-10-19": 1, "2026-10-18": 1])
        #expect(!s.readToday)
        #expect(s.currentStreak == 2)
    }

    @Test func streakBreaksAfterMissedDay() {
        let s = stats(["2026-10-18": 1, "2026-10-17": 1, "2026-10-16": 1])
        #expect(s.currentStreak == 0)
        #expect(s.longestStreak == 3)
    }

    @Test func longestStreakAcrossMonths() {
        let s = stats(["2026-09-29": 1, "2026-09-30": 1, "2026-10-01": 1, "2026-10-02": 1, "2026-10-10": 1])
        #expect(s.longestStreak == 4)
    }

    @Test func levelsGrowWithChapters() {
        #expect([0, 1, 2, 3, 4, 6, 7, 20].map(ReadingStats.level(for:)) == [0, 1, 2, 2, 3, 3, 4, 4])
    }

    @Test func heatmapEndsOnCurrentWeek() {
        let s = stats(["2026-10-20": 3])
        let weeks = s.heatmap(weeks: 53)
        #expect(weeks.count == 53)
        #expect(weeks.allSatisfy { $0.count == 7 })
        let last = weeks.last!
        #expect(calendar.component(.weekday, from: last[0].date) == 1)
        let todayCell = last.first { $0.isToday }!
        #expect(todayCell.key == "2026-10-20")
        #expect(todayCell.level == 2)
        #expect(last.filter(\.isFuture).count == 4) // quarta a sábado
    }
}
