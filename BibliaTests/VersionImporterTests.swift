import Foundation
import Testing
@testable import Biblia

struct VersionImporterTests {
    @Test func importsFormatA() throws {
        let text = try VersionImporter.parse(data: TestSupport.formatA(TestSupport.syntheticBooks()), id: "TESTE")
        #expect(text.books.count == 66)
        #expect(text.verses(ChapterRef(book: 43, chapter: 3)).count == 3)
        #expect(text.verse(VerseRef(book: 43, chapter: 3, verse: 2)) == "Jo 3:2 texto de exemplo")
    }

    @Test func importsFormatB() throws {
        let text = try VersionImporter.parse(data: TestSupport.formatB(TestSupport.syntheticBooks()), id: "TESTE")
        #expect(text.verseCount == 1189 * 3)
    }

    @Test func stripsBOM() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + TestSupport.formatA(TestSupport.syntheticBooks(versesPerChapter: 1))
        #expect(throws: Never.self) { try VersionImporter.parse(data: data, id: "TESTE") }
    }

    @Test func rejectsInvalidJSON() {
        #expect(throws: VersionImportError.invalidJSON) {
            try VersionImporter.parse(data: Data("não é json".utf8), id: "TESTE")
        }
    }

    @Test func rejectsUnknownShape() {
        #expect(throws: VersionImportError.unknownFormat) {
            try VersionImporter.parse(data: Data(#"{"foo": 1}"#.utf8), id: "TESTE")
        }
    }

    @Test func rejectsMissingBooks() {
        var books = TestSupport.syntheticBooks(versesPerChapter: 1)
        books.removeLast()
        #expect(throws: VersionImportError.wrongBookCount(found: 65)) {
            try VersionImporter.parse(data: TestSupport.formatA(books), id: "TESTE")
        }
    }

    @Test func rejectsWrongChapterCount() {
        var books = TestSupport.syntheticBooks(versesPerChapter: 1)
        books[0].removeLast()
        #expect(throws: VersionImportError.wrongChapterCount(book: "Gênesis", expected: 50, found: 49)) {
            try VersionImporter.parse(data: TestSupport.formatA(books), id: "TESTE")
        }
    }

    @Test func rejectsEmptyChapter() {
        var books = TestSupport.syntheticBooks(versesPerChapter: 1)
        books[42][2] = []
        #expect(throws: VersionImportError.emptyChapter(book: "João", chapter: 3)) {
            try VersionImporter.parse(data: TestSupport.formatA(books), id: "TESTE")
        }
    }

    @Test func rejectsOversizedFile() {
        let data = Data(count: VersionImporter.maxFileSize + 1)
        #expect(throws: VersionImportError.tooLarge(bytes: data.count)) {
            try VersionImporter.parse(data: data, id: "TESTE")
        }
    }

    @Test func derivesIdFromFileName() {
        #expect(VersionInfo.id(fromFileName: "ara.json") == "ARA")
        #expect(VersionInfo.id(fromFileName: "../../NVI 2000.json") == "NVI2000")
        #expect(VersionInfo.displayName(for: "ARA") == "Almeida Revista e Atualizada")
    }

    @Test func storeInstallsAndLoads() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inbox = root.appendingPathComponent("inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        try TestSupport.formatA(TestSupport.syntheticBooks()).write(to: inbox.appendingPathComponent("teste.json"))
        try Data("ruim".utf8).write(to: inbox.appendingPathComponent("ruim.json"))

        let store = await VersionStore(directory: root.appendingPathComponent("Versoes"), inbox: inbox)
        await store.importInbox()
        let ids = await store.installed.map(\.id)
        #expect(ids == ["TESTE"])
        #expect(await store.inboxMessages.count == 2)
        let text = try await store.load("TESTE")
        #expect(text.books.count == 66)
    }

    /// Só roda de verdade se você colocou arquivos em Versoes/ (fora do git).
    @Test func importsLocalVersionsIfPresent() throws {
        let files = (try? FileManager.default.contentsOfDirectory(at: TestSupport.localVersionsFolder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            let text = try VersionImporter.parse(data: Data(contentsOf: file), id: VersionInfo.id(fromFileName: file.lastPathComponent))
            #expect(text.books.count == 66)
            #expect(text.verseCount > 31_000)
        }
    }
}
