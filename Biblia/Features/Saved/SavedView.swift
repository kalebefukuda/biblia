import SwiftData
import SwiftUI

struct SavedView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case todos = "Todos", destaques = "Destaques", salvos = "Salvos", notas = "Notas"
        var id: String { rawValue }
    }

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \VerseMark.updatedAt, order: .reverse) private var marks: [VerseMark]
    @State private var filter: Filter = .todos
    @State private var color: HighlightColor?
    @State private var confirming: VerseMark?

    private var store: BibleStore { BibleStore(context: context) }

    private var filtered: [VerseMark] {
        marks.filter { mark in
            let byKind: Bool = switch filter {
            case .todos: true
            case .destaques: mark.color != nil || mark.underline
            case .salvos: mark.saved
            case .notas: mark.hasNote
            }
            return byKind && (color == nil || mark.color == color)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filtro", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 12) {
                        ForEach(HighlightColor.allCases) { item in
                            Button {
                                color = color == item ? nil : item
                            } label: {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(color == item ? 0.7 : 0), lineWidth: 2))
                                    .opacity(color == nil || color == item ? 1 : 0.35)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Filtrar por \(item.label)")
                        }
                        Spacer()
                        if color != nil {
                            Button("Limpar") { color = nil }.font(.footnote)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Section {
                    ForEach(filtered) { mark in
                        Button { app.open(mark.ref) } label: { SavedRow(mark: mark, text: app.text) }
                            .buttonStyle(.plain)
                            .swipeActions(allowsFullSwipe: false) { swipeAction(for: mark) }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        marks.isEmpty ? "Nada salvo ainda" : "Nada neste filtro",
                        systemImage: "bookmark",
                        description: Text(marks.isEmpty ? "Toque num versículo enquanto lê para destacar, sublinhar, salvar ou anotar." : "Tente outro filtro.")
                    )
                }
            }
            .navigationTitle("Salvos")
            .confirmationDialog(
                confirming.map { "Apagar a nota de \($0.ref.title)?" } ?? "",
                isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                titleVisibility: .visible
            ) {
                if let mark = confirming {
                    Button("Apagar só a nota", role: .destructive) { store.setNote(nil, for: mark.ref) }
                    if filter == .todos {
                        Button("Apagar tudo do versículo", role: .destructive) { store.deleteMark(mark) }
                    }
                }
            } message: {
                Text("A nota não pode ser recuperada, a não ser por uma cópia de segurança.")
            }
        }
    }

    /// Cada filtro remove só o que ele mostra; apagar uma nota sempre pede confirmação.
    @ViewBuilder
    private func swipeAction(for mark: VerseMark) -> some View {
        switch filter {
        case .salvos:
            Button("Tirar dos salvos") { store.toggleSaved(for: [mark.ref]) }
                .tint(.orange)
        case .destaques:
            Button("Tirar destaque") { store.clearHighlight(for: [mark.ref]) }
                .tint(.orange)
        case .notas:
            Button("Apagar nota") { confirming = mark }
                .tint(.red)
        case .todos:
            Button("Apagar") {
                if mark.hasNote { confirming = mark } else { store.deleteMark(mark) }
            }
            .tint(.red)
        }
    }
}

private struct SavedRow: View {
    let mark: VerseMark
    let text: BibleText?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let color = mark.color {
                    Circle().fill(color.color).frame(width: 10, height: 10)
                }
                Text(mark.ref.title).font(.subheadline.weight(.semibold))
                Spacer()
                if mark.underline { Image(systemName: "underline") }
                if mark.saved { Image(systemName: "bookmark.fill") }
                if mark.hasNote { Image(systemName: "note.text") }
            }
            .font(.caption)
            .foregroundStyle(Color.accentColor)

            if let verse = text?.verse(mark.ref) {
                Text(verse)
                    .font(.system(.subheadline, design: .serif))
                    .lineLimit(3)
                    .padding(.horizontal, mark.color != nil ? 4 : 0)
                    .background(mark.color.map { $0.color.opacity(0.25) } ?? .clear, in: RoundedRectangle(cornerRadius: 4))
            }
            if let note = mark.note, mark.hasNote {
                Text(note)
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
