import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case ler, planos, salvos, progresso, ajustes
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ReaderDefaults.themeKey, store: AppGroup.defaults) private var themeRaw = ReaderTheme.sistema.rawValue

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            ReaderView()
                .tabItem { Label("Ler", systemImage: "book") }
                .tag(AppTab.ler)
            PlansView()
                .tabItem { Label("Planos", systemImage: "calendar") }
                .tag(AppTab.planos)
            SavedView()
                .tabItem { Label("Salvos", systemImage: "bookmark") }
                .tag(AppTab.salvos)
            ProgressScreen()
                .tabItem { Label("Progresso", systemImage: "square.grid.3x3.fill") }
                .tag(AppTab.progresso)
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(AppTab.ajustes)
        }
        .preferredColorScheme(ReaderTheme(rawValue: themeRaw)?.colorScheme)
        .task {
            app.onReadingChanged = { store in ReadingSync.refresh(store) }
            await app.refreshVersions()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await app.refreshVersions() }
            ReadingSync.refresh(BibleStore(context: context))
        }
    }
}
