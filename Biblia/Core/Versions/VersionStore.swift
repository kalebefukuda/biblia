import Foundation
import Observation

/// Versões instaladas no aparelho e cache das que já foram carregadas.
@MainActor
@Observable
final class VersionStore {
    private(set) var installed: [VersionInfo] = []
    /// Mensagens da última importação automática (pasta Documentos do app).
    private(set) var inboxMessages: [String] = []

    @ObservationIgnored private var cache: [String: BibleText] = [:]
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let inbox: URL

    init(directory: URL? = nil, inbox: URL? = nil) {
        self.directory = directory ?? AppGroup.containerURL.appendingPathComponent("Versoes", isDirectory: true)
        self.inbox = inbox ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        refresh()
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        installed = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { url in
                let id = VersionInfo.id(fromFileName: url.lastPathComponent)
                return VersionInfo(id: id, name: VersionInfo.displayName(for: id), fileURL: url)
            }
            .sorted { $0.id < $1.id }
    }

    /// Valida e copia um arquivo escolhido pelo usuário (Arquivos, AirDrop, iCloud Drive).
    @discardableResult
    func install(from url: URL) throws -> VersionInfo {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let id = VersionInfo.id(fromFileName: url.lastPathComponent)
        guard !id.isEmpty else { throw VersionImportError.invalidName }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > VersionImporter.maxFileSize {
            throw VersionImportError.tooLarge(bytes: size)
        }
        let data = try Data(contentsOf: url)
        let text = try VersionImporter.parse(data: data, id: id)

        let destination = directory.appendingPathComponent("\(id).json")
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache[id] = text
        refresh()
        return VersionInfo(id: id, name: text.name, fileURL: destination)
    }

    /// Importa JSONs deixados na pasta Documentos do app (via Finder ou app Arquivos).
    func importInbox() {
        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        var messages: [String] = []
        for file in files where file.pathExtension.lowercased() == "json" {
            do {
                let info = try install(from: file)
                try? FileManager.default.removeItem(at: file)
                messages.append("\(info.id) importada.")
            } catch {
                messages.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !messages.isEmpty { inboxMessages = messages }
    }

    func remove(_ id: String) {
        guard let info = installed.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: info.fileURL)
        cache[id] = nil
        refresh()
    }

    func load(_ id: String) async throws -> BibleText {
        if let cached = cache[id] { return cached }
        guard let info = installed.first(where: { $0.id == id }) else { throw VersionImportError.invalidName }
        let url = info.fileURL
        let text = try await Task.detached(priority: .userInitiated) {
            try VersionImporter.parse(data: Data(contentsOf: url), id: id)
        }.value
        cache[id] = text
        return text
    }
}
