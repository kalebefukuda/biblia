import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable {
    case sistema, claro, sepia, escuro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sistema: "Automático"
        case .claro: "Claro"
        case .sepia: "Sépia"
        case .escuro: "Escuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .sistema: nil
        case .claro, .sepia: .light
        case .escuro: .dark
        }
    }

    var background: Color {
        switch self {
        case .sistema: Color(.systemBackground)
        case .claro: .white
        case .sepia: Color(red: 0.965, green: 0.933, blue: 0.866)
        case .escuro: Color(red: 0.07, green: 0.07, blue: 0.08)
        }
    }

    var text: Color {
        switch self {
        case .sistema: Color(.label)
        case .claro: Color(white: 0.1)
        case .sepia: Color(red: 0.25, green: 0.2, blue: 0.15)
        case .escuro: Color(white: 0.88)
        }
    }

    var secondary: Color {
        switch self {
        case .sistema: Color(.secondaryLabel)
        case .claro: Color(white: 0.45)
        case .sepia: Color(red: 0.5, green: 0.42, blue: 0.33)
        case .escuro: Color(white: 0.55)
        }
    }

    /// Amostra usada no seletor de tema.
    var swatch: Color {
        self == .sistema ? Color(.secondarySystemBackground) : background
    }
}

enum ReaderDefaults {
    static let fontSizeKey = "tamanhoFonte"
    static let themeKey = "temaLeitura"
    static let defaultFontSize: Double = 19
    static let fontRange: ClosedRange<Double> = 14...30
}
