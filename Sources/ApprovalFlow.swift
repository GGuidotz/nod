// Il flusso di un'approvazione al Mac: suono (e riassunto parlato, se lo vuoi), 15 s per un gesto,
// annuire → conferma col tasto laterale del Watch → approvata; scuotere → negata subito (negare non esegue nulla).
// Finché le richieste vere dell'AI non sono collegate a Cocaine gira in modalità prova: stesso flusso, nessuna richiesta vera.

import AppKit
import AVFoundation
import Foundation

@MainActor
final class ApprovalFlow: ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForGesture(summary: String, until: Date)
        case confirmingOnWatch(summary: String)
        case approved(summary: String)
        case denied(summary: String)
        case expired(summary: String)
        case failed(summary: String, reason: String)
    }

    @Published private(set) var phase = Phase.idle

    private let head: HeadMotionMonitor
    private let watch: WatchConfirmer
    private let prefs: Preferences
    private let speech = AVSpeechSynthesizer()
    private var windowTask: Task<Void, Never>?
    private var completion: ((Bool, String?) -> Void)?

    static let gestureWindow: TimeInterval = 15

    init(head: HeadMotionMonitor, watch: WatchConfirmer, prefs: Preferences) {
        self.head = head
        self.watch = watch
        self.prefs = prefs
    }

    /// Apre la finestra dei gesti per una richiesta. `completion(allow, reason)` riceve l'esito; nil se scade.
    func ask(_ summary: String, completion: ((Bool, String?) -> Void)? = nil) {
        cancel()
        self.completion = completion
        phase = .waitingForGesture(summary: summary, until: Date().addingTimeInterval(Self.gestureWindow))
        NSSound(named: "Glass")?.play()
        if prefs.speakSummaries {
            let utterance = AVSpeechUtterance(string: summary)
            utterance.voice = AVSpeechSynthesisVoice(language: "it-IT")
            speech.speak(utterance)
        }
        if !head.isRunning { head.start() }
        head.onGesture = { [weak self] gesture in self?.received(gesture, summary: summary) }
        windowTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.gestureWindow * 1_000_000_000))
            guard !Task.isCancelled, let self, case .waitingForGesture = self.phase else { return }
            self.finish(.expired(summary: summary), allow: nil)
        }
    }

    func demo() { ask("Prova: Claude vuole eseguire npm test nel progetto di esempio.") }

    func cancel() {
        windowTask?.cancel()
        head.onGesture = nil
        phase = .idle
    }

    private func received(_ gesture: HeadGesture, summary: String) {
        guard case .waitingForGesture = phase else { return }
        windowTask?.cancel()
        head.onGesture = nil
        switch gesture {
        case .shake:
            finish(.denied(summary: summary), allow: false)
        case .nod:
            phase = .confirmingOnWatch(summary: summary)
            Task {
                switch await watch.confirm("approvare: \(summary)") {
                case .confirmed: finish(.approved(summary: summary), allow: true)
                case .refused(let why): finish(.failed(summary: summary, reason: why), allow: nil)
                }
            }
        }
    }

    private func finish(_ final: Phase, allow: Bool?) {
        phase = final
        if let allow { completion?(allow, nil) }
        completion = nil
    }
}
