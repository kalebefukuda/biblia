import SwiftData
import SwiftUI

/// Livro → capítulo. Capítulos já lidos aparecem marcados.
struct BookPicker: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var testament: Testament = .new
    @State private var path: [BibleBook] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Picker("Testamento", selection: $testament) {
                    ForEach(Testament.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(Canon.books.filter { $0.testament == testament }) { book in
                    NavigationLink(value: book) {
                        HStack {
                            Text(book.name)
                                .fontWeight(book.id == app.position.book ? .semibold : .regular)
                            Spacer()
                            Text("\(book.chapterCount)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Livros")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BibleBook.self) { book in
                ChapterGrid(book: book) { chapter in
                    app.open(ChapterRef(book: book.id, chapter: chapter))
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear {
                testament = app.position.bookInfo.testament
            }
        }
    }
}

struct ChapterGrid: View {
    let book: BibleBook
    let onSelect: (Int) -> Void

    @Environment(AppState.self) private var app
    @Query private var entries: [ReadingEntry]

    init(book: BibleBook, onSelect: @escaping (Int) -> Void) {
        self.book = book
        self.onSelect = onSelect
        let id = book.id
        _entries = Query(filter: #Predicate<ReadingEntry> { $0.book == id })
    }

    var body: some View {
        let read = Set(entries.map(\.chapter))
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    let isCurrent = app.position == ChapterRef(book: book.id, chapter: chapter)
                    Button { onSelect(chapter) } label: {
                        Text("\(chapter)")
                            .font(.body.monospacedDigit().weight(isCurrent ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                isCurrent ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(alignment: .topTrailing) {
                                if read.contains(chapter) {
                                    Circle().fill(Color.accentColor).frame(width: 7, height: 7).padding(7)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Capítulo \(chapter)\(read.contains(chapter) ? ", lido" : "")")
                }
            }
            .padding()
        }
        .navigationTitle(book.name)
    }
}

struct VersionMenu: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Menu {
            ForEach(app.versions.installed) { version in
                Button {
                    Task { await app.selectVersion(version.id) }
                } label: {
                    if version.id == app.currentVersionID {
                        Label("\(version.id) · \(version.name)", systemImage: "checkmark")
                    } else {
                        Text("\(version.id) · \(version.name)")
                    }
                }
            }
            Divider()
            Button {
                app.tab = .ajustes
            } label: {
                Label("Gerenciar versões", systemImage: "books.vertical")
            }
        } label: {
            Text(app.currentVersionID ?? "Versão")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .accessibilityLabel("Versão atual \(app.currentVersionID ?? "nenhuma")")
    }
}
