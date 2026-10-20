import SwiftData
import SwiftUI

@main
struct BibliaApp: App {
    @State private var app = AppState()
    private let container: ModelContainer

    init() {
        do {
            container = try Persistence.makeContainer()
        } catch {
            // Sem armazenamento local não há como guardar marcações; melhor falhar cedo e visível.
            fatalError("Não foi possível abrir o armazenamento: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .modelContainer(container)
    }
}
