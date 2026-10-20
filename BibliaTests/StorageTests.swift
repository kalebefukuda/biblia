import Foundation
import Testing
@testable import Biblia

struct StorageTests {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func migratesDataWhenAppGroupAppears() throws {
        let legacy = try tempDir(), group = try tempDir()
        try Data("banco".utf8).write(to: legacy.appendingPathComponent("Biblia.store"))
        try Data("wal".utf8).write(to: legacy.appendingPathComponent("Biblia.store-wal"))
        try FileManager.default.createDirectory(at: legacy.appendingPathComponent("Versoes"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: legacy.appendingPathComponent("Versoes/ARA.json"))
        // O app pode já ter criado a pasta vazia no grupo.
        try FileManager.default.createDirectory(at: group.appendingPathComponent("Versoes"), withIntermediateDirectories: true)

        #expect(try StorageMaintenance.migrateIfNeeded(from: legacy, to: group))
        #expect(try String(contentsOf: group.appendingPathComponent("Biblia.store"), encoding: .utf8) == "banco")
        #expect(FileManager.default.fileExists(atPath: group.appendingPathComponent("Biblia.store-wal").path))
        #expect(FileManager.default.fileExists(atPath: group.appendingPathComponent("Versoes/ARA.json").path))
        #expect(!FileManager.default.fileExists(atPath: legacy.appendingPathComponent("Biblia.store").path))
    }

    @Test func migrationNeverOverwritesExistingGroupData() throws {
        let legacy = try tempDir(), group = try tempDir()
        try Data("antigo".utf8).write(to: legacy.appendingPathComponent("Biblia.store"))
        try Data("atual".utf8).write(to: group.appendingPathComponent("Biblia.store"))

        #expect(try !StorageMaintenance.migrateIfNeeded(from: legacy, to: group))
        #expect(try String(contentsOf: group.appendingPathComponent("Biblia.store"), encoding: .utf8) == "atual")
        #expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("Biblia.store").path))
    }

    @Test func migratesOnlyMissingPreferences() {
        let source = UserDefaults(suiteName: UUID().uuidString)!
        let destination = UserDefaults(suiteName: UUID().uuidString)!
        source.set(43, forKey: "posicaoLivro")
        source.set("NVI", forKey: "versaoAtual")
        destination.set("ARA", forKey: "versaoAtual")

        StorageMaintenance.migrateDefaults(from: source, to: destination)
        #expect(destination.integer(forKey: "posicaoLivro") == 43)
        #expect(destination.string(forKey: "versaoAtual") == "ARA")
    }

    @Test func quarantineRenamesWithoutDeleting() throws {
        let dir = try tempDir()
        for name in ["Biblia.store", "Biblia.store-shm", "Biblia.store-wal"] {
            try Data(name.utf8).write(to: dir.appendingPathComponent(name))
        }
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .current, year: 2026, month: 10, day: 20, hour: 19, minute: 15))!
        let moved = try StorageMaintenance.quarantineStore(in: dir, now: now)

        #expect(moved.count == 3)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Biblia.store").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Biblia.store.ilegivel-20261020-191500").path))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Biblia.store.ilegivel-20261020-191500-wal").path))
    }
}
