import SwiftData
import SwiftUI

/// Barra que aparece ao tocar em versículos: cores, sublinhado, salvar, nota, copiar e compartilhar.
struct VerseActionBar: View {
    let refs: [VerseRef]
    let text: BibleText
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var editingNote: VerseRef?
    @State private var copied = false

    private var sorted: [VerseRef] { refs.sorted { $0.verse < $1.verse } }
    private var store: BibleStore { BibleStore(context: context) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(VerseFormatting.title(for: refs))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fechar")
            }

            HStack(spacing: 0) {
                ForEach(HighlightColor.allCases) { color in
                    Button {
                        store.setColor(color, for: refs)
                        onClose()
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 34, height: 34)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Destacar em \(color.label)")
                }
                Button {
                    store.setColor(nil, for: refs)
                    onClose()
                } label: {
                    Image(systemName: "circle.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remover destaque")
            }

            HStack(spacing: 0) {
                action("Sublinhar", "underline") {
                    store.toggleUnderline(for: refs)
                    onClose()
                }
                action("Salvar", "bookmark") {
                    store.toggleSaved(for: refs)
                    onClose()
                }
                action("Nota", "note.text.badge.plus") {
                    editingNote = sorted.first
                }
                action(copied ? "Copiado" : "Copiar", copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = VerseFormatting.shareText(for: refs, in: text)
                    copied = true
                }
                ShareLink(item: VerseFormatting.shareText(for: refs, in: text)) {
                    ActionLabel(title: "Enviar", icon: "square.and.arrow.up")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: refs.count)
        .sheet(item: $editingNote) { ref in
            NoteEditor(ref: ref, onDone: onClose)
        }
    }

    private func action(_ title: String, _ icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { ActionLabel(title: title, icon: icon) }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
    }
}

private struct ActionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 19)).frame(height: 24)
            Text(title).font(.caption2)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

extension VerseRef: Identifiable {
    var id: String { key }
}

struct NoteEditor: View {
    let ref: VerseRef
    var onDone: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let verse = app.text?.verse(ref) {
                    Text(verse)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                TextEditor(text: $note)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle(ref.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        BibleStore(context: context).setNote(note, for: ref)
                        dismiss()
                        onDone()
                    }
                }
            }
            .onAppear {
                note = BibleStore(context: context).mark(for: ref)?.note ?? ""
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}
