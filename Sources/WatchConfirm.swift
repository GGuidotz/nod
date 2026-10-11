// Conferma col doppio clic del tasto laterale dell'Apple Watch (LocalAuthentication), vicino al Mac.
// Serve "Usa Apple Watch per sbloccare app e Mac" attivo in Impostazioni di Sistema > Touch ID e password.

import Foundation
import LocalAuthentication

@MainActor
final class WatchConfirmer: ObservableObject {
    enum Outcome: Equatable {
        case confirmed(seconds: Double)
        case refused(String)
    }

    @Published private(set) var isAvailable = false
    @Published private(set) var unavailableReason: String?
    @Published private(set) var isAsking = false
    @Published private(set) var lastOutcome: Outcome?

    func refresh() {
        var error: NSError?
        isAvailable = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithWatch, error: &error)
        unavailableReason = isAvailable ? nil : Self.describe(error)
    }

    /// Chiede la conferma sul Watch. `reason` completa la frase di sistema "Nod sta cercando di …".
    func confirm(_ reason: String) async -> Outcome {
        isAsking = true
        defer { isAsking = false }
        let start = Date()
        let outcome: Outcome
        do {
            let ok = try await LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithWatch, localizedReason: reason)
            outcome = ok ? .confirmed(seconds: Date().timeIntervalSince(start)) : .refused("Non confermato.")
        } catch {
            outcome = .refused(Self.describe(error as NSError))
        }
        lastOutcome = outcome
        return outcome
    }

    private static func describe(_ error: NSError?) -> String {
        guard let error else { return "Apple Watch non disponibile." }
        switch LAError.Code(rawValue: error.code) {
        case .watchNotAvailable?: return "Nessun Apple Watch sbloccato vicino al Mac."
        case .userCancel?, .appCancel?, .systemCancel?: return "Richiesta annullata."
        case .authenticationFailed?: return "Conferma non riuscita."
        default: return error.localizedDescription
        }
    }
}
