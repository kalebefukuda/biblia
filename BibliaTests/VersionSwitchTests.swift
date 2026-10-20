import Foundation
import Testing
@testable import Biblia

@MainActor
struct VersionSwitchTests {
    /// Trocar de versão enquanto outra ainda carrega não pode deixar o leitor na versão errada.
    @Test func slowLoadDoesNotOverrideNewerChoice() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dir = root.appendingPathComponent("Versoes")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try TestSupport.formatA(TestSupport.syntheticBooks(versesPerChapter: 30)).write(to: dir.appendingPathComponent("LENTA.json"))
        try TestSupport.formatA(TestSupport.syntheticBooks(versesPerChapter: 1)).write(to: dir.appendingPathComponent("RAPIDA.json"))

        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let versions = VersionStore(directory: dir, inbox: root.appendingPathComponent("vazio"), defaults: defaults)
        _ = try await versions.load("RAPIDA") // já em cache: carrega sem esperar
        let app = AppState(versions: versions, defaults: defaults)

        let slow = Task { await app.selectVersion("LENTA") }
        for _ in 0..<5 { await Task.yield() }
        await app.selectVersion("RAPIDA")
        await slow.value

        #expect(app.currentVersionID == "RAPIDA")
        #expect(app.text?.id == "RAPIDA")
    }
}
