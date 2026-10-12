// Lingue di Nod: italiano, inglese, francese, spagnolo. La chiave di ogni testo è la frase italiana: `L("Stato")`,
// `L("Passo %d di %d", 2, 8)`. Le traduzioni stanno in Localization/<lingua>.lproj/Localizable.strings
// (it.lproj è vuoto: la chiave è già il testo). Sistema segue macOS; le altre scelte cambiano subito l'interfaccia.

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system, it, en, fr, es
    var id: String { rawValue }

    /// Il nome di ogni lingua scritto in quella lingua; "Sistema" tradotto.
    var title: String {
        switch self {
        case .system: L("Sistema")
        case .it: "Italiano"
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        }
    }
}

enum Localization {
    /// Aggiornato da Preferences quando cambi lingua.
    nonisolated(unsafe) static var language: AppLanguage = .system {
        didSet { bundle = resolveBundle() }
    }
    nonisolated(unsafe) private(set) static var bundle: Bundle = resolveBundle()

    /// Il codice della lingua che si vede adesso (per date, numeri e il report).
    static var effectiveCode: String {
        if language != .system { return language.rawValue }
        return Bundle.main.preferredLocalizations.first ?? "en"
    }

    static var locale: Locale { Locale(identifier: effectiveCode) }

    private static func resolveBundle() -> Bundle {
        guard language != .system,
              let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let b = Bundle(path: path) else { return .main }
        return b
    }
}

/// Il testo tradotto per la chiave italiana `key`.
func L(_ key: String) -> String {
    Localization.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// Il testo tradotto con valori: `L("Passo %d di %d", 2, 8)`, `L("Versione %@", v)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Localization.locale, arguments: args)
}
