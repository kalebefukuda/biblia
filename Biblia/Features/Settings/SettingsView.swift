import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @AppStorage(ReaderDefaults.fontSizeKey, store: AppGroup.defaults) private var fontSize = ReaderDefaults.defaultFontSize
    @AppStorage(ReaderDefaults.themeKey, store: AppGroup.defaults) private var themeRaw = ReaderTheme.sistema.rawValue
    @AppStorage(ReminderSettings.enabledKey, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(ReminderSettings.hourKey, store: AppGroup.defaults) private var reminderHour = 7
    @AppStorage(ReminderSettings.minuteKey, store: AppGroup.defaults) private var reminderMinute = 0

    @State private var importingVersion = false
    @State private var importingBackup = false
    @State private var exportingBackup = false
    @State private var backupDocument: BackupDocument?
    @State private var message: String?
    @State private var removing: VersionInfo?
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                versionsSection
                readingSection
                reminderSection
                backupSection
                aboutSection
            }
            .navigationTitle("Ajustes")
            .alert("Bíblia", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog(
                "Remover \(removing?.id ?? "")?",
                isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remover", role: .destructive) {
                    if let id = removing?.id { Task { await app.removeVersion(id) } }
                }
            } message: {
                Text("Seus destaques e notas continuam salvos.")
            }
            .task { await refreshPermission() }
        }
    }

    // MARK: Seções

    private var versionsSection: some View {
        Section {
            ForEach(app.versions.installed) { version in
                Button {
                    Task { await app.selectVersion(version.id) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(version.id).font(.body.weight(.semibold))
                            Text(version.name).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if version.id == app.currentVersionID {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Remover", role: .destructive) { removing = version }
                }
            }
            // Cada seletor de arquivo fica preso ao próprio botão: vários na mesma view
            // podem fazer só um deles abrir.
            Button {
                importingVersion = true
            } label: {
                Label("Importar versão", systemImage: "square.and.arrow.down")
            }
            .fileImporter(isPresented: $importingVersion, allowedContentTypes: [.json]) { result in
                Task {
                    do {
                        try await app.install(from: result.get())
                        message = "Versão importada."
                    } catch {
                        message = error.localizedDescription
                    }
                }
            }
            ForEach(app.versions.inboxMessages, id: \.self) { line in
                Text(line).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Versões")
        } footer: {
            Text("Arquivos JSON (ex.: ARA.json, NVI.json). Também dá para colocá-los na pasta “Bíblia” do app Arquivos ou arrastar pelo Finder com o iPhone no cabo; o app importa ao abrir.")
        }
    }

    private var readingSection: some View {
        Section("Leitura") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tamanho da letra")
                    Spacer()
                    Text("\(Int(fontSize))").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $fontSize, in: ReaderDefaults.fontRange, step: 1)
                Text("No princípio era o Verbo")
                    .font(.system(size: fontSize, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Picker("Tema", selection: $themeRaw) {
                ForEach(ReaderTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Lembrete diário", isOn: Binding(get: { reminderEnabled }, set: setReminder))
            if reminderEnabled {
                DatePicker("Horário", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
            if notificationsDenied {
                Button("Permitir notificações nos Ajustes do iPhone") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.footnote)
            }
        } header: {
            Text("Lembrete")
        } footer: {
            Text("Se você já leu no dia, o lembrete daquele dia não toca.")
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                do {
                    backupDocument = BackupDocument(data: try BackupService.encode(BackupService.makeBackup(context: context)))
                    exportingBackup = true
                } catch {
                    message = error.localizedDescription
                }
            } label: {
                Label("Exportar cópia de segurança", systemImage: "square.and.arrow.up")
            }
            .fileExporter(isPresented: $exportingBackup, document: backupDocument, contentType: .json, defaultFilename: backupFileName) { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            Button {
                importingBackup = true
            } label: {
                Label("Restaurar cópia", systemImage: "arrow.counterclockwise")
            }
            .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
                restoreBackup(result)
            }
        } header: {
            Text("Cópia de segurança")
        } footer: {
            Text("Guarda destaques, notas, leituras e planos num arquivo. Sem iCloud, faça uma cópia de vez em quando e salve no Arquivos ou no seu Mac.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Versão do app", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            LabeledContent("Widget", value: AppGroup.isAvailable ? "Ativo" : "Indisponível nesta conta")
        } header: {
            Text("Sobre")
        } footer: {
            Text("Os textos bíblicos pertencem aos seus detentores (ARA e NAA © Sociedade Bíblica do Brasil; NVI © Biblica). O app só lê os arquivos que você importa e não acessa a internet.")
        }
    }

    // MARK: Ações

    private var backupFileName: String {
        "biblia-backup-\(DayKey.from(.now))"
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        } set: { date in
            reminderHour = Calendar.current.component(.hour, from: date)
            reminderMinute = Calendar.current.component(.minute, from: date)
            ReadingSync.refresh(BibleStore(context: context))
        }
    }

    private func setReminder(_ enabled: Bool) {
        Task {
            if enabled {
                let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                notificationsDenied = !granted
                reminderEnabled = granted
            } else {
                reminderEnabled = false
            }
            ReadingSync.refresh(BibleStore(context: context))
        }
    }

    private func refreshPermission() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsDenied = status == .denied
        if status == .denied { reminderEnabled = false }
    }

    private func restoreBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let backup = try BackupService.decode(Data(contentsOf: url))
            let counts = BackupService.restore(backup, into: context)
            ReadingSync.refresh(BibleStore(context: context))
            message = "Restaurado: \(counts.marks) marcações, \(counts.readings) leituras e \(counts.plans) planos."
        } catch {
            message = error.localizedDescription
        }
    }
}
