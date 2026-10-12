// Conferma col doppio clic del tasto laterale dell'Apple Watch (LocalAuthentication), vicino al Mac.
// Serve "Usa Apple Watch per sbloccare app e Mac" attivo in Impostazioni di Sistema > Touch ID e password.
// Il contesto resta vivo per tutta la richiesta (un contesto rilasciato chiude subito la richiesta di sistema) e si può
// chiudere da qui quando la risposta arriva da un'altra strada (la notifica sul Watch).

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
            case .confirmed(let s): String(format: "Confermato in %.1f s.", s)
            case .denied: "Hai scelto Nega."
            case .interrupted(let why): why
            case .unavailable(let why): why
            }
        }
    }

    @Published private(set) var isAvailable = false
    @Published private(set) var unavailableReason: String?
    @Published private(set) var isAsking = false
    @Published private(set) var lastOutcome: Outcome?

    private var context: LAContext?

    func refresh() {
        var error: NSError?
        isAvailable = LAContext().canEvaluatePolicy(policy, error: &error)
        unavailableReason = isAvailable ? nil : Self.describe(error)
    }

    /// Il Watch come unico metodo; su macOS 15+ anche come "dispositivo companion" se il primo non è disponibile.
    private var policy: LAPolicy {
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithWatch, error: nil) {
            return .deviceOwnerAuthenticationWithWatch
        }
        if #available(macOS 15.0, *), LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithCompanion, error: nil) {
            return .deviceOwnerAuthenticationWithCompanion
        }
        return .deviceOwnerAuthenticationWithWatch
    }

    /// Chiede la conferma sul Watch. `reason` completa la frase di sistema "Nod sta cercando di …".
    func confirm(_ reason: String) async -> Outcome {
        cancel()
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Nega"
        context = ctx
        isAsking = true
        // Una richiesta di un'app non attiva viene chiusa dal sistema.
        NSApp.activate(ignoringOtherApps: true)
        let start = Date()
        let outcome: Outcome
        do {
            let ok = try await ctx.evaluatePolicy(policy, localizedReason: reason)
            outcome = ok ? .confirmed(seconds: Date().timeIntervalSince(start)) : .interrupted("Non confermato.")
        } catch {
            outcome = Self.outcome(for: error as NSError)
        }
        if context === ctx {
            context = nil
            isAsking = false
        }
        lastOutcome = outcome
        return outcome
    }

    /// Chiude la richiesta in corso (per esempio perché hai risposto dalla notifica).
    func cancel() {
        context?.invalidate()
        context = nil
        isAsking = false
    }

    private static func outcome(for error: NSError) -> Outcome {
        switch LAError.Code(rawValue: error.code) {
        case .userCancel?: return .denied
        case .systemCancel?: return .interrupted("Chiusa dal sistema (codice \(error.code)): Nod deve restare l'app attiva.")
        case .appCancel?, .invalidContext?: return .interrupted("Richiesta chiusa da Nod.")
        default: return .unavailable(describe(error))
        }
    }

    private static func describe(_ error: NSError?) -> String {
        guard let error else { return "Apple Watch non disponibile." }
        switch LAError.Code(rawValue: error.code) {
        case .watchNotAvailable?: return "Nessun Apple Watch sbloccato vicino al Mac."
        case .authenticationFailed?: return "Conferma non riuscita."
        case .notInteractive?: return "Nod non può mostrare la richiesta adesso."
        default: return "\(error.localizedDescription) (codice \(error.code))"
        }
    }
}
