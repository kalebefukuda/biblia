import SwiftUI
import UIKit
import WidgetKit

extension Color {
    /// Verde do app com variante escura. Explícito porque fora do app (widget,
    /// renderização em teste) o accentColor nem sempre é o do catálogo.
    static let brand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.337, green: 0.733, blue: 0.478, alpha: 1)
            : UIColor(red: 0.157, green: 0.420, blue: 0.290, alpha: 1)
    })
}

/// Visual dos widgets. Fica em Shared para poder ser renderizado nos testes.
struct StreakWidgetView: View {
    let snapshot: WidgetSnapshot
    let date: Date
    let family: WidgetFamily

    var body: some View {
        let stats = ReadingStats(counts: snapshot.counts, today: date)
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        StreakNumber(stats: stats, size: 34)
                        Spacer(minLength: 0)
                        TodayMark(readToday: stats.readToday)
                    }
                    FillingHeatmap(stats: stats, spacing: 2.5)
                }
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        StreakNumber(stats: stats, size: 40)
                        Spacer(minLength: 8)
                        TodayLabel(readToday: stats.readToday)
                        Text("Recorde: \(stats.longestStreak) \(stats.longestStreak == 1 ? "dia" : "dias")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 3)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    FillingHeatmap(stats: stats, spacing: 3)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sequência de \(stats.currentStreak) \(stats.currentStreak == 1 ? "dia" : "dias"). \(stats.readToday ? "Leu hoje." : "Ainda não leu hoje.")")
    }
}

/// Rótulo pequeno em caixa alta e o número da sequência em destaque.
private struct StreakNumber: View {
    let stats: ReadingStats
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("SEQUÊNCIA")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(stats.currentStreak)")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .tracking(-size * 0.035)
                    .minimumScaleFactor(0.6)
                Text(stats.currentStreak == 1 ? "dia" : "dias")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TodayMark: View {
    let readToday: Bool

    var body: some View {
        Image(systemName: readToday ? "checkmark.circle.fill" : "circle.dashed")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(readToday ? Color.brand : .secondary)
            .widgetAccentable()
    }
}

private struct TodayLabel: View {
    let readToday: Bool

    var body: some View {
        Label(readToday ? "Leu hoje" : "Ler hoje", systemImage: readToday ? "checkmark.circle.fill" : "circle.dashed")
            .font(.caption.weight(.semibold))
            .foregroundStyle(readToday ? Color.brand : .secondary)
            .widgetAccentable()
    }
}

/// Mapa estilo GitHub que ocupa todo o espaço disponível: a altura define o
/// tamanho do quadrado (7 dias) e a largura define quantas semanas cabem.
struct FillingHeatmap: View {
    let stats: ReadingStats
    var spacing: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let cell = max(4, (geo.size.height - spacing * 6) / 7)
            let columns = max(1, Int((geo.size.width + spacing) / (cell + spacing)))
            let columnSpacing = columns > 1 ? (geo.size.width - CGFloat(columns) * cell) / CGFloat(columns - 1) : 0
            let weeks = stats.heatmap(weeks: columns)
            HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(weeks.indices, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(weeks[column], id: \.key) { day in
                            HeatCell(day: day, size: cell)
                        }
                    }
                }
            }
        }
    }
}

private struct HeatCell: View {
    let day: HeatDay
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        Group {
            if day.isFuture {
                Color.clear
            } else if day.level > 0 {
                shape.fill(MiniHeatmap.color(for: day.level)).widgetAccentable()
            } else {
                shape.fill(MiniHeatmap.color(for: 0))
                    .overlay { if day.isToday { shape.strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1) } }
            }
        }
        .frame(width: size, height: size)
    }
}

/// Paleta do mapa (também usada pelo app).
enum MiniHeatmap {
    static func color(for level: Int) -> Color {
        switch level {
        case 0: Color.primary.opacity(0.08)
        case 1: Color.brand.opacity(0.35)
        case 2: Color.brand.opacity(0.55)
        case 3: Color.brand.opacity(0.78)
        default: Color.brand
        }
    }
}

struct VerseWidgetView: View {
    let verse: WidgetSnapshot.Verse?
    let family: WidgetFamily

    var body: some View {
        if let verse {
            VStack(alignment: .leading, spacing: 8) {
                Text("VERSÍCULO DO DIA")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.brand)
                Text(verse.text)
                    .font(.system(size: family == .systemLarge ? 20 : 15, design: .serif))
                    .minimumScaleFactor(0.7)
                    .lineLimit(family == .systemLarge ? 12 : 5)
                Spacer(minLength: 0)
                Text("\(verse.title) · \(verse.versionID)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "book")
                    .font(.title2)
                    .foregroundStyle(Color.brand)
                Text("Abra o app Bíblia para carregar o versículo do dia.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
