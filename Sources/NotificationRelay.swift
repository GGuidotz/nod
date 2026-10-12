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
    /// L'ultima volta che un pulsante di una notifica è tornato fino al Mac: prova che il percorso funziona.
    @Published private(set) var lastRoundTrip: Date?
    /// Per la diagnostica: l'ultimo invio e la verifica lato server.
    @Published private(set) var lastPublish: String?
    @Published private(set) var lastServerCheck: String?

    private let prefs: Preferences
    private var pending: [String: (expires: Date, action: @MainActor () -> Void)] = [:]
    private var listenTask: Task<Void, Never>?

    init(prefs: Preferences) { self.prefs = prefs }

    var replyTopic: String { prefs.topic + "-r" }
    var accessToken: String? { Keychain.read("ntfy-token").flatMap { $0.isEmpty ? nil : $0 } }
    /// L'indirizzo completo del topic, da incollare nell'app ntfy dell'iPhone.
    var subscribeURL: String { (prefs.serverURL?.absoluteString ?? "https://ntfy.sh") + "/" + prefs.topic }

    // MARK: invio

    /// Pubblica una notifica; i pulsanti (al massimo 3) restano validi per `lifetime` secondi.
    func send(title: String, message: String, buttons: [NtfyButton] = [], lifetime: TimeInterval = 120,
              priority: Int = 4) async -> Bool {
        guard let server = prefs.serverURL else {
            lastEvent = L("Indirizzo del server non valido (serve https).")
            diag(.ntfy, "publish skipped: invalid server URL")
            return false
        }
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
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let id = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["id"] as? String
            lastPublish = "\(DiagnosticsLog.stamp(Date())) HTTP \(code) priority \(priority) buttons \(buttons.count) id \(id ?? "-")"
            diag(.ntfy, "publish to \(server.host ?? "?"): HTTP \(code), id \(id ?? "-")")
            guard code == 200 else {
                lastEvent = L("Il server ha risposto %d.", code)
                return false
            }
            lastEvent = L("Notifica inviata.")
            if let id { Task { await verifyOnServer(id: id, server: server) } }
            return true
        } catch {
            lastEvent = L("Invio non riuscito: %@", error.localizedDescription)
            lastPublish = "\(DiagnosticsLog.stamp(Date())) error \(error.localizedDescription)"
            diag(.ntfy, "publish failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Chiede al server se ha davvero il messaggio: distingue "non parte dal Mac" da "l'iPhone non lo mostra".
    private func verifyOnServer(id: String, server: URL) async {
        var components = URLComponents(url: server.appendingPathComponent(prefs.topic).appendingPathComponent("json"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "poll", value: "1"), URLQueryItem(name: "since", value: "5m")]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let found = String(decoding: data, as: UTF8.self).contains("\"id\":\"\(id)\"")
            lastServerCheck = "\(DiagnosticsLog.stamp(Date())) HTTP \(code), message \(found ? "found" : "NOT found")"
            diag(.ntfy, "server check: HTTP \(code), message \(found ? "found" : "not found")")
            lastEvent = found ? L("Il server ha ricevuto la notifica. Se non la vedi sul Watch, il problema è sull'iPhone.")
                              : L("Il server non ha il messaggio (HTTP %d).", code)
        } catch {
            lastServerCheck = "\(DiagnosticsLog.stamp(Date())) error \(error.localizedDescription)"
            diag(.ntfy, "server check failed: \(error.localizedDescription)")
        }
    }

    func sendTest() async {
        _ = await send(title: L("Nod: prova"), message: L("Fai doppio tap sul Watch."),
                       buttons: [NtfyButton(label: L("Ricevuta")) { [weak self] in self?.lastEvent = L("Risposta ricevuta dal Watch.") },
                                 NtfyButton(label: L("Ignora")) { [weak self] in self?.lastEvent = L("Hai scelto Ignora.") }])
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
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                isListening = false
                diag(.ntfy, "listen: HTTP \(code)")
                return
            }
            isListening = true
            diag(.ntfy, "listening for replies on \(server.host ?? "?")")
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["event"] as? String == "message", let token = json["message"] as? String else { continue }
                handle(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            diag(.ntfy, "listen dropped: \(error.localizedDescription)")
        }
        isListening = false
    }

    /// Un token vale una volta sola e fino alla sua scadenza; tutti i token della stessa notifica cadono insieme.
    private func handle(token: String) {
        guard let entry = pending[token] else { return }
        pending = pending.filter { $0.value.expires != entry.expires }
        guard entry.expires > Date() else {
            lastEvent = L("Risposta arrivata dopo la scadenza: ignorata.")
            diag(.ntfy, "reply after expiry ignored")
            return
        }
        lastRoundTrip = Date()
        diag(.ntfy, "reply received (round trip ok)")
        entry.action()
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
