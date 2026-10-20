import SwiftUI

struct ReaderView: View {
    @Environment(AppState.self) private var app
    @AppStorage(ReaderDefaults.fontSizeKey, store: AppGroup.defaults) private var fontSize = ReaderDefaults.defaultFontSize
    @AppStorage(ReaderDefaults.themeKey, store: AppGroup.defaults) private var themeRaw = ReaderTheme.sistema.rawValue

    @State private var pageIndex: Int?
    @State private var selection: Set<VerseRef> = []
    @State private var showBooks = false
    @State private var showSearch = false
    @State private var showDisplay = false

    private var theme: ReaderTheme { ReaderTheme(rawValue: themeRaw) ?? .sistema }

    var body: some View {
        NavigationStack {
            Group {
                if let text = app.text {
                    pager(text)
                } else if app.versions.installed.isEmpty {
                    NoVersionsView()
                } else if let error = app.loadError {
                    ContentUnavailableView("Não foi possível abrir a versão", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView()
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbarBackground(theme.background, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if let text = app.text, !selection.isEmpty {
                    VerseActionBar(refs: Array(selection), text: text) {
                        withAnimation(.snappy) { selection.removeAll() }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showBooks) { BookPicker() }
            .sheet(isPresented: $showSearch) { SearchView() }
        }
    }

    private func pager(_ text: BibleText) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<Canon.totalChapters, id: \.self) { index in
                    let ref = Canon.chapter(atGlobalIndex: index)
                    ChapterPage(
                        ref: ref,
                        verses: text.verses(ref),
                        fontSize: fontSize,
                        theme: theme,
                        selection: $selection
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIndex)
        .scrollIndicators(.hidden)
        .onAppear { pageIndex = app.position.globalIndex }
        .onChange(of: pageIndex) { _, index in
            guard let index else { return }
            let ref = Canon.chapter(atGlobalIndex: index)
            if ref != app.position { app.position = ref }
            selection.removeAll()
        }
        .onChange(of: app.position) { _, ref in
            if pageIndex != ref.globalIndex { pageIndex = ref.globalIndex }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            VersionMenu()
        }
        ToolbarItem(placement: .principal) {
            Button {
                showBooks = true
            } label: {
                HStack(spacing: 4) {
                    Text(app.position.title).font(.headline)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
                .foregroundStyle(theme.text)
            }
            .accessibilityLabel("Escolher livro e capítulo, atual \(app.position.title)")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                .accessibilityLabel("Buscar")
            Button { showDisplay = true } label: { Image(systemName: "textformat.size") }
                .accessibilityLabel("Letra e tema")
                .popover(isPresented: $showDisplay) {
                    DisplaySettings(fontSize: $fontSize, themeRaw: $themeRaw)
                        .presentationCompactAdaptation(.popover)
                }
        }
    }
}

/// Ajuste rápido de tamanho de letra e tema.
struct DisplaySettings: View {
    @Binding var fontSize: Double
    @Binding var themeRaw: String

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                Button { fontSize = max(ReaderDefaults.fontRange.lowerBound, fontSize - 1) } label: {
                    Image(systemName: "textformat.size.smaller").frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityLabel("Diminuir letra")
                Divider().frame(height: 24)
                Button { fontSize = min(ReaderDefaults.fontRange.upperBound, fontSize + 1) } label: {
                    Image(systemName: "textformat.size.larger").frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityLabel("Aumentar letra")
            }
            .font(.title3)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 14) {
                ForEach(ReaderTheme.allCases) { theme in
                    Button { themeRaw = theme.rawValue } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(theme.swatch)
                                .overlay(Circle().strokeBorder(themeRaw == theme.rawValue ? Color.accentColor : Color(.separator), lineWidth: themeRaw == theme.rawValue ? 2.5 : 1))
                                .overlay(Text("Aa").font(.system(size: 13, design: .serif)).foregroundStyle(theme == .sistema ? Color(.label) : theme.text))
                                .frame(width: 44, height: 44)
                            Text(theme.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}

/// Aparece quando ainda não há nenhuma versão no aparelho.
struct NoVersionsView: View {
    @Environment(AppState.self) private var app
    @State private var importing = false
    @State private var error: String?

    var body: some View {
        ContentUnavailableView {
            Label("Nenhuma versão instalada", systemImage: "books.vertical")
        } description: {
            Text("Importe o arquivo JSON de uma versão (ARA, NVI…) pelo app Arquivos, iCloud Drive ou AirDrop. Também dá para arrastar o arquivo pelo Finder para a pasta do app Bíblia.")
        } actions: {
            Button("Importar versão") { importing = true }
                .buttonStyle(.borderedProminent)
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task {
                do {
                    try await app.install(from: result.get())
                    error = nil
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
