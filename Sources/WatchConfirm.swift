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
    /// Risultati della prova guidata in Diagnostica.
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
    /// Prova guidata: l'istruzione del passo in corso.
    @Published private(set) var guidedStep: String?

    private let prefs: Preferences
    private var context: LAContext?
    private var right: LARight?

    init(prefs: Preferences) { self.prefs = prefs }

    func refresh() {
        let chain = chain()
        currentChain = chain
        var error: NSError?
        if chain.first == .laRight {
            isAvailable = true
        } else if let first = chain.first, let policy = first.policy {
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
        if prefs.watchMethod != .automatic { return prefs.watchMethod.isUsable ? [prefs.watchMethod] : [] }
        var order: [WatchMethod] = []
        for method in [prefs.learnedWatchMethod].compactMap({ $0 }) + Self.automaticOrder where !order.contains(method) {
            if let policy = method.policy, LAContext().canEvaluatePolicy(policy, error: nil) { order.append(method) }
        }
        return order.isEmpty ? [.watch] : order
    }

    static let automaticOrder: [WatchMethod] = [.biometricsOrCompanion, .deviceOwner, .companion, .watch]

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
            guard method.isUsable else { continue }
            outcome = await run(method, reason: reason)
            if case .interrupted = outcome, let last = attempts.last, last.seconds < 1.5, last.code == LAError.Code.systemCancel.rawValue {
                diag(.watch, "Closed by the system after \(String(format: "%.2f", last.seconds))s: retrying with Nod in front")
                bringToFront()
                try? await Task.sleep(nanoseconds: 400_000_000)
                outcome = await run(method, reason: reason)
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

    /// Diagnostica, prova guidata: per ogni metodo dice prima cosa fare (solo doppio clic sul Watch, senza toccare il Mac),
    /// poi annota esito e codice. La tabella finisce anche nel report.
    func testAllMethods() async {
        methodResults = [:]
        let methods = WatchMethod.concrete
        for (index, method) in methods.enumerated() {
            guard method.isUsable else { methodResults[method] = L("Non disponibile su questo macOS"); continue }
            guidedStep = L("%d di %d, %@: ora doppio clic sul Watch, non toccare il Mac.", index + 1, methods.count, method.title)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let outcome = await run(method, reason: L("provare il metodo %@", method.title))
            let code = attempts.last.flatMap { $0.code }.map { " (\($0) \(Self.codeName(code: $0)))" } ?? ""
            methodResults[method] = outcome.title + code
        }
        guidedStep = nil
        diag(.watch, "guided test: " + methods.map { "\($0.rawValue)=\(methodResults[$0] ?? "-")" }.joined(separator: "; "))
    }

    /// Un metodo: una LAPolicy oppure LARight.
    private func run(_ method: WatchMethod, reason: String) async -> Outcome {
        if method == .laRight { return await authorizeRight(reason: reason) }
        guard let policy = method.policy else { return .unavailable(L("Non disponibile su questo macOS")) }
        return await evaluate(policy, method: method, reason: reason)
    }

    /// Chiude la richiesta in corso (per esempio perché hai risposto dalla notifica).
    func cancel() {
        context?.invalidate()
        context = nil
        if let right {
            self.right = nil
            Task { await right.deauthorize() }
        }
        isAsking = false
    }

    /// Diagnostica: la stessa richiesta fatta da osascript, firmato Apple. Se così il Watch la riceve e da Nod no, macOS
    /// rifiuta il Watch per la firma locale di Nod (senza Team ID).
    func probeViaOsascript() async {
        guard let script = Bundle.main.url(forResource: "watch-probe", withExtension: "js") else {
            probeResult = L("Script di prova non trovato nell'app.")
            return
        }
        cancel()
        isProbing = true
        probeResult = nil
        let reason = L("provare il Watch da osascript")
        var lines: [String] = []
        // Solo Watch (3), poi Touch ID, Watch o password (2): due percorsi diversi dello stesso sistema.
        for policy in [WatchMethod.companion.policy ?? .deviceOwnerAuthenticationWithWatch, LAPolicy.deviceOwnerAuthentication] {
            diag(.watch, "osascript probe started (policy \(policy.rawValue))")
            let start = Date()
            let output = await Self.osascript(script: script, policy: policy, reason: reason)
            if policy != .deviceOwnerAuthentication {
                probeRefusedFast = Date().timeIntervalSince(start) < 3 && output.contains("error -1")
            }
            diag(.watch, "osascript probe: \(output)")
            lines.append(output.isEmpty ? L("Nessuna risposta da osascript.") : output)
        }
        probeResult = lines.joined(separator: " | ")
        isProbing = false
    }

    private static func osascript(script: URL, policy: LAPolicy, reason: String) async -> String {
        await Task.detached { () -> String in
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
    }

    // MARK: valutazione

    private func evaluate(_ policy: LAPolicy, method: WatchMethod, reason: String) async -> Outcome {
        cancel()
        let ctx = LAContext()
        ctx.localizedCancelTitle = L("Nega")
        // Niente pulsante di ripiego ("Usa password…"): su macOS 27.0.1 il doppio clic sul Watch tornava come userFallback (-3).
        // Con "Touch ID, Watch o password" la password fa parte della politica, quindi il ripiego resta.
        if method != .deviceOwner { ctx.localizedFallbackTitle = "" }
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

    /// LARight (macOS 13+): l'autorizzazione con il requisito predefinito, qualsiasi autenticazione del proprietario.
    private func authorizeRight(reason: String) async -> Outcome {
        cancel()
        let right = LARight()
        self.right = right
        isAsking = true
        bringToFront()
        diag(.watch, "authorize laRight")
        let start = Date()
        var error: NSError?
        do {
            try await right.authorize(localizedReason: reason)
        } catch let caught {
            error = caught as NSError
        }
        let seconds = Date().timeIntervalSince(start)
        let ok = error == nil
        let result = ok ? "confirmed" : "\(error?.domain ?? "?") \(error?.code ?? 0) \(Self.codeName(error))"
        attempts.append(Attempt(date: start, method: WatchMethod.laRight.rawValue, seconds: seconds, result: result,
                                code: ok ? nil : (error?.code ?? 0)))
        if attempts.count > 30 { attempts.removeFirst() }
        diag(.watch, "result laRight after \(String(format: "%.2f", seconds))s: \(result)")
        if self.right === right {
            self.right = nil
            isAsking = false
        }
        return ok ? .confirmed(seconds: seconds) : Self.outcome(for: error)
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
        case .userFallback?:
            return .interrupted(L("macOS ha chiuso la richiesta col ramo \"altro metodo\": il doppio clic non è stato riconosciuto come conferma."))
        default: return .unavailable(describe(error))
        }
    }

    private static func codeName(_ error: NSError?) -> String {
        guard let error else { return "" }
        return codeName(code: error.code)
    }

    static func codeName(code raw: Int) -> String {
        guard let code = LAError.Code(rawValue: raw) else { return "code \(raw)" }
        switch code {
        case .userCancel: return "userCancel"
        case .userFallback: return "userFallback"
        case .biometryNotEnrolled: return "biometryNotEnrolled"
        case .systemCancel: return "systemCancel"
        case .appCancel: return "appCancel"
        case .watchNotAvailable: return "watchNotAvailable"
        case .authenticationFailed: return "authenticationFailed"
        case .biometryNotAvailable: return "biometryNotAvailable"
        case .biometryLockout: return "biometryLockout"
        case .invalidContext: return "invalidContext"
        case .notInteractive: return "notInteractive"
        case .passcodeNotSet: return "passcodeNotSet"
        default: return "code \(raw)"
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
