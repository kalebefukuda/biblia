import SwiftData
import SwiftUI

@main
struct BibliaApp: App {
    @State private var app: AppState
    private let container: ModelContainer

    init() {
        if AppGroup.isAvailable {
            try? StorageMaintenance.migrateIfNeeded(from: AppGroup.legacyURL, to: AppGroup.containerURL)
            StorageMaintenance.migrateDefaults(from: .standard, to: AppGroup.defaults)
        }

        let state = AppState()
        do {
            container = try Persistence.makeContainer()
        } catch {
            // Nunca apagar dados automaticamente: abre em memória e avisa,
            // em vez de fechar o app a cada abertura.
            container = try! Persistence.makeContainer(inMemory: true)
            state.storageFailed = true
        }
        _app = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .alert("Seus dados não puderam ser abertos", isPresented: .constant(app.storageFailed && !app.storageWarningSeen)) {
                    Button("Entendi") { app.storageWarningSeen = true }
                } message: {
                    Text("Nada do que você fizer agora será salvo. Não apague sua cópia de segurança. Feche e abra o app de novo; se continuar, vá em Ajustes para recomeçar.")
                }
        }
        .modelContainer(container)
    }
}
