// Lo stato dell'app: preferenze, servizi (Cocaine, AirPods, Watch, notifiche, presenza) e quale configurazione mostrare.

import AppKit
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case status, approvals, presence, devices, whatsNew, diagnostics
    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: L("Stato")
        case .approvals: L("Approvazioni")
        case .presence: L("Presenza")
        case .devices: L("Dispositivi")
        case .whatsNew: L("Novità")
        case .diagnostics: L("Diagnostica")
        }
    }

    var symbol: String {
        switch self {
        case .status: "gauge.with.dots.needle.33percent"
        case .approvals: "checkmark.seal"
        case .presence: "figure.walk"
        case .devices: "airpodspro"
        case .whatsNew: "sparkles"
        case .diagnostics: "stethoscope"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let prefs: Preferences
    let cocaine: CocaineBridge
    let head: HeadMotionMonitor
    let watch: WatchConfirmer
    let relay: NotificationRelay
    let reminders: ReminderRelay
    let presence: PresenceEngine
    let approvals: ApprovalFlow
    let updater: Updater

    @Published var selection: SidebarItem? = .status
    @Published var setup: SetupSession?

    private init() {
        let prefs = Preferences.shared, cocaine = CocaineBridge(), head = HeadMotionMonitor(), watch = WatchConfirmer(prefs: prefs)
        let relay = NotificationRelay(prefs: prefs), reminders = ReminderRelay(prefs: prefs)
        let presence = PresenceEngine(prefs: prefs, head: head, cocaine: cocaine)
        presence.relay = relay
        presence.reminders = reminders
        self.prefs = prefs
        self.cocaine = cocaine
        self.head = head
        self.watch = watch
        self.relay = relay
        self.reminders = reminders
        self.presence = presence
        approvals = ApprovalFlow(head: head, watch: watch, relay: relay, reminders: reminders, prefs: prefs)
        updater = Updater(prefs: prefs)
    }

    var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func didLaunch() {
        let info = Bundle.main.infoDictionary ?? [:]
        diag(.app, "launch \(appVersion) build \(info["CFBundleVersion"] as? String ?? "?"), icon \(info["NodIconTier"] as? String ?? "?"), "
             + "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        prefs.applyAppearance()
        prefs.applyDockIcon()
        prefs.migrateClassicDockIcon()
        updater.start()
        cocaine.refresh()
        watch.refresh()
        if prefs.setupCompleted, prefs.headMotionEnabled { head.start() }
        presence.start()
        relay.startListening()

        if !prefs.setupCompleted {
            startSetup(.full)
        } else if Version(appVersion) > Version(prefs.lastSeenVersion) {
            startSetup(.update(from: prefs.lastSeenVersion))
        }
    }

    /// Primo avvio: tutti i passaggi. Aggiornamento: le novità e solo i passaggi introdotti dopo l'ultima versione vista.
    func startSetup(_ kind: SetupSession.Kind) {
        setup = SetupSession(kind: kind, currentVersion: appVersion)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showWhatsNew() {
        selection = .whatsNew
        NSApp.activate(ignoringOtherApps: true)
    }

    func finishSetup() {
        prefs.setupCompleted = true
        prefs.lastSeenVersion = appVersion
        setup = nil
        if prefs.headMotionEnabled { head.start() }
        relay.startListening()
    }
}

/// Confronto numerico tra versioni ("0.10.0" > "0.9.2").
struct Version: Comparable {
    let parts: [Int]
    init(_ string: String) { parts = string.split(separator: ".").map { Int($0) ?? 0 } }

    static func < (a: Version, b: Version) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0, y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    static func == (a: Version, b: Version) -> Bool { !(a < b) && !(b < a) }
}
