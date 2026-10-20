import Foundation
import Observation
import SwiftData

/// Estado compartilhado entre as abas: versão atual, posição de leitura e navegação.
@MainActor
@Observable
final class AppState {
    let versions: VersionStore
    var tab: AppTab = .ler
    private(set) var text: BibleText?
    private(set) var loadError: String?
    /// Índice de busca da versão atual (montado em segundo plano).
    private(set) var searchIndex: SearchIndex?

    /// Capítulo aberto no leitor.
    var position: ChapterRef {
        didSet {
            defaults.set(position.book, forKey: Keys.book)
            defaults.set(position.chapter, forKey: Keys.chapter)
        }
    }

    /// Versículo para rolar e piscar quando o leitor abrir o capítulo.
    var pendingVerse: VerseRef?

    var currentVersionID: String? {
        didSet { defaults.set(currentVersionID, forKey: Keys.version) }
    }

    /// Chamado sempre que leituras mudam (lembretes e widget se atualizam por aqui).
    @ObservationIgnored var onReadingChanged: ((BibleStore) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let book = "posicaoLivro"
        static let chapter = "posicaoCapitulo"
        static let version = "versaoAtual"
    }

    init(versions: VersionStore? = nil, defaults: UserDefaults = AppGroup.defaults) {
        self.versions = versions ?? VersionStore()
        self.defaults = defaults
        let book = defaults.integer(forKey: Keys.book)
        let chapter = defaults.integer(forKey: Keys.chapter)
        let saved = ChapterRef(book: book, chapter: chapter)
        position = Canon.isValid(saved) ? saved : ChapterRef(book: 43, chapter: 1)
        currentVersionID = defaults.string(forKey: Keys.version)
    }

    func open(_ ref: ChapterRef, verse: Int? = nil) {
        position = ref
        pendingVerse = verse.map { VerseRef(book: ref.book, chapter: ref.chapter, verse: $0) }
        tab = .ler
    }

    func open(_ ref: VerseRef) {
        open(ref.chapterRef, verse: ref.verse)
    }

    /// Importa o que estiver na pasta Documentos e garante uma versão carregada.
    func refreshVersions() async {
        versions.importInbox()
        let ids = versions.installed.map(\.id)
        if currentVersionID == nil || !ids.contains(currentVersionID!) {
            currentVersionID = ids.first(where: { $0 == "ARA" }) ?? ids.first
        }
        await loadCurrentVersion()
    }

    func selectVersion(_ id: String) async {
        currentVersionID = id
        await loadCurrentVersion()
    }

    func loadCurrentVersion() async {
        guard let id = currentVersionID else {
            text = nil
            return
        }
        if text?.id == id { return }
        do {
            let loaded = try await versions.load(id)
            text = loaded
            loadError = nil
            searchIndex = nil
            searchIndex = await Task.detached(priority: .utility) { SearchIndex(text: loaded) }.value
        } catch {
            text = nil
            loadError = error.localizedDescription
        }
    }

    func install(from url: URL) async throws {
        let info = try versions.install(from: url)
        if currentVersionID == nil || text == nil {
            await selectVersion(info.id)
        }
    }

    func removeVersion(_ id: String) async {
        versions.remove(id)
        if currentVersionID == id {
            currentVersionID = nil
            text = nil
        }
        await refreshVersions()
    }
}
