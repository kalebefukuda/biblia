import SwiftData
import SwiftUI

struct ProgressScreen: View {
    @Environment(AppState.self) private var app
    @Query private var entries: [ReadingEntry]
    @State private var selected: HeatDay?

    private var stats: ReadingStats {
        ReadingStats(counts: entries.reduce(into: [:]) { $0[$1.dayKey, default: 0] += 1 })
    }

    private var coverage: Double {
        Double(Set(entries.map(\.chapterRef)).count) / Double(Canon.totalChapters)
    }

    var body: some View {
        let stats = stats
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    streakCard(stats)
                    heatmapCard(stats)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(value: "\(stats.longestStreak)", label: "Maior sequência", icon: "trophy")
                        StatTile(value: "\(stats.daysRead)", label: "Dias com leitura", icon: "calendar")
                        StatTile(value: "\(stats.totalChapters)", label: "Capítulos lidos", icon: "book")
                        StatTile(value: coverage.formatted(.percent.precision(.fractionLength(coverage < 0.1 ? 1 : 0))), label: "Da Bíblia lida", icon: "chart.pie")
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progresso")
        }
    }

    private func streakCard(_ stats: ReadingStats) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(stats.currentStreak > 0 ? .orange : .secondary)
                }
                Text(stats.currentStreak == 1 ? "dia seguido" : "dias seguidos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                if stats.readToday {
                    Label("Leu hoje", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("Ainda não leu hoje")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Ler agora") { app.tab = .ler }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func heatmapCard(_ stats: ReadingStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Últimos 12 meses")
                .font(.headline)
            HeatmapView(weeks: stats.heatmap(weeks: 53), selected: $selected)
            HStack {
                if let selected {
                    Text(dayDetail(selected))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Toque num dia para ver o que leu")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                HeatmapLegend()
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dayDetail(_ day: HeatDay) -> String {
        let date = day.date.formatted(.dateTime.day().month(.abbreviated))
        let chapters = entries.filter { $0.dayKey == day.key }.map(\.chapterRef).sorted().map(\.title)
        return chapters.isEmpty ? "\(date): sem leitura" : "\(date): \(chapters.joined(separator: ", "))"
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
