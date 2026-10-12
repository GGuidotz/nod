// Conferma col doppio clic del tasto laterale dell'Apple Watch (LocalAuthentication), vicino al Mac.
// Serve "Usa Apple Watch per sbloccare app e Mac" attivo in Impostazioni di Sistema > Touch ID e password.
// - Il contesto resta vivo per tutta la richiesta e si può chiudere da qui (risposta arrivata dalla notifica).
// - Politica: su macOS 15+ prima "companion" (la politica watch è deprecata da macOS 15), poi watch; oppure quella scelta
//   in Diagnostica. Ogni tentativo va nel registro con durata e codice d'errore.
// - Se il sistema chiude la richiesta entro 1,5 s, un secondo tentativo dopo aver portato davanti la finestra di Nod.

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
        var line: String { "\(DiagnosticsLog.stamp(date)) \(method) \(String(format: "%.2f", seconds))s → \(result)" }
    }

    @Published private(set) var isAvailable = false
    @Published private(set) var unavailableReason: String?
    @Published private(set) var isAsking = false
    @Published private(set) var lastOutcome: Outcome?
    @Published private(set) var attempts: [Attempt] = []
    /// Risultati di "Prova ogni metodo" in Diagnostica.
    @Published private(set) var methodResults: [WatchMethod: String] = [:]

    private let prefs: Preferences
    private var context: LAContext?

    init(prefs: Preferences) { self.prefs = prefs }

    func refresh() {
        let (method, policy) = resolved()
        var error: NSError?
        isAvailable = LAContext().canEvaluatePolicy(policy, error: &error)
        unavailableReason = isAvailable ? nil : Self.describe(error)
        diag(.watch, "canEvaluate \(method.rawValue): \(isAvailable)" + (error.map { " (\($0.domain) \($0.code))" } ?? ""))
    }

    /// La politica da usare adesso: quella scelta, oppure la prima che il Mac sa valutare.
    private func resolved() -> (WatchMethod, LAPolicy) {
        if prefs.watchMethod != .automatic, let policy = prefs.watchMethod.policy { return (prefs.watchMethod, policy) }
        for method in [WatchMethod.companion, .watch] {
            if let policy = method.policy, LAContext().canEvaluatePolicy(policy, error: nil) { return (method, policy) }
        }
        return (.watch, .deviceOwnerAuthenticationWithWatch)
    }

    /// Chiede la conferma sul Watch. `reason` completa la frase di sistema "Nod sta cercando di …".
    func confirm(_ reason: String) async -> Outcome {
        let (method, policy) = resolved()
        var outcome = await evaluate(policy, method: method, reason: reason)
        if case .interrupted = outcome, let last = attempts.last, last.seconds < 1.5, last.result.contains("systemCancel") {
            diag(.watch, "Closed by the system after \(String(format: "%.2f", last.seconds))s: retrying with Nod in front")
            bringToFront()
            try? await Task.sleep(nanoseconds: 400_000_000)
            outcome = await evaluate(policy, method: method, reason: reason)
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
        attempts.append(Attempt(date: start, method: method.rawValue, seconds: seconds, result: result))
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
