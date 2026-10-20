import Foundation

/// Mudanças no local dos dados do app, sempre sem apagar nada do usuário.
enum StorageMaintenance {
    /// Itens que o app guarda no container (banco, versões importadas e resumo do widget).
    static let items = Persistence.storeFiles + ["Versoes", WidgetSnapshot.fileName]

    /// Preferências que acompanham os dados.
    static let defaultsKeys = [
        AppState.Keys.book, AppState.Keys.chapter, AppState.Keys.version,
        ReaderDefaults.fontSizeKey, ReaderDefaults.themeKey,
        ReminderSettings.enabledKey, ReminderSettings.hourKey, ReminderSettings.minuteKey,
        VersionStore.ignoredInboxKey,
    ]

    /// Instalado sem App Group (Apple ID gratuito), o app guarda tudo no próprio
    /// Application Support. Se depois o App Group passar a existir, leva os dados
    /// para o container do grupo, em vez de abrir um banco vazio lá.
    /// Não sobrescreve nada que já exista no destino.
    @discardableResult
    static func migrateIfNeeded(from legacy: URL, to group: URL, fileManager: FileManager = .default) throws -> Bool {
        let legacyStore = legacy.appendingPathComponent(Persistence.storeName)
        let groupStore = group.appendingPathComponent(Persistence.storeName)
        guard legacy.standardizedFileURL != group.standardizedFileURL,
              fileManager.fileExists(atPath: legacyStore.path),
              !fileManager.fileExists(atPath: groupStore.path)
        else { return false }

        try fileManager.createDirectory(at: group, withIntermediateDirectories: true)
        for item in items {
            let source = legacy.appendingPathComponent(item)
            let destination = group.appendingPathComponent(item)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            if fileManager.fileExists(atPath: destination.path) {
                try mergeDirectory(source, into: destination, fileManager: fileManager)
            } else {
                try fileManager.moveItem(at: source, to: destination)
            }
        }
        return true
    }

    private static func mergeDirectory(_ source: URL, into destination: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        for child in try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            let target = destination.appendingPathComponent(child.lastPathComponent)
            if !fileManager.fileExists(atPath: target.path) {
                try fileManager.moveItem(at: child, to: target)
            }
        }
    }

    static func migrateDefaults(from source: UserDefaults, to destination: UserDefaults) {
        guard source !== destination else { return }
        for key in defaultsKeys where destination.object(forKey: key) == nil {
            if let value = source.object(forKey: key) { destination.set(value, forKey: key) }
        }
    }

    /// Quando o banco não abre, renomeia os arquivos (ex.: "Biblia.store.ilegivel-20261020-1915")
    /// para o app começar um banco novo no próximo início. Nada é apagado.
    @discardableResult
    static func quarantineStore(in directory: URL, now: Date = .now, fileManager: FileManager = .default) throws -> [URL] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: now)
        var moved: [URL] = []
        for name in Persistence.storeFiles {
            let file = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: file.path) else { continue }
            let target = directory.appendingPathComponent(name.replacingOccurrences(of: Persistence.storeName, with: "\(Persistence.storeName).ilegivel-\(stamp)"))
            try fileManager.moveItem(at: file, to: target)
            moved.append(target)
        }
        return moved
    }
}
