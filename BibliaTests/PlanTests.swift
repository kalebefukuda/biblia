import Foundation
import Testing
@testable import Biblia

struct PlanTests {
    @Test func oneYearPlanCoversWholeBibleOnce() throws {
        let plan = try #require(PlanGenerator.plan("biblia-1-ano"))
        #expect(plan.days.count == 365)
        let flat = plan.days.flatMap { $0 }
        #expect(flat == Canon.allChapters)
        #expect(Set(flat).count == 1189)
        let sizes = Set(plan.days.map(\.count))
        #expect(sizes == [3, 4])
    }

    @Test func otherPlansHaveExpectedShape() throws {
        #expect(try #require(PlanGenerator.plan("nt-90-dias")).chapterCount == 260)
        #expect(try #require(PlanGenerator.plan("nt-90-dias")).days.count == 90)
        #expect(try #require(PlanGenerator.plan("salmos-30-dias")).days.allSatisfy { $0.count == 5 })
        #expect(try #require(PlanGenerator.plan("proverbios-31-dias")).days.allSatisfy { $0.count == 1 })
        #expect(try #require(PlanGenerator.plan("evangelhos-30-dias")).chapterCount == 89)
    }

    @Test func progressComesFromReadings() throws {
        let plan = try #require(PlanGenerator.plan("salmos-30-dias"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 8))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 8))!

        let read = Set(plan.days[0] + plan.days[1] + plan.days[2].prefix(2))
        let progress = PlanProgress(plan: plan, startedAt: start, readSinceStart: read, calendar: calendar, now: now)
        #expect(progress.completedDays == 2)
        #expect(progress.currentDay == 2)
        #expect(progress.expectedDays == 5)
        #expect(progress.daysBehind == 2)

        let firstDay = PlanProgress(plan: plan, startedAt: start, readSinceStart: [], calendar: calendar, now: start)
        #expect(firstDay.daysBehind == 0)
        #expect(!progress.isFinished)

        let all = PlanProgress(plan: plan, startedAt: start, readSinceStart: Set(plan.days.flatMap { $0 }), calendar: calendar, now: now)
        #expect(all.isFinished && all.currentDay == nil)
    }

    @Test func describesChapterRanges() {
        let refs = [ChapterRef(book: 40, chapter: 28), ChapterRef(book: 41, chapter: 1), ChapterRef(book: 41, chapter: 2)]
        #expect(PlanGenerator.describe(refs) == "Mateus 28; Marcos 1–2")
        #expect(PlanGenerator.describe([ChapterRef(book: 1, chapter: 1)]) == "Gênesis 1")
    }
}
