// Movimento della testa dalle AirPods (Core Motion): indossate o no, assetto in tempo reale, annuire/scuotere, camminata.
// Gli assi (beccheggio = annuire, imbardata = scuotere) sono l'ipotesi del design: la prova M0 `spike/run.sh head` la verifica.

import CoreMotion
import Foundation

enum HeadGesture: String {
    case nod, shake
    var title: String { self == .nod ? L("Annuito") : L("Scosso la testa") }
}

/// Riconosce un'oscillazione su un asse: picchi di segno alternato oltre la soglia, entro una finestra di tempo.
struct OscillationDetector {
    var threshold = 0.9        // rad/s
    var window = 1.2           // s
    var minPeaks = 3
    private var peaks: [(t: Double, sign: Int)] = []
    private var current = 0
    private var cooldownUntil = 0.0

    mutating func feed(_ v: Double, at t: Double, dominant: Bool) -> Bool {
        let s = v > threshold ? 1 : (v < -threshold ? -1 : 0)
        if s != 0, s != current, peaks.last?.sign != s { peaks.append((t, s)) }
        current = s
        peaks.removeAll { t - $0.t > window }
        guard t >= cooldownUntil, dominant, peaks.count >= minPeaks else { return false }
        peaks.removeAll()
        cooldownUntil = t + 1.0
        return true
    }
}

/// Passi dall'accelerazione utente: 6 picchi in 4 s = cammini.
struct StepDetector {
    private var steps: [Double] = []
    private var last = 0.0
    private var above = false

    mutating func feed(magnitude: Double, at t: Double) -> Bool {
        if magnitude > 0.12, !above, t - last > 0.3 { steps.append(t); last = t }
        above = magnitude > 0.12
        steps.removeAll { t - $0 > 4 }
        return steps.count >= 6
    }
}

@MainActor
final class HeadMotionMonitor: NSObject, ObservableObject, CMHeadphoneMotionManagerDelegate {
    @Published private(set) var isConnected = false
    @Published private(set) var isRunning = false
    @Published private(set) var authorization = CMHeadphoneMotionManager.authorizationStatus()
    /// Assetto in radianti, per l'indicatore dal vivo.
    @Published private(set) var pitch = 0.0
    @Published private(set) var yaw = 0.0
    @Published private(set) var roll = 0.0
    @Published private(set) var lastGesture: (gesture: HeadGesture, at: Date)?
    @Published private(set) var isWalking = false
    @Published private(set) var lastDisconnect: Date?

    /// Chi aspetta un gesto (una richiesta di approvazione, la prova nella configurazione).
    var onGesture: ((HeadGesture) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private var nod = OscillationDetector()
    private var shake = OscillationDetector()
    private var steps = StepDetector()
    private var energy = [0.0, 0.0, 0.0]
    private var previous: (t: Double, a: [Double])?
    private var lastPublish = 0.0

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        manager.delegate = self
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { self?.handle(motion) }
        }
        isRunning = true
        authorization = CMHeadphoneMotionManager.authorizationStatus()
        diag(.airpods, "motion updates started, authorization \(authorization.rawValue)")
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in
            diag(.airpods, "connected")
            self.isConnected = true
            self.authorization = CMHeadphoneMotionManager.authorizationStatus()
        }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in
            diag(.airpods, "disconnected")
            self.isConnected = false
            self.isWalking = false
            self.lastDisconnect = Date()
        }
    }

    private func handle(_ m: CMDeviceMotion) {
        if !isConnected { isConnected = true }
        let t = m.timestamp
        let a = [m.attitude.pitch, m.attitude.yaw, m.attitude.roll]
        if let p = previous, t > p.t {
            var v = [0.0, 0.0, 0.0]
            for i in 0..<3 {
                var d = a[i] - p.a[i]
                if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                v[i] = d / (t - p.t)
                energy[i] = 0.85 * energy[i] + 0.15 * abs(v[i])
            }
            if nod.feed(v[0], at: t, dominant: energy[0] > 2 * max(energy[1], energy[2])) { report(.nod) }
            if shake.feed(v[1], at: t, dominant: energy[1] > 2 * max(energy[0], energy[2])) { report(.shake) }
        }
        previous = (t, a)

        let u = m.userAcceleration
        let walking = steps.feed(magnitude: (u.x * u.x + u.y * u.y + u.z * u.z).squareRoot(), at: t)
        if walking != isWalking { isWalking = walking }

        // L'indicatore non ha bisogno di più di 30 aggiornamenti al secondo.
        if t - lastPublish > 1.0 / 30 {
            pitch = a[0]; yaw = a[1]; roll = a[2]
            lastPublish = t
        }
    }

    private func report(_ g: HeadGesture) {
        lastGesture = (g, Date())
        onGesture?(g)
    }
}
