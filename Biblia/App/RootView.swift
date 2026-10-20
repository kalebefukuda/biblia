import SwiftUI

enum AppTab: Hashable {
    case ler, planos, salvos, progresso, ajustes
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ReaderDefaults.themeKey, store: AppGroup.defaults) private var themeRaw = ReaderTheme.sistema.rawValue

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            ReaderView()
                .tabItem { Label("Ler", systemImage: "book") }
                .tag(AppTab.ler)
            Text("Planos")
                .tabItem { Label("Planos", systemImage: "calendar") }
                .tag(AppTab.planos)
            Text("Salvos")
                .tabItem { Label("Salvos", systemImage: "bookmark") }
                .tag(AppTab.salvos)
            Text("Progresso")
                .tabItem { Label("Progresso", systemImage: "square.grid.3x3.fill") }
                .tag(AppTab.progresso)
            Text("Ajustes")
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(AppTab.ajustes)
        }
        .preferredColorScheme(ReaderTheme(rawValue: themeRaw)?.colorScheme)
        .task { await app.refreshVersions() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await app.refreshVersions() } }
        }
    }
}
