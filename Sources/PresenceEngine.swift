// Presenza: capisce quando ti allontani dal Mac e ti chiede sul Watch cosa fare.
//   al Mac ──(inattivo ≥ N s E (cammini con le AirPods O AirPods scollegate da poco O schermo bloccato))──> in uscita
//   in uscita ──(tua risposta, o la regola dopo il tempo di attesa)──> via
//   via / in uscita ──(input, sblocco)──> al Mac, e Cocaine torna com'era se l'aveva acceso Nod
// Senza risposta vale la regola: tieni sveglio se una delle app scelte è aperta ed è la tua fascia oraria, altrimenti niente.

import AppKit
import Foundation
import IOKit

enum PresenceState: String {
    case here, leaving, away

    var title: String {
        switch self {
        case .here: "Al Mac"
        case .leaving: "In uscita"
        case .away: "Lontano"
        }
    }

    var symbol: String {
        switch self {
        case .here: "airpodspro"
        case .leaving: "figure.walk.motion"
        case .away: "figure.walk"
        }
    }
}

@MainActor
final class PresenceEngine: ObservableObject {
    @Published private(set) var state = PresenceState.here
    @Published private(set) var decision: LeavingAction?
    @Published private(set) var since = Date()
    @Published private(set) var log: [(date: Date, text: String)] = []

    weak var relay: NotificationRelay?
    private let prefs: Preferences
    private let head: HeadMotionMonitor
    private let cocaine: CocaineBridge
    private var timer: Timer?
    private var timeoutTask: Task<Void, Never>?
    private var screenLocked = false
    private var nodTurnedCocaineOn = false
    private var observers: [NSObjectProtocol] = []

    init(prefs: Preferences, head: HeadMotionMonitor, cocaine: CocaineBridge) {
        self.prefs = prefs
        self.head = head
        self.cocaine = cocaine
    }

    func start() {
        guard timer == nil else { return }
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = true; self?.tick() }
        })
        observers.append(center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = false; self?.tick() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let idle = Self.idleSeconds()
        switch state {
        case .here:
            let recentlyDisconnected = head.lastDisconnect.map { Date().timeIntervalSince($0) < 120 } ?? false
            if idle >= Double(prefs.leavingIdleSeconds), head.isWalking || recentlyDisconnected || screenLocked {
                markLeaving(manual: false)
            }
        case .leaving, .away:
            if idle < 3, !screenLocked { markHere(manual: false) }
        }
    }

    func markLeaving(manual: Bool) {
        guard state == .here else { return }
        state = .leaving
        since = Date()
        decision = nil
        note(manual ? "Hai detto che stai uscendo." : "Ti stai allontanando.")

        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let rule = prefs.leavingRule
        let fallback = rule.defaultAction(now: Date(), running: running)
        let buttons = rule.buttons(now: Date(), running: running, stayOnlineAvailable: cocaine.approvalsAvailable)
            .map { action in NtfyButton(label: action.title) { [weak self] in self?.apply(action, answered: true) } }
        let minutes = rule.timeoutMinutes
        Task {
            _ = await relay?.send(title: "Ti stai allontanando",
                                  message: "Senza risposta tra \(minutes) min: \(fallback.title.lowercased()).",
                                  buttons: buttons, lifetime: TimeInterval(minutes * 60), priority: 5)
        }
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled, let self, self.state == .leaving else { return }
            self.apply(fallback, answered: false)
        }
    }

    func markHere(manual: Bool) {
        guard state != .here else { return }
        timeoutTask?.cancel()
        state = .here
        since = Date()
        note(manual ? "Hai detto che sei al Mac." : "Sei tornato al Mac.")
        if nodTurnedCocaineOn {
            nodTurnedCocaineOn = false
            Task { await cocaine.stopKeepingAwake(); note("Cocaine spento, com'era prima.") }
        }
    }

    private func apply(_ action: LeavingAction, answered: Bool) {
        guard state == .leaving else { return }
        timeoutTask?.cancel()
        decision = action
        state = .away
        note((answered ? "Hai scelto: " : "Nessuna risposta, regola: ") + action.title + ".")
        switch action {
        case .keepAwake:
            Task {
                await cocaine.refreshStatus()
                guard cocaine.status?.on != true else { return }
                if await cocaine.keepAwake() { nodTurnedCocaineOn = true; note("Cocaine acceso.") }
            }
        case .stayOnline:
            note("Resta online non è ancora collegato a Cocaine.")
        case .nothing:
            break
        }
    }

    private func note(_ text: String) {
        log.insert((Date(), text), at: 0)
        if log.count > 50 { log.removeLast() }
    }

    /// Secondi dall'ultimo input (tastiera, mouse, trackpad), dal sistema HID.
    static func idleSeconds() -> Double {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else { return 0 }
        return value.doubleValue / 1_000_000_000
    }
}
