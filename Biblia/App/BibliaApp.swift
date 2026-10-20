import SwiftData
import SwiftUI

@main
struct BibliaApp: App {
    @State private var app = AppState()
    private let container: ModelContainer
    private let storageFailed: Bool

    init() {
        do {
            container = try Persistence.makeContainer()
            storageFailed = false
        } catch {
            // Nunca apagar dados automaticamente: abre em memória e avisa,
            // em vez de fechar o app a cada abertura.
            container = try! Persistence.makeContainer(inMemory: true)
            storageFailed = true
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .alert("Seus dados não puderam ser abertos", isPresented: .constant(storageFailed)) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Nada do que você marcar agora será salvo. Feche e abra o app de novo; se continuar, restaure uma cópia de segurança em Ajustes.")
                }
        }
        .modelContainer(container)
    }
}
