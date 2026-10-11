// Configurazione guidata. Al primo avvio: tutti i passaggi. A ogni aggiornamento: prima le novità, poi solo i passaggi
// introdotti dopo l'ultima versione che hai visto (un nuovo permesso, una nuova funzione), poi la fine.
// Si riapre da Nod > Ripeti configurazione. Ogni passaggio si prova davvero: annuire, la conferma sul Watch, la notifica.

import ServiceManagement
import SwiftUI

enum SetupStep: String, CaseIterable, Identifiable {
    case welcome, whatsNew, cocaine, airpods, watch, notifications, presence, done
    var id: String { rawValue }

    /// La versione che ha introdotto il passaggio: dopo un aggiornamento compaiono solo quelli più nuovi di ciò che hai visto.
    var introducedIn: String {
        switch self {
        default: "0.1.0"
        }
    }

    static let full: [SetupStep] = [.welcome, .cocaine, .airpods, .watch, .notifications, .presence, .done]
}

struct SetupSession: Identifiable {
    enum Kind: Equatable {
        case full
        case update(from: String)
    }

    let id = UUID()
    let kind: Kind
    let steps: [SetupStep]
    let news: [ChangelogEntry]

    init(kind: Kind, currentVersion: String) {
        self.kind = kind
        switch kind {
        case .full:
            steps = SetupStep.full
            news = []
        case .update(let from):
            news = Changelog.entries(after: from, upTo: currentVersion, in: Changelog.load())
            let added = SetupStep.full.filter { $0 != .welcome && $0 != .done && Version($0.introducedIn) > Version(from) }
            steps = [.whatsNew] + added + [.done]
        }
    }
}

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    let session: SetupSession
    @State private var index = 0

    private var step: SetupStep { session.steps[index] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
            }
            Divider()
            footer.padding(16)
        }
        .frame(width: 600, height: 560)
        .interactiveDismissDisabled()
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: WelcomeStep()
        case .whatsNew: WhatsNewStep(entries: session.news)
        case .cocaine: CocaineStep(cocaine: model.cocaine)
        case .airpods: AirPodsStep(head: model.head, prefs: model.prefs)
        case .watch: WatchStep(watch: model.watch)
        case .notifications: NotificationsStep(prefs: model.prefs, relay: model.relay)
        case .presence: PresenceStep(prefs: model.prefs)
        case .done: DoneStep()
        }
    }

    private var footer: some View {
        HStack {
            Text("Passo \(index + 1) di \(session.steps.count)")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            if step == .welcome {
                Button("Configura più tardi") { model.finishSetup() }
            } else if index > 0 {
                Button("Indietro") { index -= 1 }
            }
            Button(step == .done ? "Inizia a usare Nod" : "Continua") {
                if step == .done { model.finishSetup() } else { index += 1 }
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Passaggi

private struct StepHeader: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title).font(.largeTitle.weight(.semibold))
            Text(subtitle).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 20)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "airpodspro", title: "Benvenuto in Nod",
                       subtitle: "Approva le richieste dell'AI con un cenno della testa e lascia la scrivania senza pensarci: "
                           + "Nod parla con Cocaine, le tue AirPods e il tuo Apple Watch.")
            Label("Annuisci per approvare, confermi col tasto laterale del Watch.", systemImage: "checkmark.seal")
            Label("Scuoti la testa per negare.", systemImage: "xmark.seal")
            Label("Quando ti allontani, il Watch ti chiede se tenere sveglio il Mac.", systemImage: "figure.walk")
            Text("Ci vogliono un paio di minuti. Ogni passaggio si prova subito.")
                .foregroundStyle(.secondary).padding(.top, 8)
        }
    }
}

struct WhatsNewStep: View {
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "sparkles", title: "Novità", subtitle: "Cosa è cambiato dall'ultima volta che hai aperto Nod.")
            if entries.isEmpty {
                Text("Piccole correzioni e miglioramenti.").foregroundStyle(.secondary)
            }
            ChangelogList(entries: entries)
        }
    }
}

struct ChangelogList: View {
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Versione \(entry.version)").font(.headline)
                        Text(entry.date).font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(entry.items, id: \.self) { item in
                        Label(item, systemImage: "circle.fill")
                            .labelStyle(BulletLabelStyle())
                    }
                }
            }
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary).accessibilityHidden(true)
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CocaineStep: View {
    @ObservedObject var cocaine: CocaineBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "powersleep", title: "Cocaine",
                       subtitle: "Nod usa Cocaine per tenere sveglio il Mac e, in futuro, per le approvazioni dell'AI.")
            Form {
                StatusRow(title: "Installato", value: cocaine.isInstalled ? "Versione \(cocaine.version ?? "?")" : "Non trovato",
                          ok: cocaine.isInstalled)
                StatusRow(title: "Approvazioni dall'AI", value: cocaine.approvalsAvailable ? "Disponibili" : "In arrivo",
                          ok: cocaine.approvalsAvailable)
            }
            .formStyle(.grouped)
            if !cocaine.isInstalled {
                Text("Installalo con: brew install --cask mattiakart/tap/cocaine")
                    .font(.body.monospaced()).textSelection(.enabled)
            }
            if !cocaine.approvalsAvailable {
                Text("Le richieste vere dell'AI non sono ancora collegate a Cocaine. Intanto Nod gestisce la presenza e puoi provare i gesti.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Button("Controlla di nuovo") { cocaine.refresh() }
        }
        .onAppear { cocaine.refresh() }
    }
}

private struct AirPodsStep: View {
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var prefs: Preferences
    @State private var tried: HeadGesture?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "airpodspro", title: "AirPods",
                       subtitle: "Nod legge il movimento della testa dalle AirPods per riconoscere quando annuisci, scuoti la testa o ti alzi e cammini.")
            if !head.isRunning {
                // Prima della richiesta di sistema: un solo pulsante, che la apre (HIG, Privacy).
                Text("Al prossimo passo macOS ti chiede il permesso Movimento e fitness. I dati restano su questo Mac.")
                    .fixedSize(horizontal: false, vertical: true)
                Button("Continua") { prefs.headMotionEnabled = true; head.start() }
                    .controlSize(.large)
            } else {
                HStack(alignment: .center, spacing: 24) {
                    HeadIndicator(head: head, size: 120)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(head.isConnected ? "Indossale e prova: annuisci due o tre volte, poi scuoti la testa."
                                              : "Indossa le AirPods: l'immagine seguirà la tua testa.")
                            .fixedSize(horizontal: false, vertical: true)
                        if let tried {
                            Label(tried.title + ": riconosciuto.", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .onReceive(head.$lastGesture) { g in if let g { tried = g.gesture } }
    }
}

private struct WatchStep: View {
    @ObservedObject var watch: WatchConfirmer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "applewatch.side.right", title: "Apple Watch",
                       subtitle: "Ogni approvazione si conferma premendo due volte il tasto laterale del Watch, come per sbloccare il Mac.")
            StatusRow(title: "Watch vicino e sbloccato", value: watch.isAvailable ? "Pronto" : (watch.unavailableReason ?? "Non pronto"),
                      ok: watch.isAvailable)
            if !watch.isAvailable {
                Text("Attiva Impostazioni di Sistema > Touch ID e password > Apple Watch, poi riprova.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Button(watch.isAsking ? "Guarda il Watch…" : "Prova la conferma") {
                Task { _ = await watch.confirm("provare la conferma con Apple Watch") }
            }
            .disabled(watch.isAsking)
            if let outcome = watch.lastOutcome {
                switch outcome {
                case .confirmed(let s):
                    Label(String(format: "Confermato in %.1f s.", s), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .refused(let why):
                    Label(why, systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                }
            }
        }
        .onAppear { watch.refresh() }
    }
}

private struct NotificationsStep: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var relay: NotificationRelay

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "applewatch.radiowaves.left.and.right", title: "Notifiche sul Watch",
                       subtitle: "Quando sei lontano, Nod ti scrive sul Watch tramite l'app ntfy dell'iPhone. Doppio tap = primo pulsante.")
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Installa ntfy sull'iPhone dall'App Store.")
                Text("2. In ntfy tocca +, incolla il topic qui sotto e, se usi un server tuo, il suo indirizzo.")
                Text("3. Invia la prova e fai doppio tap sul Watch.")
            }
            Form { ServerSettingsSection(prefs: prefs, relay: relay) }
                .formStyle(.grouped)
                .frame(minHeight: 220)
            HStack {
                Button("Invia notifica di prova") { Task { await relay.sendTest() } }
                if let event = relay.lastEvent { Text(event).foregroundStyle(.secondary) }
            }
        }
    }
}

private struct PresenceStep: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "figure.walk", title: "Quando ti allontani",
                       subtitle: "Il Watch ti chiede cosa fare. Se non rispondi, vale questa regola.")
            Form { PresenceRuleEditor(prefs: prefs) }
                .formStyle(.grouped)
                .frame(minHeight: 380)
        }
    }
}

private struct DoneStep: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(symbol: "checkmark.circle", title: "Tutto pronto",
                       subtitle: "Nod resta nella barra dei menu. La finestra si riapre da lì, e questa configurazione da Nod > Ripeti configurazione.")
            Toggle("Apri Nod all'accesso", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    do {
                        if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                }
            if let loginError { Text(loginError).foregroundStyle(.orange) }
        }
    }
}
