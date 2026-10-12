// Il collegamento con Cocaine. Usa solo ciò che Cocaine espone già: la sua riga di comando
// (Cocaine.app/Contents/Resources/cocaine). Le richieste vere dell'AI e "Resta disponibile" non sono ancora collegate:
// finché non lo sono, `approvalsAvailable` resta false e l'interfaccia lo dice.

import AppKit
import Foundation

struct CocaineStatus: Decodable, Equatable {
    var on: Bool
    var until: Double?
    var remaining_minutes: Int?
}

@MainActor
final class CocaineBridge: ObservableObject {
    static let bundleID = "local.cocaine.toggle"

    @Published private(set) var appURL: URL?
    @Published private(set) var version: String?
    @Published private(set) var isRunning = false
    @Published private(set) var status: CocaineStatus?
    @Published private(set) var lastError: String?
    /// Richieste vere dell'AI e Resta disponibile collegate a Cocaine. Non ancora.
    @Published private(set) var approvalsAvailable = false

    var isInstalled: Bool { appURL != nil }
    private var engine: URL? { appURL?.appendingPathComponent("Contents/Resources/cocaine") }

    func refresh() {
        appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID)
        version = appURL.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        guard let out = await run(["status", "--json"]), let data = out.data(using: .utf8) else { return }
        status = try? JSONDecoder().decode(CocaineStatus.self, from: data)
    }

    /// Tiene sveglio il Mac (come `cocaine on`): restituisce se ci è riuscito.
    @discardableResult
    func keepAwake() async -> Bool {
        let ok = await run(["on"]) != nil
        await refreshStatus()
        return ok
    }

    @discardableResult
    func stopKeepingAwake() async -> Bool {
        let ok = await run(["off"]) != nil
        await refreshStatus()
        return ok
    }

    func openCocaine() {
        guard let appURL else { return }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Esegue il motore di Cocaine fuori dal thread principale; nil se manca o fallisce.
    private func run(_ args: [String]) async -> String? {
        guard let engine, FileManager.default.isExecutableFile(atPath: engine.path) else {
            lastError = L("Cocaine non è installato.")
            return nil
        }
        let result: (Int32, String) = await Task.detached {
            let p = Process()
            p.executableURL = engine
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            do { try p.run() } catch { return (-1, "") }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        }.value
        guard result.0 == 0 else {
            lastError = L("Il comando di Cocaine \"%@\" non è riuscito (codice %d).", args.joined(separator: " "), Int(result.0))
            return nil
        }
        lastError = nil
        return result.1
    }
}
