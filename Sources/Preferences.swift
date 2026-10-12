// Preferenze salvate (UserDefaults) e le regole della presenza. Il token del server ntfy sta nel Portachiavi (Keychain.swift).

import Foundation
import Security
import AppKit
import SwiftUI

/// Un'app che, se aperta, rende "tieni sveglio" la scelta predefinita quando ti allontani.
struct WatchedApp: Codable, Hashable, Identifiable {
    var bundleIDs: [String]
    var name: String
    var id: String { name }

    static let teams = WatchedApp(bundleIDs: ["com.microsoft.teams2", "com.microsoft.teams"], name: "Microsoft Teams")
    static let slack = WatchedApp(bundleIDs: ["com.tinyspeck.slackmacgap"], name: "Slack")
    static let zoom = WatchedApp(bundleIDs: ["us.zoom.xos"], name: "Zoom")
    static let suggestions = [teams, slack, zoom]
}

/// Giorni della settimana e fascia oraria. I giorni usano la numerazione di Calendar (1 = domenica … 7 = sabato).
/// Una fascia che passa la mezzanotte (22:00-02:00) appartiene al giorno in cui inizia.
struct WorkSchedule: Codable, Equatable {
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var startMinutes = 9 * 60
    var endMinutes = 18 * 60

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let day = c.weekday else { return false }
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if startMinutes == endMinutes { return weekdays.contains(day) }
        if startMinutes < endMinutes { return weekdays.contains(day) && m >= startMinutes && m < endMinutes }
        let yesterday = day == 1 ? 7 : day - 1
        return (weekdays.contains(day) && m >= startMinutes) || (weekdays.contains(yesterday) && m < endMinutes)
    }
}

/// Cosa fare quando ti allontani.
enum LeavingAction: String, Codable, CaseIterable, Identifiable {
    case keepAwake, stayOnline, nothing
    var id: String { rawValue }

    var title: String {
        switch self {
        case .keepAwake: L("Tieni sveglio")
        case .stayOnline: L("Resta online")
        case .nothing: L("Niente")
        }
    }
}

struct LeavingRule: Codable, Equatable {
    /// Basta che una di queste app sia aperta.
    var apps: [WatchedApp] = [.teams]
    var schedule = WorkSchedule()
    /// Minuti di attesa della tua risposta sul Watch prima di applicare la scelta predefinita.
    var timeoutMinutes = 5

    /// La regola scelta per il silenzio: "tieni sveglio" se una delle app è aperta ed è la tua fascia oraria, altrimenti niente.
    func defaultAction(now: Date, running: Set<String>, calendar: Calendar = .current) -> LeavingAction {
        let appOpen = apps.contains { !Set($0.bundleIDs).isDisjoint(with: running) }
        return appOpen && schedule.contains(now, calendar: calendar) ? .keepAwake : .nothing
    }

    /// I pulsanti della notifica, il predefinito per primo (il doppio tap sul Watch esegue il primo).
    func buttons(now: Date, running: Set<String>, stayOnlineAvailable: Bool) -> [LeavingAction] {
        let first = defaultAction(now: now, running: running)
        var all: [LeavingAction] = [.keepAwake]
        if stayOnlineAvailable { all.append(.stayOnline) }
        all.append(.nothing)
        return [first] + all.filter { $0 != first }
    }
}

enum NtfyServerChoice: String, Codable, CaseIterable, Identifiable {
    case ntfySh, own
    var id: String { rawValue }
    var title: String { self == .ntfySh ? L("ntfy.sh (predefinito)") : L("Server mio") }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    @Published var setupCompleted: Bool { didSet { defaults.set(setupCompleted, forKey: "setupCompleted") } }
    @Published var lastSeenVersion: String { didSet { defaults.set(lastSeenVersion, forKey: "lastSeenVersion") } }
    @Published var headMotionEnabled: Bool { didSet { defaults.set(headMotionEnabled, forKey: "headMotionEnabled") } }
    @Published var speakSummaries: Bool { didSet { defaults.set(speakSummaries, forKey: "speakSummaries") } }
    @Published var serverChoice: NtfyServerChoice { didSet { defaults.set(serverChoice.rawValue, forKey: "serverChoice") } }
    @Published var ownServerURL: String { didSet { defaults.set(ownServerURL, forKey: "ownServerURL") } }
    @Published var topic: String { didSet { defaults.set(topic, forKey: "topic") } }
    @Published var leavingRule: LeavingRule { didSet { save(leavingRule, "leavingRule") } }
    @Published var leavingIdleSeconds: Int { didSet { defaults.set(leavingIdleSeconds, forKey: "leavingIdleSeconds") } }
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance"); applyAppearance() }
    }
    @Published var menuBarStyle: MenuBarStyle { didSet { defaults.set(menuBarStyle.rawValue, forKey: "menuBarStyle") } }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language"); Localization.language = language }
    }
    /// Quale politica di LocalAuthentication usare per la conferma col Watch (Diagnostica).
    @Published var watchMethod: WatchMethod { didSet { defaults.set(watchMethod.rawValue, forKey: "watchMethod") } }
    /// In automatico: l'ultimo metodo che ha davvero confermato, provato per primo la volta dopo.
    @Published var learnedWatchMethod: WatchMethod? {
        didSet { defaults.set(learnedWatchMethod?.rawValue, forKey: "learnedWatchMethod") }
    }
    /// Mostra nel Dock l'icona classica (.icns) invece di quella del catalogo, se quella non si vede.
    @Published var classicDockIcon: Bool {
        didSet { defaults.set(classicDockIcon, forKey: "classicDockIcon"); applyDockIcon() }
    }
    @Published var autoCheckUpdates: Bool { didSet { defaults.set(autoCheckUpdates, forKey: "autoCheckUpdates") } }
    /// Avvisi anche con Promemoria (iCloud) oltre a ntfy: ReminderRelay.
    @Published var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: "remindersEnabled") } }

    private init() {
        setupCompleted = defaults.bool(forKey: "setupCompleted")
        lastSeenVersion = defaults.string(forKey: "lastSeenVersion") ?? "0"
        headMotionEnabled = defaults.object(forKey: "headMotionEnabled") as? Bool ?? true
        speakSummaries = defaults.bool(forKey: "speakSummaries")
        serverChoice = NtfyServerChoice(rawValue: defaults.string(forKey: "serverChoice") ?? "") ?? .ntfySh
        ownServerURL = defaults.string(forKey: "ownServerURL") ?? ""
        topic = defaults.string(forKey: "topic") ?? Preferences.newTopic()
        leavingIdleSeconds = defaults.object(forKey: "leavingIdleSeconds") as? Int ?? 30
        leavingRule = (defaults.data(forKey: "leavingRule")).flatMap { try? JSONDecoder().decode(LeavingRule.self, from: $0) }
            ?? LeavingRule()
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: "menuBarStyle") ?? "") ?? .filled
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        watchMethod = WatchMethod(rawValue: defaults.string(forKey: "watchMethod") ?? "") ?? .automatic
        learnedWatchMethod = WatchMethod(rawValue: defaults.string(forKey: "learnedWatchMethod") ?? "")
        classicDockIcon = defaults.bool(forKey: "classicDockIcon")
        autoCheckUpdates = defaults.object(forKey: "autoCheckUpdates") as? Bool ?? true
        remindersEnabled = defaults.bool(forKey: "remindersEnabled")
        defaults.set(topic, forKey: "topic")
        Localization.language = language
    }

    /// Icona classica nel Dock mentre Nod è aperto: se scelta, o da sola se l'icona Liquid Glass risulta vuota (IconHealth).
    func applyDockIcon() {
        IconHealth.shared.apply(forceClassic: classicDockIcon)
    }

    /// Una volta sola (0.3.2): l'icona classica forzata era il rimedio della 0.3.0 per il Dock vuoto. Se ora l'icona Liquid
    /// Glass risulta a posto, la scelta si spegne; resta disponibile in Diagnostica.
    func migrateClassicDockIcon() {
        guard !defaults.bool(forKey: "migration.classicDockIcon.0.3.2") else { return }
        defaults.set(true, forKey: "migration.classicDockIcon.0.3.2")
        guard classicDockIcon, IconHealth.shared.tier == "liquid-glass", IconHealth.shared.looksHealthy else { return }
        classicDockIcon = false
        diag(.icon, "classic Dock icon turned off: the Liquid Glass icon renders correctly")
    }

    /// Applica a tutta l'app l'aspetto scelto (Sistema = segue macOS).
    func applyAppearance() {
        NSApp?.appearance = appearance.nsAppearance
    }

    /// L'indirizzo del server in uso, senza "/" finale.
    var serverURL: URL? {
        let raw = serverChoice == .ntfySh ? "https://ntfy.sh" : ownServerURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: raw.hasSuffix("/") ? String(raw.dropLast()) : raw), url.scheme == "https" else { return nil }
        return url
    }

    /// Nome del topic casuale: chi lo conosce può leggere e scrivere sul topic, quindi fa da segreto.
    static func newTopic() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return "nod-" + bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
