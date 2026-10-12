// Diagnostica: un registro degli eventi (in memoria e in ~/Library/Application Support/Nod/diagnostics.log) e un report
// in testo semplice da mandare come feedback. Mai segreti: niente token, topic mascherato, niente testi delle richieste.

import AppKit
import CoreMotion
import Foundation
import LocalAuthentication

enum DiagCategory: String {
    case app, watch, ntfy, presence, airpods, cocaine, update, icon
}

@MainActor
final class DiagnosticsLog: ObservableObject {
    static let shared = DiagnosticsLog()

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let category: DiagCategory
        let message: String
    }

    @Published private(set) var entries: [Entry] = []
    private let limit = 300
    private let fileURL: URL? = {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Nod", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("diagnostics.log")
    }()

    func add(_ category: DiagCategory, _ message: String) {
        let entry = Entry(date: Date(), category: category, message: message)
        entries.append(entry)
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        append(toFile: "\(Self.stamp(entry.date)) [\(category.rawValue)] \(message)\n")
    }

    private func append(toFile line: String) {
        guard let fileURL, let data = line.data(using: .utf8) else { return }
        if let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? Int, size > 512 * 1024 {
            try? FileManager.default.removeItem(at: fileURL.deletingPathExtension().appendingPathExtension("old.log"))
            try? FileManager.default.moveItem(at: fileURL, to: fileURL.deletingPathExtension().appendingPathExtension("old.log"))
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL)
        }
    }

    nonisolated static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: date)
    }
}

/// Scorciatoia per scrivere nel registro da qualsiasi punto del codice sul main actor.
@MainActor
func diag(_ category: DiagCategory, _ message: String) {
    DiagnosticsLog.shared.add(category, message)
}

/// Le politiche di LocalAuthentication che Nod sa usare per il Watch.
enum WatchMethod: String, CaseIterable, Identifiable, Codable {
    case automatic, companion, watch, biometricsOrCompanion
    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: L("Automatico")
        case .companion: "Companion (macOS 15+)"
        case .watch: "Apple Watch"
        case .biometricsOrCompanion: L("Touch ID o Watch")
        }
    }

    /// La politica concreta; nil se non esiste su questo macOS.
    var policy: LAPolicy? {
        switch self {
        case .automatic:
            return nil
        case .watch:
            return .deviceOwnerAuthenticationWithWatch
        case .companion:
            if #available(macOS 15.0, *) { return .deviceOwnerAuthenticationWithCompanion }
            return nil
        case .biometricsOrCompanion:
            if #available(macOS 15.0, *) { return .deviceOwnerAuthenticationWithBiometricsOrCompanion }
            return .deviceOwnerAuthenticationWithBiometricsOrWatch
        }
    }

    static let concrete: [WatchMethod] = [.companion, .watch, .biometricsOrCompanion]
}

enum DiagnosticsReport {
    @MainActor
    static func make(model: AppModel) -> String {
        var out: [String] = []
        func section(_ title: String) { out.append(""); out.append("## \(title)") }
        func row(_ key: String, _ value: String) { out.append("- \(key): \(value)") }

        let info = Bundle.main.infoDictionary ?? [:]
        out.append("# Nod diagnostics")
        row("Generated", DiagnosticsLog.stamp(Date()))

        section("App")
        row("Version", "\(info["CFBundleShortVersionString"] as? String ?? "?") (build \(info["CFBundleVersion"] as? String ?? "?"))")
        row("Commit", info["NodGitCommit"] as? String ?? "unknown")
        row("Signing", info["NodSigningTier"] as? String ?? "unknown")
        row("Icon", (info["NodIconTier"] as? String ?? "unknown") + (model.prefs.classicDockIcon ? " (classic Dock icon forced)" : ""))
        row("Bundle", Bundle.main.bundlePath)
        row("Language", "\(model.prefs.language.rawValue) → \(Localization.effectiveCode)")
        row("Appearance", model.prefs.appearance.rawValue)
        row("Update channel", Updater.channel.rawValue)

        section("Mac")
        row("macOS", ProcessInfo.processInfo.operatingSystemVersionString)
        row("Model", sysctl("hw.model"))
        #if arch(arm64)
        row("Architecture", "arm64")
        #else
        row("Architecture", "x86_64")
        #endif

        section("Cocaine")
        row("Installed", model.cocaine.appURL?.path ?? "no")
        row("Version", model.cocaine.version ?? "-")
        row("Running", model.cocaine.isRunning ? "yes" : "no")
        row("Awake", model.cocaine.status.map { $0.on ? "on" : "off" } ?? "unknown")
        row("Last error", model.cocaine.lastError ?? "-")

        section("AirPods")
        row("Motion available", model.head.isAvailable ? "yes" : "no")
        row("Authorization", "\(model.head.authorization.rawValue) (0 not determined, 1 restricted, 2 denied, 3 authorized)")
        row("Monitoring", model.head.isRunning ? "yes" : "no")
        row("Connected", model.head.isConnected ? "yes" : "no")
        row("Head motion setting", model.prefs.headMotionEnabled ? "on" : "off")

        section("Apple Watch (LocalAuthentication)")
        row("Method setting", model.prefs.watchMethod.rawValue)
        for method in WatchMethod.concrete {
            guard let policy = method.policy else { row(method.rawValue, "not available on this macOS"); continue }
            var error: NSError?
            let ok = LAContext().canEvaluatePolicy(policy, error: &error)
            row(method.rawValue, ok ? "can evaluate" : "cannot evaluate (\(error?.domain ?? "?") \(error?.code ?? 0): \(error?.localizedDescription ?? "-"))")
        }
        for attempt in model.watch.attempts.suffix(10) {
            out.append("  - \(attempt.line)")
        }

        section("Notifications (ntfy)")
        row("Server", model.prefs.serverURL?.host ?? "invalid URL")
        row("Topic", String(model.prefs.topic.prefix(8)) + "…")
        row("Access token", model.relay.accessToken == nil ? "none" : "set (hidden)")
        row("Listening for replies", model.relay.isListening ? "yes" : "no")
        row("Last publish", model.relay.lastPublish ?? "-")
        row("Server check", model.relay.lastServerCheck ?? "-")
        row("Last round trip", model.relay.lastRoundTrip.map(DiagnosticsLog.stamp) ?? "-")

        section("Presence")
        row("State", model.presence.state.rawValue)
        row("Since", DiagnosticsLog.stamp(model.presence.since))
        row("Idle seconds", String(format: "%.0f", PresenceEngine.idleSeconds()))

        section("Events (latest first)")
        for entry in DiagnosticsLog.shared.entries.suffix(150).reversed() {
            out.append("\(DiagnosticsLog.stamp(entry.date)) [\(entry.category.rawValue)] \(entry.message)")
        }
        return out.joined(separator: "\n") + "\n"
    }

    private static func sysctl(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "?" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    /// Salva il report e restituisce il file (di default sulla Scrivania).
    @MainActor
    static func save(_ text: String, to url: URL) throws {
        try text.data(using: .utf8)?.write(to: url)
        diag(.app, "Diagnostics report saved: \(url.lastPathComponent)")
    }

    static var suggestedFileName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "Nod-diagnostics-\(f.string(from: Date())).txt"
    }
}
