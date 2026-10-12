// Conferma col doppio clic del tasto laterale dell'Apple Watch (LocalAuthentication), vicino al Mac.
// Serve "Usa Apple Watch per sbloccare app e Mac" attivo in Impostazioni di Sistema > Touch ID e password.
// - Il contesto resta vivo per tutta la richiesta e si può chiudere da qui (risposta arrivata dalla notifica).
// - Automatico: una catena di politiche, Touch ID o Watch → companion → watch (solo quelle che il Mac sa valutare), con
//   per prima quella che ha confermato l'ultima volta. Se una fallisce subito (meno di 1,5 s, senza che tu abbia fatto
//   niente) si passa alla seguente. Oppure la politica scelta in Diagnostica. Ogni tentativo va nel registro.
// - Se il sistema chiude la richiesta entro 1,5 s, un secondo tentativo dopo aver portato davanti la finestra di Nod.
// - Prova da un processo firmato Apple (osascript, Resources/Scripts/watch-probe.js): dice se macOS rifiuta il Watch per
//   la firma locale di Nod.

import AppKit
import Foundation
import LocalAuthentication

@MainActor
final class WatchConfirmer: ObservableObject {
    enum Outcome: Equatable {
        case confirmed(seconds: Double)
        /// "Nega" nella richiesta di sistema: per un'approvazione vale come Nega.
        case denied
        /// Chiusa dal sistema o da Nod (un'altra risposta è arrivata prima): nessuna decisione.
        case interrupted(String)
        case unavailable(String)

        var title: String {
            switch self {
            case .confirmed(let s): L("Confermato in %@ s.", String(format: "%.1f", s))
            case .denied: L("Hai scelto Nega.")
            case .interrupted(let why): why
            case .unavailable(let why): why
            }
        }
    }

    struct Attempt {
        let date: Date
        let method: String
        let seconds: Double
        let result: String
        /// Codice di LAError, nil se confermato.
        let code: Int?
        var line: String { "\(DiagnosticsLog.stamp(date)) \(method) \(String(format: "%.2f", seconds))s → \(result)" }
    }

    @Published private(set) var isAvailable = false
    @Published private(set) var unavailableReason: String?
    @Published private(set) var isAsking = false
    @Published private(set) var lastOutcome: Outcome?
    @Published private(set) var attempts: [Attempt] = []
    /// Risultati di "Prova ogni metodo" in Diagnostica.
    @Published private(set) var methodResults: [WatchMethod: String] = [:]
    /// Esito della prova tramite osascript (processo firmato Apple).
    @Published private(set) var probeResult: String?
    @Published private(set) var isProbing = false
    /// Anche osascript (firmato Apple) è stato rifiutato subito: il limite è di macOS su questo Mac, non della firma di Nod.
    /// Resta salvato fra un avvio e l'altro, finché una nuova prova non dice altro.
    @Published private(set) var probeRefusedFast = UserDefaults.standard.bool(forKey: "watch.probeRefusedFast") {
        didSet { UserDefaults.standard.set(probeRefusedFast, forKey: "watch.probeRefusedFast") }
    }
    /// L'ordine dei metodi che Nod proverà adesso (aggiornato da `refresh`).
    @Published private(set) var currentChain: [WatchMethod] = []

    private let prefs: Preferences
    private var context: LAContext?

    init(prefs: Preferences) { self.prefs = prefs }

    func refresh() {
        let chain = chain()
        currentChain = chain
        var error: NSError?
        if let first = chain.first, let policy = first.policy {
            isAvailable = LAContext().canEvaluatePolicy(policy, error: &error)
        } else {
            isAvailable = false
        }
        unavailableReason = isAvailable ? nil : Self.describe(error)
        diag(.watch, "canEvaluate chain \(chain.map(\.rawValue).joined(separator: " → ")): \(isAvailable)"
             + (error.map { " (\($0.domain) \($0.code))" } ?? ""))
    }

    /// Le politiche da provare, in ordine: quella scelta in Diagnostica, oppure (automatico) quella che ha confermato
    /// l'ultima volta e poi Touch ID o Watch → companion → watch, tenendo solo quelle che il Mac sa valutare.
    func chain() -> [WatchMethod] {
        if prefs.watchMethod != .automatic { return prefs.watchMethod.policy == nil ? [] : [prefs.watchMethod] }
        var order: [WatchMethod] = []
        for method in [prefs.learnedWatchMethod].compactMap({ $0 }) + Self.automaticOrder where !order.contains(method) {
            if let policy = method.policy, LAContext().canEvaluatePolicy(policy, error: nil) { order.append(method) }
        }
        return order.isEmpty ? [.watch] : order
    }

    static let automaticOrder: [WatchMethod] = [.biometricsOrCompanion, .companion, .watch]

    /// Codici che, se arrivano entro 1,5 s, vogliono dire "questo metodo qui non va" e non "hai risposto".
    private static let fastFailCodes: Set<Int> = [LAError.Code.authenticationFailed.rawValue, LAError.Code.biometryNotAvailable.rawValue,
                                                  LAError.Code.watchNotAvailable.rawValue]

    /// Le politiche solo-Watch (companion, watch) falliscono subito: macOS non manda la richiesta al Watch.
    var watchOnlyFailsFast: Bool {
        guard let last = attempts.last(where: { $0.method == WatchMethod.companion.rawValue || $0.method == WatchMethod.watch.rawValue })
        else { return false }
        return last.seconds < 1.5 && last.code.map { Self.fastFailCodes.contains($0) } == true
    }

    /// Il doppio clic sul Watch non è disponibile per nessuna app su questo Mac (Nod e osascript rifiutati subito).
    /// Basta la prova da osascript: è una richiesta solo-Watch da un processo firmato Apple.
    var systemRefusesWatch: Bool { probeRefusedFast }
    /// Mostrare la lista di controllo del Watch.
    var needsTroubleshooting: Bool { watchOnlyFailsFast || systemRefusesWatch }

    /// Chiede la conferma sul Watch. `reason` completa la frase di sistema "Nod sta cercando di …".
    func confirm(_ reason: String) async -> Outcome {
        let chain = chain()
        var outcome: Outcome = .unavailable(L("Apple Watch non disponibile."))
        for (index, method) in chain.enumerated() {
            guard let policy = method.policy else { continue }
            outcome = await evaluate(policy, method: method, reason: reason)
            if case .interrupted = outcome, let last = attempts.last, last.seconds < 1.5, last.code == LAError.Code.systemCancel.rawValue {
                diag(.watch, "Closed by the system after \(String(format: "%.2f", last.seconds))s: retrying with Nod in front")
                bringToFront()
                try? await Task.sleep(nanoseconds: 400_000_000)
                outcome = await evaluate(policy, method: method, reason: reason)
            }
            if case .confirmed = outcome {
                if prefs.watchMethod == .automatic, prefs.learnedWatchMethod != method {
                    prefs.learnedWatchMethod = method
                    diag(.watch, "learned method: \(method.rawValue)")
                }
                break
            }
            guard index < chain.count - 1, let last = attempts.last, last.seconds < 1.5,
                  let code = last.code, Self.fastFailCodes.contains(code) else { break }
            diag(.watch, "\(method.rawValue) failed instantly (\(code)): trying \(chain[index + 1].rawValue)")
        }
        lastOutcome = outcome
        return outcome
    }

    /// Diagnostica: prova uno dopo l'altro i metodi e annota quale funziona.
    func testAllMethods() async {
        methodResults = [:]
        for method in WatchMethod.concrete {
            guard let policy = method.policy else { methodResults[method] = L("Non disponibile su questo macOS"); continue }
            let outcome = await evaluate(policy, method: method, reason: L("provare il metodo %@", method.title))
            methodResults[method] = outcome.title
        }
    }

    /// Chiude la richiesta in corso (per esempio perché hai risposto dalla notifica).
    func cancel() {
        context?.invalidate()
        context = nil
        isAsking = false
    }

    /// Diagnostica: la stessa richiesta fatta da osascript, firmato Apple. Se così il Watch la riceve e da Nod no, macOS
    /// rifiuta il Watch per la firma locale di Nod (senza Team ID).
    func probeViaOsascript() async {
        guard let script = Bundle.main.url(forResource: "watch-probe", withExtension: "js") else {
            probeResult = L("Script di prova non trovato nell'app.")
            return
        }
        let method = chain().first(where: { $0 != .biometricsOrCompanion }) ?? .companion
        guard let policy = method.policy else { return }
        cancel()
        isProbing = true
        probeResult = nil
        diag(.watch, "osascript probe started (\(method.rawValue), policy \(policy.rawValue))")
        let reason = L("provare il Watch da osascript")
        let start = Date()
        let output = await Task.detached { () -> String in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", script.path, String(policy.rawValue), reason]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do { try process.run() } catch { return "launch failed: \(error.localizedDescription)" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
        probeResult = output.isEmpty ? L("Nessuna risposta da osascript.") : output
        probeRefusedFast = Date().timeIntervalSince(start) < 3 && output.contains("error -1")
        isProbing = false
        diag(.watch, "osascript probe: \(output)")
    }

    // MARK: valutazione

    private func evaluate(_ policy: LAPolicy, method: WatchMethod, reason: String) async -> Outcome {
        cancel()
        let ctx = LAContext()
        ctx.localizedCancelTitle = L("Nega")
        context = ctx
        isAsking = true
        bringToFront()
        let active = NSApp.isActive, key = NSApp.keyWindow != nil
        diag(.watch, "evaluate \(method.rawValue) (app active: \(active), key window: \(key))")
        let start = Date()
        // Versione con completion: il contesto resta trattenuto qui finché il sistema non risponde.
        let (ok, error): (Bool, NSError?) = await withCheckedContinuation { continuation in
            ctx.evaluatePolicy(policy, localizedReason: reason) { ok, error in
                continuation.resume(returning: (ok, error as NSError?))
            }
        }
        let seconds = Date().timeIntervalSince(start)
        let outcome: Outcome = ok ? .confirmed(seconds: seconds) : Self.outcome(for: error)
        let result = ok ? "confirmed" : "\(error?.domain ?? "?") \(error?.code ?? 0) \(Self.codeName(error))"
        attempts.append(Attempt(date: start, method: method.rawValue, seconds: seconds, result: result,
                                code: ok ? nil : (error?.code ?? 0)))
        if attempts.count > 30 { attempts.removeFirst() }
        diag(.watch, "result \(method.rawValue) after \(String(format: "%.2f", seconds))s: \(result)")
        if context === ctx {
            context = nil
            isAsking = false
        }
        return outcome
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible && $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
    }

    private static func outcome(for error: NSError?) -> Outcome {
        guard let error else { return .interrupted(L("Non confermato.")) }
        switch LAError.Code(rawValue: error.code) {
        case .userCancel?: return .denied
        case .systemCancel?: return .interrupted(L("Chiusa dal sistema (codice %d): Nod deve restare l'app attiva.", error.code))
        case .appCancel?, .invalidContext?: return .interrupted(L("Richiesta chiusa da Nod."))
        default: return .unavailable(describe(error))
        }
    }

    private static func codeName(_ error: NSError?) -> String {
        guard let error, let code = LAError.Code(rawValue: error.code) else { return "" }
        switch code {
        case .userCancel: return "userCancel"
        case .systemCancel: return "systemCancel"
        case .appCancel: return "appCancel"
        case .watchNotAvailable: return "watchNotAvailable"
        case .authenticationFailed: return "authenticationFailed"
        case .biometryNotAvailable: return "biometryNotAvailable"
        case .biometryLockout: return "biometryLockout"
        case .invalidContext: return "invalidContext"
        case .notInteractive: return "notInteractive"
        case .passcodeNotSet: return "passcodeNotSet"
        default: return "code \(error.code)"
        }
    }

    private static func describe(_ error: NSError?) -> String {
        guard let error else { return L("Apple Watch non disponibile.") }
        switch LAError.Code(rawValue: error.code) {
        case .watchNotAvailable?: return L("Nessun Apple Watch sbloccato vicino al Mac.")
        case .authenticationFailed?: return L("Conferma non riuscita.")
        case .notInteractive?: return L("Nod non può mostrare la richiesta adesso.")
        default: return "\(error.localizedDescription) (\(error.code))"
        }
    }
}
