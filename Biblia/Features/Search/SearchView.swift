import SwiftUI

/// Busca: digite uma referência ("Jo 3:16") para ir direto, ou palavras para procurar no texto.
struct SearchView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searching = false
    @State private var hits: [SearchIndex.Hit] = []
    @State private var isSearching = false

    private var reference: ParsedReference? { ReferenceParser.parse(query) }

    var body: some View {
        NavigationStack {
            List {
                if let reference {
                    Section {
                        Button {
                            open(reference.chapterRef, verse: reference.verse)
                        } label: {
                            Label("Ir para \(reference.title)", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                        }
                    }
                }
                if !hits.isEmpty, let text = app.text {
                    Section(hits.count >= 300 ? "300+ versículos" : "\(hits.count) versículo\(hits.count == 1 ? "" : "s")") {
                        ForEach(hits) { hit in
                            Button {
                                open(hit.ref.chapterRef, verse: hit.ref.verse)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hit.ref.title)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                    Text(highlighted(text.verse(hit.ref) ?? ""))
                                        .font(.system(.subheadline, design: .serif))
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Buscar na Bíblia",
                        systemImage: "magnifyingglass",
                        description: Text("Digite uma referência como “Jo 3:16” ou palavras como “amor ao próximo”.")
                    )
                } else if hits.isEmpty && reference == nil && !isSearching && app.searchIndex != nil {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always), prompt: "Jo 3:16 ou palavras")
            .onSubmit(of: .search) {
                if let reference { open(reference.chapterRef, verse: reference.verse) }
            }
            .task { searching = true }
            .task(id: query) { await runSearch() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func open(_ ref: ChapterRef, verse: Int?) {
        app.open(ref, verse: verse)
        dismiss()
    }

    private func runSearch() async {
        let current = query
        guard current.count >= 2, let index = app.searchIndex else {
            hits = []
            return
        }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let found = await Task.detached(priority: .userInitiated) { index.search(current) }.value
        guard !Task.isCancelled else { return }
        hits = found
        isSearching = false
    }

    /// Destaca em negrito os termos encontrados.
    private func highlighted(_ verse: String) -> AttributedString {
        var result = AttributedString(verse)
        let folded = SearchIndex.fold(verse)
        let terms = SearchIndex.fold(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 }
        // A dobra de acentos preserva a contagem de caracteres em português, então as posições batem.
        guard folded.count == verse.count else { return result }
        for term in terms {
            var searchStart = folded.startIndex
            while let range = folded.range(of: term, options: .literal, range: searchStart..<folded.endIndex) {
                let lower = folded.distance(from: folded.startIndex, to: range.lowerBound)
                let length = folded.distance(from: range.lowerBound, to: range.upperBound)
                let start = result.index(result.startIndex, offsetByCharacters: lower)
                let end = result.index(start, offsetByCharacters: length)
                result[start..<end].inlinePresentationIntent = .stronglyEmphasized
                result[start..<end].foregroundColor = .accentColor
                searchStart = range.upperBound
            }
        }
        return result
    }
}
