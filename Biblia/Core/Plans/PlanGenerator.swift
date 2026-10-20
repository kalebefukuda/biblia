import Foundation

struct ReadingPlan: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let icon: String
    let days: [[ChapterRef]]

    var chapterCount: Int { days.reduce(0) { $0 + $1.count } }
}

/// Progresso de um plano, derivado das leituras registradas desde o início do plano.
/// Assim, ler o capítulo pelo leitor normal também conta para o plano.
struct PlanProgress: Sendable {
    let plan: ReadingPlan
    let startedAt: Date
    let readSinceStart: Set<ChapterRef>
    var calendar: Calendar = .current
    var now: Date = .now

    func isComplete(day index: Int) -> Bool {
        plan.days[index].allSatisfy(readSinceStart.contains)
    }

    var completedDays: Int { plan.days.indices.filter(isComplete).count }
    var isFinished: Bool { completedDays == plan.days.count }
    var fraction: Double { Double(completedDays) / Double(plan.days.count) }

    /// Primeiro dia ainda não concluído (é a "leitura de hoje").
    var currentDay: Int? { plan.days.indices.first { !isComplete(day: $0) } }

    /// Quantos dias o calendário diz que já deveriam estar concluídos.
    var expectedDays: Int {
        let start = calendar.startOfDay(for: startedAt)
        let today = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return min(plan.days.count, elapsed + 1)
    }

    /// Dias de atraso: conta só os dias que já terminaram (a leitura de hoje
    /// ainda pode ser feita). Zero ou negativo = em dia/adiantado.
    var daysBehind: Int { (expectedDays - 1) - completedDays }
}

enum PlanGenerator {
    /// Divide em blocos contíguos e equilibrados (diferença máxima de 1 capítulo por dia).
    static func split(_ chapters: [ChapterRef], days: Int) -> [[ChapterRef]] {
        guard days > 0, !chapters.isEmpty else { return [] }
        return (0..<days).map { day in
            let start = day * chapters.count / days
            let end = (day + 1) * chapters.count / days
            return Array(chapters[start..<end])
        }.filter { !$0.isEmpty }
    }

    private static func chapters(of books: ClosedRange<Int>) -> [ChapterRef] {
        Canon.allChapters.filter { books.contains($0.book) }
    }

    static let all: [ReadingPlan] = [
        ReadingPlan(
            id: "biblia-1-ano", title: "Bíblia em 1 ano", summary: "De Gênesis a Apocalipse, 3 a 4 capítulos por dia",
            icon: "book.closed", days: split(Canon.allChapters, days: 365)
        ),
        ReadingPlan(
            id: "nt-90-dias", title: "Novo Testamento em 90 dias", summary: "Cerca de 3 capítulos por dia",
            icon: "cross", days: split(chapters(of: 40...66), days: 90)
        ),
        ReadingPlan(
            id: "evangelhos-30-dias", title: "Evangelhos em 30 dias", summary: "Mateus, Marcos, Lucas e João",
            icon: "person.2", days: split(chapters(of: 40...43), days: 30)
        ),
        ReadingPlan(
            id: "salmos-30-dias", title: "Salmos em 30 dias", summary: "5 salmos por dia",
            icon: "music.note", days: split(chapters(of: 19...19), days: 30)
        ),
        ReadingPlan(
            id: "proverbios-31-dias", title: "Provérbios em 31 dias", summary: "Um capítulo por dia do mês",
            icon: "lightbulb", days: split(chapters(of: 20...20), days: 31)
        ),
    ]

    static func plan(_ id: String) -> ReadingPlan? { all.first { $0.id == id } }

    /// "Gênesis 1–3", "Mateus 28; Marcos 1–2".
    static func describe(_ chapters: [ChapterRef]) -> String {
        var groups: [(book: Int, first: Int, last: Int)] = []
        for ref in chapters {
            if let last = groups.last, last.book == ref.book, last.last + 1 == ref.chapter {
                groups[groups.count - 1].last = ref.chapter
            } else {
                groups.append((ref.book, ref.chapter, ref.chapter))
            }
        }
        return groups.map { group in
            let name = Canon.book(group.book).name
            return group.first == group.last ? "\(name) \(group.first)" : "\(name) \(group.first)–\(group.last)"
        }.joined(separator: "; ")
    }
}
