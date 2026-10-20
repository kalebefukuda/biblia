import SwiftData
import SwiftUI

/// Um capítulo: rola na vertical; o leitor passa de capítulo deslizando para o lado.
struct ChapterPage: View {
    let ref: ChapterRef
    let verses: [String]
    let fontSize: Double
    let theme: ReaderTheme
    @Binding var selection: Set<VerseRef>

    @Environment(AppState.self) private var app
    @Query private var marks: [VerseMark]
    @State private var flashVerse: Int?

    init(ref: ChapterRef, verses: [String], fontSize: Double, theme: ReaderTheme, selection: Binding<Set<VerseRef>>) {
        self.ref = ref
        self.verses = verses
        self.fontSize = fontSize
        self.theme = theme
        _selection = selection
        let book = ref.book, chapter = ref.chapter
        _marks = Query(filter: #Predicate<VerseMark> { $0.book == book && $0.chapter == chapter })
    }

    var body: some View {
        let marksByVerse = Dictionary(marks.map { ($0.verse, $0) }, uniquingKeysWith: { a, _ in a })
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ForEach(Array(verses.enumerated()), id: \.offset) { offset, verse in
                        let number = offset + 1
                        let verseRef = VerseRef(book: ref.book, chapter: ref.chapter, verse: number)
                        VerseRow(
                            number: number,
                            text: verse,
                            mark: marksByVerse[number],
                            isSelected: selection.contains(verseRef),
                            isFlashing: flashVerse == number,
                            fontSize: fontSize,
                            theme: theme
                        )
                        .id(number)
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.2)) {
                                if selection.contains(verseRef) {
                                    selection.remove(verseRef)
                                } else {
                                    selection.insert(verseRef)
                                }
                            }
                        }
                    }
                    ChapterFooter(ref: ref, theme: theme)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .task(id: app.pendingVerse) {
                guard let target = app.pendingVerse, target.chapterRef == ref else { return }
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation { proxy.scrollTo(target.verse, anchor: .top) }
                flashVerse = target.verse
                app.pendingVerse = nil
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.6)) { flashVerse = nil }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ref.bookInfo.name.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(theme.secondary)
            Text("\(ref.chapter)")
                .font(.system(size: 54, weight: .light, design: .serif))
                .foregroundStyle(theme.text)
        }
        .padding(.top, 18)
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ref.title)
    }
}

struct VerseRow: View {
    let number: Int
    let text: String
    let mark: VerseMark?
    let isSelected: Bool
    let isFlashing: Bool
    let fontSize: Double
    let theme: ReaderTheme

    var body: some View {
        content
            .lineSpacing(fontSize * 0.38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, -6)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Toque para marcar este versículo")
    }

    private var content: Text {
        let numberText = Text("\(number) ")
            .font(.system(size: fontSize * 0.62, weight: .semibold))
            .foregroundColor(.accentColor)
            .baselineOffset(fontSize * 0.32)

        var body = Text(text)
            .font(.system(size: fontSize, design: .serif))
            .foregroundColor(theme.text)
        if isSelected {
            body = body.underline(true, pattern: .dot, color: .accentColor)
        } else if let mark, mark.underline {
            body = body.underline(true, color: mark.color?.color ?? .accentColor)
        }

        var result = numberText + body
        if let mark {
            if mark.saved {
                result = result + Text(" ") + Text(Image(systemName: "bookmark.fill")).font(.system(size: fontSize * 0.6)).foregroundColor(.accentColor)
            }
            if mark.hasNote {
                result = result + Text(" ") + Text(Image(systemName: "note.text")).font(.system(size: fontSize * 0.6)).foregroundColor(.accentColor)
            }
        }
        return result
    }

    private var background: Color {
        if isFlashing { return Color.accentColor.opacity(0.18) }
        if let color = mark?.color, !(mark?.underline ?? false) { return color.color.opacity(0.32) }
        if isSelected { return Color.accentColor.opacity(0.06) }
        return .clear
    }
}

/// Fim do capítulo: marcar como lido (alimenta o mapa e a sequência).
struct ChapterFooter: View {
    let ref: ChapterRef
    let theme: ReaderTheme

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var entries: [ReadingEntry]

    init(ref: ChapterRef, theme: ReaderTheme) {
        self.ref = ref
        self.theme = theme
        let book = ref.book, chapter = ref.chapter
        _entries = Query(filter: #Predicate<ReadingEntry> { $0.book == book && $0.chapter == chapter })
    }

    private var readToday: Bool {
        let today = DayKey.from(.now)
        return entries.contains { $0.dayKey == today }
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                let store = BibleStore(context: context)
                if readToday {
                    store.unmarkRead(ref)
                } else {
                    store.markRead([ref])
                }
                app.onReadingChanged?(store)
            } label: {
                Label(readToday ? "Lido hoje" : "Marcar como lido", systemImage: readToday ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(readToday ? Color.accentColor.opacity(0.85) : .accentColor)
            .sensoryFeedback(.success, trigger: readToday) { _, new in new }

            if !readToday, let last = entries.map(\.readAt).max() {
                Text("Última leitura em \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(theme.secondary)
            }
            if ref.globalIndex < Canon.totalChapters - 1 {
                Text("Deslize para o lado para ir a \(Canon.chapter(atGlobalIndex: ref.globalIndex + 1).title)")
                    .font(.footnote)
                    .foregroundStyle(theme.secondary)
            }
        }
        .padding(.top, 32)
    }
}
