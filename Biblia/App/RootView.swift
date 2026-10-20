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
            app.onReadingChanged = { [app] store in ReadingSync.refresh(store, text: app.text) }
            await app.refreshVersions()
            ReadingSync.refresh(BibleStore(context: context), text: app.text)
        }
        .onChange(of: app.text?.id) { _, _ in
            ReadingSync.refresh(BibleStore(context: context), text: app.text)
        }
        .onOpenURL(perform: handle)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await app.refreshVersions() }
            ReadingSync.refresh(BibleStore(context: context), text: app.text)
        }
    }

    /// Links do widget: biblia://progresso e biblia://versiculo/43.3.16.
    /// A URL vem de fora do app, então só aceita referências válidas do cânon.
    private func handle(_ url: URL) {
        guard url.scheme == "biblia" else { return }
        switch url.host() {
        case "progresso":
            app.tab = .progresso
        case "versiculo":
            let key = url.lastPathComponent
            if let ref = VerseRef(key: key), Canon.isValid(ref.chapterRef), ref.verse >= 1 {
                app.open(ref)
            }
        default:
            break
        }
    }
}
