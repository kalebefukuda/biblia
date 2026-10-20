import Foundation

/// Lê arquivos escolhidos pelo usuário só depois de conferir o tamanho, para um
/// arquivo enorme escolhido por engano não ser carregado inteiro na memória.
enum BoundedFile {
    enum ReadError: Error, Equatable {
        case tooLarge(bytes: Int)
        case unknownSize
    }

    static func read(_ url: URL, maxBytes: Int) throws -> Data {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw ReadError.unknownSize
        }
        guard size <= maxBytes else { throw ReadError.tooLarge(bytes: size) }
        return try Data(contentsOf: url)
    }
}
