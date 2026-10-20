import SwiftUI

/// Mapa estilo GitHub: cada quadrado é um dia; quanto mais capítulos, mais forte a cor.
struct HeatmapView: View {
    let weeks: [[HeatDay]]
    var cell: CGFloat = 13
    var spacing: CGFloat = 3.5
    @Binding var selected: HeatDay?

    private static let weekdayLabels = ["D", "S", "T", "Q", "Q", "S", "S"]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: spacing) {
                Color.clear.frame(width: 10, height: 14)
                ForEach(0..<7, id: \.self) { row in
                    Text(row % 2 == 1 ? Self.weekdayLabels[row] : "")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: cell)
                }
            }
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: spacing) {
                    monthLabels
                    HStack(spacing: spacing) {
                        ForEach(weeks.indices, id: \.self) { column in
                            VStack(spacing: spacing) {
                                ForEach(weeks[column], id: \.key) { day in
                                    square(day)
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 2)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.trailing)
        }
    }

    private var monthLabels: some View {
        HStack(spacing: spacing) {
            ForEach(weeks.indices, id: \.self) { column in
                let first = weeks[column].first
                let showsMonth = first.map { Calendar.current.component(.day, from: $0.date) <= 7 } ?? false
                Text(showsMonth ? first!.date.formatted(.dateTime.month(.abbreviated)) : "")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(width: cell, height: 14, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func square(_ day: HeatDay) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(day.isFuture ? Color.clear : Self.color(for: day.level))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.2)
                } else if selected?.key == day.key {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !day.isFuture else { return }
                selected = selected?.key == day.key ? nil : day
            }
            .accessibilityLabel("\(day.date.formatted(date: .long, time: .omitted)): \(day.count) capítulos")
    }

    static func color(for level: Int) -> Color {
        switch level {
        case 0: Color(.systemGray5)
        case 1: Color.accentColor.opacity(0.38)
        case 2: Color.accentColor.opacity(0.58)
        case 3: Color.accentColor.opacity(0.8)
        default: Color.accentColor
        }
    }
}

struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Menos")
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2.5).fill(HeatmapView.color(for: level)).frame(width: 11, height: 11)
            }
            Text("Mais")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
