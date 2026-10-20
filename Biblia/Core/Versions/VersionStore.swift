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
    @ObservationIgnored private let defaults: UserDefaults

    nonisolated static let ignoredInboxKey = "inboxIgnorados"

    init(directory: URL? = nil, inbox: URL? = nil, defaults: UserDefaults = AppGroup.defaults) {
        self.directory = directory ?? AppGroup.containerURL.appendingPathComponent("Versoes", isDirectory: true)
        self.inbox = inbox ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.defaults = defaults
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
        let data: Data
        do {
            data = try BoundedFile.read(url, maxBytes: VersionImporter.maxFileSize)
        } catch BoundedFile.ReadError.tooLarge(let bytes) {
            throw VersionImportError.tooLarge(bytes: bytes)
        } catch BoundedFile.ReadError.unknownSize {
            throw VersionImportError.unreadable
        }
        let text = try VersionImporter.parse(data: data, id: id)

        let destination = directory.appendingPathComponent("\(id).json")
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache[id] = text
        refresh()
        return VersionInfo(id: id, name: text.name, fileURL: destination)
    }

    /// Importa JSONs deixados na pasta Documentos do app (via Finder ou app Arquivos).
    /// Cópias de segurança salvas ali são ignoradas, e um arquivo que já falhou só
    /// é tentado de novo se mudar (nome, tamanho ou data), para o erro não voltar a cada abertura.
    func importInbox() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: keys)) ?? []
        var ignored = Set(defaults.stringArray(forKey: Self.ignoredInboxKey) ?? [])
        var messages: [String] = []
        for file in files where file.pathExtension.lowercased() == "json" && !Self.isBackup(file) {
            let signature = Self.signature(of: file)
            guard !ignored.contains(signature) else { continue }
            do {
                let info = try install(from: file)
                try? FileManager.default.removeItem(at: file)
                messages.append("\(info.id) importada.")
            } catch {
                ignored.insert(signature)
                messages.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        defaults.set(Array(ignored), forKey: Self.ignoredInboxKey)
        if !messages.isEmpty { inboxMessages = messages }
    }

    /// Cópia de segurança do próprio app (nome padrão ou conteúdo com "formatVersion" no início).
    static func isBackup(_ file: URL) -> Bool {
        if file.lastPathComponent.lowercased().hasPrefix("biblia-backup") { return true }
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 256)) ?? Data()
        return String(decoding: head, as: UTF8.self).contains("\"formatVersion\"")
    }

    private static func signature(of file: URL) -> String {
        let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = values?.fileSize ?? -1
        let modified = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        return "\(file.lastPathComponent)|\(size)|\(modified)"
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
