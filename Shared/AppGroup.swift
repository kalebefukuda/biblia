import Foundation

/// Local compartilhado entre o app e o widget.
///
/// Com Apple ID gratuito o App Group pode não estar disponível; nesse caso
/// tudo cai para o Application Support do próprio app e só o widget perde dados.
enum AppGroup {
    static let id = "group.com.kalebefukuda.biblia"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    /// Onde o app guarda tudo quando não há App Group.
    static var legacyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    static var defaults: UserDefaults {
        isAvailable ? (UserDefaults(suiteName: id) ?? .standard) : .standard
    }
}
