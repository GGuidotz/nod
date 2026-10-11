// SensorProbe: prove M0 dello spin-off. Una piccola app senza finestra con tre modalità:
//   head  [picchi]   movimento della testa dalle AirPods: indossate/tolte, annuire/scuotere/inclinare, camminata
//   watch [motivo]   conferma col tasto laterale dell'Apple Watch (LocalAuthentication)
//   stem  [mic|audio] click sullo stelo come comandi multimediali (e gesto muto con "mic")
// Si compila con build.sh e si avvia con run.sh (serve un bundle .app per i permessi di macOS).

import AppKit
import AVFAudio
import CoreMotion
import Foundation
import LocalAuthentication
import MediaPlayer

func ts() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}

@main
struct SensorProbe {
    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        let args = Array(CommandLine.arguments.dropFirst())
        let mode = args.first ?? "help"
        let rest = Array(args.dropFirst())
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        switch mode {
        case "head": HeadProbe.shared.start(minPeaks: rest.first.flatMap(Int.init) ?? 3)
        case "watch": WatchProbe.run(reason: rest.joined(separator: " "))
        case "stem": StemProbe.shared.start(options: Set(rest))
        default:
            print("""
            uso: run.sh head [picchi]     movimento testa (picchi per gesto, default 3)
                 run.sh watch [motivo]    conferma col tasto laterale del Watch
                 run.sh stem [mic] [audio] click sullo stelo
            """)
            exit(0)
        }
        app.run()
    }
}

// MARK: - head

/// Riconosce un'oscillazione su un asse: picchi di segno alternato oltre la soglia, entro una finestra di tempo.
struct OscillationDetector {
    let label: String
    var threshold = 0.9        // rad/s
    var window = 1.2           // s
    var minPeaks = 3
    var peaks: [(t: Double, sign: Int)] = []
    var current = 0
    var cooldownUntil = 0.0

    init(_ label: String) { self.label = label }

    /// Restituisce il numero di picchi quando riconosce un gesto, altrimenti nil.
    mutating func feed(_ v: Double, at t: Double, dominant: Bool) -> Int? {
        let s = v > threshold ? 1 : (v < -threshold ? -1 : 0)
        if s != 0, s != current, peaks.last?.sign != s { peaks.append((t, s)) }
        current = s
        peaks.removeAll { t - $0.t > window }
        guard t >= cooldownUntil, dominant, peaks.count >= minPeaks else { return nil }
        let n = peaks.count
        peaks.removeAll()
        cooldownUntil = t + 1.0
        return n
    }
}

final class HeadProbe: NSObject, CMHeadphoneMotionManagerDelegate {
    static let shared = HeadProbe()
    let manager = CMHeadphoneMotionManager()
    var detectors = [OscillationDetector("pitch (beccheggio)"), OscillationDetector("yaw (imbardata)"),
                     OscillationDetector("roll (rollio)")]
    var energy = [0.0, 0.0, 0.0]
    var previous: (t: Double, a: [Double])?
    var samples = 0
    var sampleWindowStart = 0.0
    var steps: [Double] = []
    var lastStep = 0.0
    var aboveStep = false
    var walking = false

    func start(minPeaks: Int) {
        for i in detectors.indices { detectors[i].minPeaks = minPeaks }
        let status = CMHeadphoneMotionManager.authorizationStatus()
        print("Permesso movimento: \(status.rawValue) (0 da chiedere, 1 limitato, 2 negato, 3 concesso)")
        manager.delegate = self
        guard manager.isDeviceMotionAvailable else {
            print("Movimento delle cuffie non disponibile su questo Mac.")
            exit(1)
        }
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error { print(ts(), "Errore:", error.localizedDescription); return }
            if let motion { self?.handle(motion) }
        }
        print("In ascolto (gesto = \(minPeaks) picchi). Indossa le AirPods, poi: annuisci, scuoti, inclina, alzati e cammina.")
        print("Annota quale asse risponde a ciascun gesto. Ctrl-C per uscire.")
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        print(ts(), "AirPods CONNESSE (indossate)")
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        print(ts(), "AirPods DISCONNESSE (tolte o fuori portata)")
    }

    func handle(_ m: CMDeviceMotion) {
        let t = m.timestamp
        let a = [m.attitude.pitch, m.attitude.yaw, m.attitude.roll]

        samples += 1
        if sampleWindowStart == 0 { sampleWindowStart = t }
        if t - sampleWindowStart >= 10 {
            print(ts(), String(format: "frequenza: %.0f Hz", Double(samples) / (t - sampleWindowStart)))
            samples = 0
            sampleWindowStart = t
        }

        if let p = previous, t > p.t {
            let dt = t - p.t
            var v = [0.0, 0.0, 0.0]
            for i in 0..<3 {
                var d = a[i] - p.a[i]
                if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                v[i] = d / dt
                energy[i] = 0.85 * energy[i] + 0.15 * abs(v[i])
            }
            for i in 0..<3 {
                let others = (0..<3).filter { $0 != i }.map { energy[$0] }.max() ?? 0
                let dominant = energy[i] > 2 * others
                if let n = detectors[i].feed(v[i], at: t, dominant: dominant) {
                    print(ts(), "GESTO sull'asse \(detectors[i].label): \(n) picchi",
                          String(format: "(energia p/y/r %.2f %.2f %.2f)", energy[0], energy[1], energy[2]))
                }
            }
        }
        previous = (t, a)

        // Passi: picchi dell'accelerazione utente (in g).
        let u = m.userAcceleration
        let mag = (u.x * u.x + u.y * u.y + u.z * u.z).squareRoot()
        if mag > 0.12, !aboveStep, t - lastStep > 0.3 {
            steps.append(t)
            lastStep = t
        }
        aboveStep = mag > 0.12
        steps.removeAll { t - $0 > 4 }
        let nowWalking = steps.count >= 6
        if nowWalking != walking {
            walking = nowWalking
            print(ts(), walking ? "CAMMINATA iniziata (\(steps.count) passi in 4 s)" : "camminata finita")
        }
    }
}

// MARK: - watch

enum WatchProbe {
    static let context = LAContext()   // tenuto vivo fino alla risposta

    static func run(reason: String) {
        var policies: [(String, LAPolicy)] = [("solo Watch", .deviceOwnerAuthenticationWithWatch),
                                              ("Touch ID o Watch", .deviceOwnerAuthenticationWithBiometricsOrWatch)]
        if #available(macOS 15.0, *) { policies.append(("companion", .deviceOwnerAuthenticationWithCompanion)) }
        for (name, policy) in policies {
            var error: NSError?
            let ok = LAContext().canEvaluatePolicy(policy, error: &error)
            print("Disponibile \(name): \(ok ? "si" : "no") \(error.map { "(\($0.code) \($0.localizedDescription))" } ?? "")")
        }
        let text = reason.isEmpty ? "approvare una richiesta di prova" : reason
        print(ts(), "Richiesta inviata: sul Watch premi due volte il tasto laterale.")
        let start = Date()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithWatch, localizedReason: text) { ok, error in
            let elapsed = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                let detail = error.map { " (\(($0 as NSError).code) \($0.localizedDescription))" } ?? ""
                print(ts(), String(format: "Risultato: %@ in %.1f s", ok ? "CONFERMATO" : "NON confermato", elapsed) + detail)
                exit(ok ? 0 : 2)
            }
        }
    }
}

// MARK: - stem

final class StemProbe: NSObject {
    static let shared = StemProbe()
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()

    func start(options: Set<String>) {
        let center = MPRemoteCommandCenter.shared()
        func listen(_ command: MPRemoteCommand, _ name: String) {
            command.isEnabled = true
            command.addTarget { _ in
                print(ts(), "STELO:", name)
                return .success
            }
        }
        listen(center.togglePlayPauseCommand, "play/pausa (click singolo)")
        listen(center.playCommand, "play")
        listen(center.pauseCommand, "pausa")
        listen(center.nextTrackCommand, "avanti (doppio click)")
        listen(center.previousTrackCommand, "indietro (triplo click)")

        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = [MPMediaItemPropertyTitle: "SensorProbe: modalità comando",
                               MPNowPlayingInfoPropertyPlaybackRate: 1.0]
        info.playbackState = .playing

        if options.contains("mic") { openMicrophone() }
        if options.contains("audio") { playSilence() }
        print("In ascolto. Premi lo stelo una, due, tre volte. Prova con e senza musica in un'altra app. Ctrl-C per uscire.")
    }

    /// Alcune versioni di macOS assegnano i tasti multimediali solo a chi sta davvero riproducendo audio.
    func playSilence() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100) else { return }
        buffer.frameLength = 44_100
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            print("Riproduco silenzio per diventare l'app In riproduzione.")
        } catch {
            print("Audio non avviato:", error.localizedDescription)
        }
    }

    /// Il gesto muto arriva solo mentre l'app usa il microfono. Attenzione: sulle AirPods passa l'audio in modalità chiamata.
    func openMicrophone() {
        do {
            try AVAudioApplication.shared.setInputMuteStateChangeHandler { muted in
                print(ts(), "STELO (gesto muto):", muted ? "muto" : "non muto")
                return true
            }
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { _, _ in }
            if !engine.isRunning { try engine.start() }
            print("Microfono aperto: prova il click singolo come gesto muto.")
        } catch {
            print("Microfono non avviato:", error.localizedDescription)
        }
    }
}
