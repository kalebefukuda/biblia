import SwiftUI

enum AppTab: Hashable {
    case ler, planos, salvos, progresso, ajustes
}

struct RootView: View {
    @State private var tab: AppTab = .ler

    var body: some View {
        TabView(selection: $tab) {
            Text("Ler")
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
    }
}
