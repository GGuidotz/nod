// Il flusso di un'approvazione. Sceglie da solo come chiedertela:
//   AirPods indossate → suono (e riassunto parlato, se lo vuoi), 15 s per un gesto: annuisci → conferma sul Watch,
//                       scuoti → Nega subito (negare non esegue nulla).
//   Senza AirPods     → subito la richiesta sul Watch (doppio clic = Approva, Nega = Nega) e insieme la notifica sul Watch
//                       con Approva / Nega. La prima risposta vince e chiude l'altra.
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
    private let prefs: Preferences
    private let speech = AVSpeechSynthesizer()
    private var windowTask: Task<Void, Never>?
    private var completion: ((Bool) -> Void)?
    /// Cambia a ogni richiesta: risposte tardive di una richiesta vecchia vengono ignorate.
    private var generation = 0

    static let gestureWindow: TimeInterval = 15
    static let watchWindow: TimeInterval = 120

    init(head: HeadMotionMonitor, watch: WatchConfirmer, relay: NotificationRelay, prefs: Preferences) {
        self.head = head
        self.watch = watch
        self.relay = relay
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
        case .nod: askOnWatch(summary, notify: false)
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
        }
        Task {
            let outcome = await watch.confirm(L("approvare: %@", summary))
            guard gen == generation, !phase.isFinal else { return }
            switch outcome {
            case .confirmed: finish(.approved(summary: summary, by: L("col tasto laterale del Watch")), allow: true, generation: gen)
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
        phase = final
        if let allow { completion?(allow) }
        completion = nil
    }
}
