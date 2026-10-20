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

    private var stats: ReadingStats { ReadingStats(counts: snapshot.counts, today: date) }

    var body: some View {
        let stats = stats
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(stats.currentStreak > 0 ? .orange : .secondary)
                    Spacer(minLength: 0)
                    Image(systemName: stats.readToday ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundStyle(stats.readToday ? Color.brand : .secondary)
                        .accessibilityLabel(stats.readToday ? "Leu hoje" : "Ainda não leu hoje")
                }
                Text(stats.currentStreak == 1 ? "dia seguido" : "dias seguidos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                MiniHeatmap(weeks: stats.heatmap(weeks: 9), cell: 9.5, spacing: 2.5)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(stats.currentStreak)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Image(systemName: "flame.fill")
                            .foregroundStyle(stats.currentStreak > 0 ? .orange : .secondary)
                    }
                    Text(stats.currentStreak == 1 ? "dia seguido" : "dias seguidos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    status(stats)
                }
                Spacer(minLength: 0)
                MiniHeatmap(weeks: stats.heatmap(weeks: 15), cell: 11.5, spacing: 3)
            }
        }
    }

    private func status(_ stats: ReadingStats) -> some View {
        Label(stats.readToday ? "Leu hoje" : "Ler hoje", systemImage: stats.readToday ? "checkmark.circle.fill" : "circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(stats.readToday ? Color.brand : .secondary)
    }
}

struct MiniHeatmap: View {
    let weeks: [[HeatDay]]
    let cell: CGFloat
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(weeks.indices, id: \.self) { column in
                VStack(spacing: spacing) {
                    ForEach(weeks[column], id: \.key) { day in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(day.isFuture ? Color.clear : Self.color(for: day.level))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }

    static func color(for level: Int) -> Color {
        switch level {
        case 0: Color.primary.opacity(0.09)
        case 1: Color.brand.opacity(0.38)
        case 2: Color.brand.opacity(0.58)
        case 3: Color.brand.opacity(0.8)
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
