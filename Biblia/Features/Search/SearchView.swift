import SwiftUI

/// Busca: digite uma referência ("Jo 3:16") para ir direto, ou palavras para procurar no texto.
struct SearchView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var reference: ParsedReference? { ReferenceParser.parse(query) }

    var body: some View {
        NavigationStack {
            List {
                if let reference {
                    Section {
                        Button {
                            app.open(reference.chapterRef, verse: reference.verse)
                            dismiss()
                        } label: {
                            Label("Ir para \(reference.title)", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                        }
                    }
                }
            }
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView(
                        "Buscar na Bíblia",
                        systemImage: "magnifyingglass",
                        description: Text("Digite uma referência como “Jo 3:16” ou “Sl 23”.")
                    )
                }
            }
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Jo 3:16 ou palavras")
            .onSubmit(of: .search) {
                if let reference {
                    app.open(reference.chapterRef, verse: reference.verse)
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
