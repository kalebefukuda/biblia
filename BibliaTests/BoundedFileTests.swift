import Foundation
import SwiftData
import Testing
@testable import Biblia

struct BoundedFileTests {
    private func tempFile(size: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(size)) // arquivo esparso: rápido mesmo grande
        try handle.close()
        return url
    }

    @Test func refusesOversizedFileBeforeReading() throws {
        let url = try tempFile(size: 30 * 1_048_576)
        #expect(throws: BoundedFile.ReadError.tooLarge(bytes: 30 * 1_048_576)) {
            try BoundedFile.read(url, maxBytes: 20 * 1_048_576)
        }
    }

    @Test func unknownSizeIsAnError() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nao-existe-\(UUID().uuidString).json")
        #expect(throws: BoundedFile.ReadError.unknownSize) { try BoundedFile.read(missing, maxBytes: 10) }
    }

    @Test @MainActor func backupReadMapsSizeErrors() throws {
        let url = try tempFile(size: BackupService.maxSize + 1)
        #expect(throws: BackupError.tooLarge) { try BackupService.read(from: url) }
    }
}
