// Il flusso di un'approvazione. Sceglie da solo come chiedertela:
//   AirPods indossate → suono (e riassunto parlato, se lo vuoi), 15 s per un gesto: annuisci → conferma sul Watch,
//                       scuoti → Nega subito (negare non esegue nulla).
//   Conferma sul Watch → la notifica ntfy con Approva / Nega, se attivo il promemoria "Approva: …" (completarlo dal
//                       Watch = Approva) e la richiesta di sistema col doppio clic (sperimentale). La prima risposta
//                       vince e chiude le altre. Dalla 0.4.1 anche dopo il cenno, perché le conferme servono lontano dal Mac.
// Doppio clic sperimentale: su macOS 27 il sistema risponde "annullato" (userCancel) anche al doppio clic, lo stesso codice
// di Nega. Finché Apple non lo corregge, un "annullato" della richiesta di sistema non nega: per negare c'è ntfy o il gesto.
// "Consenti sempre" non c'è mai. Finché le richieste vere dell'AI non sono collegate a Cocaine gira in modalità prova.

import AppKit
import AVFoundation
import Foundation

@MainActor
final class ApprovalFlow: ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForGesture(summary: String, until: Date)
        case confirmingOnWatch(summary: String, alsoNotified: Bool)
        case approved(summary: String, by: String)
        case denied(summary: String, by: String)
        case expired(summary: String)
        case failed(summary: String, reason: String)

        var isFinal: Bool {
            switch self {
            case .approved, .denied, .expired, .failed: true
            default: false
            }
        }
    }

    @Published private(set) var phase = Phase.idle

    private let head: HeadMotionMonitor
    private let watch: WatchConfirmer
    private let relay: NotificationRelay
    private let reminders: ReminderRelay
    private let prefs: Preferences
    private let speech = AVSpeechSynthesizer()
    private var windowTask: Task<Void, Never>?
    private var completion: ((Bool) -> Void)?
    /// Cambia a ogni richiesta: risposte tardive di una richiesta vecchia vengono ignorate.
    private var generation = 0
    /// L'avviso di Promemoria della richiesta in corso, da cancellare alla fine.
    private var reminderID: String?

    static let gestureWindow: TimeInterval = 15
    static let watchWindow: TimeInterval = 300

    init(head: HeadMotionMonitor, watch: WatchConfirmer, relay: NotificationRelay, reminders: ReminderRelay, prefs: Preferences) {
        self.head = head
        self.watch = watch
        self.relay = relay
        self.reminders = reminders
        self.prefs = prefs
    }

    var usesGestures: Bool { prefs.headMotionEnabled && head.isConnected }

    /// Chiede un'approvazione. `completion(allow)` riceve la decisione; non viene chiamata se scade o fallisce.
    func ask(_ summary: String, completion: ((Bool) -> Void)? = nil) {
        cancel()
        generation += 1
        self.completion = completion
        NSSound(named: "Glass")?.play()
        if usesGestures {
            askWithGestures(summary)
        } else {
            askOnWatch(summary, notify: true)
        }
    }

    func demo() { ask(L("Prova: Claude vuole eseguire npm test nel progetto di esempio.")) }

    func cancel() {
        windowTask?.cancel()
        head.onGesture = nil
        watch.cancel()
        reminders.clear(reminderID)
        reminderID = nil
        completion = nil
        phase = .idle
    }

    // MARK: AirPods + Watch

    private func askWithGestures(_ summary: String) {
        phase = .waitingForGesture(summary: summary, until: Date().addingTimeInterval(Self.gestureWindow))
        if prefs.speakSummaries {
            let utterance = AVSpeechUtterance(string: summary)
            utterance.voice = AVSpeechSynthesisVoice(language: "it-IT")
            speech.speak(utterance)
        }
        let gen = generation
        head.onGesture = { [weak self] gesture in self?.received(gesture, summary: summary, generation: gen) }
        windowTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.gestureWindow * 1_000_000_000))
            guard !Task.isCancelled, let self, self.generation == gen, case .waitingForGesture = self.phase else { return }
            self.head.onGesture = nil
            self.finish(.expired(summary: summary), allow: nil, generation: gen)
        }
    }

    private func received(_ gesture: HeadGesture, summary: String, generation gen: Int) {
        guard gen == generation, case .waitingForGesture = phase else { return }
        windowTask?.cancel()
        head.onGesture = nil
        switch gesture {
        case .shake: finish(.denied(summary: summary, by: L("scuotendo la testa")), allow: false, generation: gen)
        case .nod: askOnWatch(summary, notify: true)
        }
    }

    // MARK: Watch (da solo o dopo il cenno)

    private func askOnWatch(_ summary: String, notify: Bool) {
        let gen = generation
        phase = .confirmingOnWatch(summary: summary, alsoNotified: notify)
        if notify {
            let approve = NtfyButton(label: L("Approva")) { [weak self] in
                self?.decide(.approved(summary: summary, by: L("dalla notifica sul Watch")), allow: true, generation: gen)
            }
            let deny = NtfyButton(label: L("Nega")) { [weak self] in
                self?.decide(.denied(summary: summary, by: L("dalla notifica sul Watch")), allow: false, generation: gen)
            }
            Task { _ = await relay.send(title: L("Nod: approvazione"), message: summary, buttons: [approve, deny],
                                        lifetime: Self.watchWindow, priority: 5) }
            reminderID = reminders.ask(title: L("Approva: %@", summary),
                                       notes: L("Completalo dal Watch per approvare. Per negare: Nega al Mac o nella notifica ntfy; senza risposta non succede nulla."),
                                       lifetime: Self.watchWindow) { [weak self] in
                self?.decide(.approved(summary: summary, by: L("dal promemoria sul Watch")), allow: true, generation: gen)
            }
        }
        Task {
            let outcome = await watch.confirm(L("approvare: %@", summary))
            guard gen == generation, !phase.isFinal else { return }
            switch outcome {
            case .confirmed: finish(.approved(summary: summary, by: L("col tasto laterale del Watch")), allow: true, generation: gen)
            case .denied where notify:
                // Su macOS 27 il doppio clic torna come userCancel, come Nega: non vale come decisione (vedi in cima).
                diag(.watch, "system prompt answered cancel: ignored, waiting for ntfy or the reminder")
            case .denied: finish(.denied(summary: summary, by: L("con Nega")), allow: false, generation: gen)
            case .interrupted(let why), .unavailable(let why):
                // Con la notifica in giro la decisione può ancora arrivare da lì.
                if !notify { finish(.failed(summary: summary, reason: why), allow: nil, generation: gen) }
            }
        }
        if notify {
            windowTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.watchWindow * 1_000_000_000))
                guard !Task.isCancelled, let self, self.generation == gen, !self.phase.isFinal else { return }
                self.watch.cancel()
                self.finish(.expired(summary: summary), allow: nil, generation: gen)
            }
        }
    }

    /// Una risposta dalla notifica: chiude la richiesta di sistema ancora aperta.
    private func decide(_ final: Phase, allow: Bool, generation gen: Int) {
        guard gen == generation, !phase.isFinal else { return }
        windowTask?.cancel()
        watch.cancel()
        finish(final, allow: allow, generation: gen)
    }

    private func finish(_ final: Phase, allow: Bool?, generation gen: Int) {
        guard gen == generation else { return }
        reminders.clear(reminderID)
        reminderID = nil
        phase = final
        if let allow { completion?(allow) }
        completion = nil
    }
}
