// Notifiche sul Watch tramite ntfy: l'app ntfy dell'iPhone le mostra, il Watch le rispecchia, il doppio tap esegue il primo
// pulsante. Ogni pulsante porta un token casuale monouso con scadenza; il pulsante lo pubblica sul topic di risposta, che
// Nod ascolta con una connessione in uscita (nessuna porta aperta sul Mac).
// ntfy non cifra end-to-end: il testo resta minimo. Server proprio: docs/server-ntfy.md.

import Foundation
import Security

struct NtfyButton {
    let label: String
    let onTap: @MainActor () -> Void
}

@MainActor
final class NotificationRelay: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var lastEvent: String?

    private let prefs: Preferences
    private var pending: [String: (expires: Date, action: @MainActor () -> Void)] = [:]
    private var listenTask: Task<Void, Never>?

    init(prefs: Preferences) { self.prefs = prefs }

    var replyTopic: String { prefs.topic + "-r" }
    var accessToken: String? { Keychain.read("ntfy-token").flatMap { $0.isEmpty ? nil : $0 } }

    // MARK: invio

    /// Pubblica una notifica; i pulsanti (al massimo 3) restano validi per `lifetime` secondi.
    func send(title: String, message: String, buttons: [NtfyButton] = [], lifetime: TimeInterval = 120,
              priority: Int = 4) async -> Bool {
        guard let server = prefs.serverURL else { lastEvent = "Indirizzo del server non valido (serve https)."; return false }
        let expires = Date().addingTimeInterval(lifetime)
        pending = pending.filter { $0.value.expires > Date() }

        var actions: [[String: Any]] = []
        for button in buttons.prefix(3) {
            let token = Self.randomToken()
            pending[token] = (expires, button.onTap)
            var action: [String: Any] = ["action": "http", "label": button.label,
                                         "url": server.appendingPathComponent(replyTopic).absoluteString,
                                         "method": "POST", "body": token, "clear": true]
            if let accessToken { action["headers"] = ["Authorization": "Bearer \(accessToken)"] }
            actions.append(action)
        }
        let body: [String: Any] = ["topic": prefs.topic, "title": title, "message": message,
                                   "priority": priority, "actions": actions]
        var request = URLRequest(url: server)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            lastEvent = code == 200 ? "Notifica inviata." : "Il server ha risposto \(code)."
            return code == 200
        } catch {
            lastEvent = "Invio non riuscito: \(error.localizedDescription)"
            return false
        }
    }

    func sendTest() async {
        _ = await send(title: "Nod: prova", message: "Fai doppio tap sul Watch.",
                       buttons: [NtfyButton(label: "Ricevuta") { [weak self] in self?.lastEvent = "Doppio tap ricevuto." },
                                 NtfyButton(label: "Ignora") { [weak self] in self?.lastEvent = "Hai scelto Ignora." }])
    }

    // MARK: risposte

    func startListening() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            var delay: UInt64 = 2
            while !Task.isCancelled {
                await self?.listenOnce()
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                delay = min(delay * 2, 60)
            }
        }
    }

    func restartListening() {
        listenTask?.cancel()
        listenTask = nil
        isListening = false
        startListening()
    }

    private func listenOnce() async {
        guard let server = prefs.serverURL else { return }
        var request = URLRequest(url: server.appendingPathComponent(replyTopic).appendingPathComponent("json"))
        request.timeoutInterval = 24 * 3600
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { isListening = false; return }
            isListening = true
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["event"] as? String == "message", let token = json["message"] as? String else { continue }
                handle(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {}
        isListening = false
    }

    /// Un token vale una volta sola e fino alla sua scadenza; tutti i token della stessa notifica cadono insieme.
    private func handle(token: String) {
        guard let entry = pending[token] else { return }
        pending = pending.filter { $0.value.expires != entry.expires }
        guard entry.expires > Date() else { lastEvent = "Risposta arrivata dopo la scadenza: ignorata."; return }
        entry.action()
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
