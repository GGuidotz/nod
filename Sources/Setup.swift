// Configurazione guidata. Al primo avvio: tutti i passaggi. A ogni aggiornamento: prima le novità, poi solo i passaggi
// introdotti dopo l'ultima versione che hai visto (un nuovo permesso, una nuova funzione), poi la fine.
// Si riapre da Nod > Ripeti configurazione. Ogni passaggio si prova davvero: annuire, la conferma sul Watch, la notifica.
// Grafica: aurora nel livello del contenuto, schede di materiale standard, una sola barra di vetro in basso con i passi,
// Indietro e Continua (HIG, Liquid Glass: il vetro solo sui controlli che galleggiano).

import ServiceManagement
import SwiftUI

enum SetupStep: String, CaseIterable, Identifiable {
    case welcome, whatsNew, cocaine, airpods, watch, notifications, presence, appearance, done
    var id: String { rawValue }

    /// La versione che ha introdotto il passaggio: dopo un aggiornamento compaiono solo quelli più nuovi di ciò che hai visto.
    var introducedIn: String {
        switch self {
        case .notifications, .appearance: "0.2.0"
        default: "0.1.0"
        }
    }

    static let full: [SetupStep] = [.welcome, .cocaine, .airpods, .watch, .notifications, .presence, .appearance, .done]
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
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var step: SetupStep { session.steps[index] }

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    content
                        .id(step)
                        .transition(transition)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                        .padding(.top, 36)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.never)
                bottomBar
            }
        }
        .frame(width: 760, height: 600)
        .interactiveDismissDisabled()
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
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
        case .appearance: AppearanceStep(prefs: model.prefs)
        case .done: DoneStep(model: model)
        }
    }

    /// L'unica superficie di vetro: passi, Indietro, Continua.
    private var bottomBar: some View {
        GlassGroup {
            HStack(spacing: 14) {
                StepDots(count: session.steps.count, current: index)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glassSurface(in: Capsule())
                Spacer()
                if step == .welcome {
                    Button("Configura più tardi") { model.finishSetup() }
                        .secondaryButton()
                } else if index > 0 {
                    Button("Indietro") { go(-1) }
                        .secondaryButton()
                }
                Button(step == .done ? "Inizia a usare Nod" : "Continua") {
                    if step == .done { model.finishSetup() } else { go(1) }
                }
                .primaryButton()
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private func go(_ delta: Int) {
        forward = delta > 0
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)) {
            index = max(0, min(session.steps.count - 1, index + delta))
        }
    }
}

// MARK: - Intestazione

private struct StepHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Brand.gradient)
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 22)
    }
}

// MARK: - Passaggi

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center, spacing: 28) {
                FloatingAppIcon(size: 150)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nod")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .foregroundStyle(Brand.gradient)
                    Text("Approva l'AI con un cenno. Lascia la scrivania senza pensarci.")
                        .font(.title2.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Nod lavora con Cocaine, le tue AirPods e il tuo Apple Watch. Ogni passaggio si prova subito.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                FeatureTile(symbol: "checkmark.seal.fill", title: "Annuisci",
                            detail: "Con le AirPods approvi con un cenno, poi confermi col tasto laterale del Watch.")
                FeatureTile(symbol: "applewatch", title: "Solo Watch",
                            detail: "Senza AirPods: doppio clic per approvare, Nega o la notifica per rifiutare.")
                FeatureTile(symbol: "figure.walk.motion", title: "Ti allontani",
                            detail: "Il Watch ti chiede se tenere sveglio il Mac. Se non rispondi decide la tua regola.")
            }
        }
    }
}

struct WhatsNewStep: View {
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                StepHeader(eyebrow: "Aggiornamento", title: "Novità di Nod",
                           subtitle: "Cosa è cambiato dall'ultima volta che l'hai aperto. Poi ti mostro solo ciò che è nuovo.")
                Spacer()
                FloatingAppIcon(size: 84)
            }
            if entries.isEmpty {
                Text("Piccole correzioni e miglioramenti.").foregroundStyle(.secondary).contentCard()
            } else {
                ChangelogList(entries: entries).contentCard(padding: 22)
            }
        }
    }
}

struct ChangelogList: View {
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Versione \(entry.version)").font(.title3.weight(.semibold))
                        Text(entry.date).font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(entry.items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "sparkle").font(.caption).foregroundStyle(Brand.gradient).accessibilityHidden(true)
                            Text(item).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct CocaineStep: View {
    @ObservedObject var cocaine: CocaineBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(eyebrow: "Passo 1", title: "Cocaine",
                       subtitle: "Nod usa Cocaine per tenere sveglio il Mac quando ti allontani.")
            VStack(alignment: .leading, spacing: 14) {
                StatusRow(title: "Installato", value: cocaine.isInstalled ? "Versione \(cocaine.version ?? "?")" : "Non trovato",
                          ok: cocaine.isInstalled, symbol: "powersleep")
                StatusRow(title: "Richieste dell'AI", value: cocaine.approvalsAvailable ? "Collegate" : "In arrivo",
                          ok: cocaine.approvalsAvailable, symbol: "checkmark.seal")
                if !cocaine.isInstalled {
                    Text("brew install --cask mattiakart/tap/cocaine")
                        .font(.body.monospaced()).textSelection(.enabled)
                }
                if !cocaine.approvalsAvailable {
                    Text("Le richieste vere dell'AI non sono ancora collegate a Cocaine. Intanto Nod gestisce la presenza e puoi provare il flusso delle approvazioni.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Button("Controlla di nuovo") { cocaine.refresh() }.secondaryButton()
            }
            .contentCard()
        }
        .onAppear { cocaine.refresh() }
    }
}

private struct AirPodsStep: View {
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var prefs: Preferences
    @State private var nods = 0
    @State private var lastLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(eyebrow: "Passo 2", title: "AirPods",
                       subtitle: "Nod legge il movimento della testa per capire quando annuisci, scuoti la testa o ti alzi e cammini. Sono facoltative: senza, basta il Watch.")
            HStack(alignment: .center, spacing: 30) {
                ZStack {
                    PulseRings(active: head.isConnected).frame(width: 220, height: 220)
                    HeadIndicator(head: head, size: 140)
                    DrawnCheck(trigger: nods, size: 70).offset(x: 70, y: 60)
                }
                .frame(width: 230, height: 230)
                VStack(alignment: .leading, spacing: 14) {
                    if !head.isRunning {
                        // Prima della richiesta di sistema: un solo pulsante, che la apre (HIG, Privacy).
                        Text("Al prossimo passo macOS ti chiede il permesso Movimento e fitness. I dati restano su questo Mac.")
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Continua") { prefs.headMotionEnabled = true; head.start() }.primaryButton()
                    } else {
                        Text(head.isConnected ? "Prova: annuisci due o tre volte, poi scuoti la testa."
                                              : "Indossa le AirPods: il disegno seguirà la tua testa.")
                            .font(.title3.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        if let lastLabel {
                            Label(lastLabel, systemImage: "checkmark.circle.fill").foregroundStyle(Brand.gradient)
                        }
                        Text("Non le hai con te? Continua: le approvazioni funzionano anche solo col Watch.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .contentCard(padding: 22)
        }
        .onReceive(head.$lastGesture) { g in
            guard let g else { return }
            lastLabel = g.gesture.title + ": riconosciuto."
            if g.gesture == .nod { nods += 1 }
        }
    }
}

private struct WatchStep: View {
    @ObservedObject var watch: WatchConfirmer
    @State private var successes = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(eyebrow: "Passo 3", title: "Apple Watch",
                       subtitle: "Ogni approvazione si conferma premendo due volte il tasto laterale, come per sbloccare il Mac. Nega nella richiesta vale come no.")
            HStack(alignment: .center, spacing: 30) {
                ZStack {
                    PulseRings(active: watch.isAsking).frame(width: 200, height: 200)
                    Image(systemName: "applewatch.side.right")
                        .font(.system(size: 84, weight: .light))
                        .foregroundStyle(Brand.gradient)
                    DrawnCheck(trigger: successes, size: 60).offset(x: 62, y: 52)
                }
                .frame(width: 220, height: 220)
                VStack(alignment: .leading, spacing: 14) {
                    StatusRow(title: "Watch vicino e sbloccato",
                              value: watch.isAvailable ? "Pronto" : (watch.unavailableReason ?? "Non pronto"), ok: watch.isAvailable)
                    if !watch.isAvailable {
                        Text("Attiva Impostazioni di Sistema > Touch ID e password > Apple Watch, poi riprova.")
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Button(watch.isAsking ? "Guarda il Watch…" : "Prova la conferma") {
                        Task {
                            if case .confirmed = await watch.confirm("provare la conferma con Apple Watch") { successes += 1 }
                        }
                    }
                    .primaryButton()
                    .disabled(watch.isAsking)
                    if let outcome = watch.lastOutcome {
                        Label(outcome.title, systemImage: outcome == .denied || isConfirmed(outcome) ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(isConfirmed(outcome) ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.orange))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .contentCard(padding: 22)
        }
        .onAppear { watch.refresh() }
    }

    private func isConfirmed(_ o: WatchConfirmer.Outcome) -> Bool {
        if case .confirmed = o { return true }
        return false
    }
}

private struct NotificationsStep: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var relay: NotificationRelay
    @AppStorage("check.allowed") private var allowed = false
    @AppStorage("check.focus") private var focus = false
    @AppStorage("check.mirror") private var mirror = false
    @AppStorage("check.locked") private var locked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(eyebrow: "Passo 4", title: "Notifiche sul Watch",
                       subtitle: "Da lontano Nod ti scrive sul Watch tramite l'app ntfy dell'iPhone. Il doppio tap sceglie il primo pulsante.")
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 14) {
                    WatchNotificationPreview()
                    Button("Invia prova") { Task { await relay.sendTest() } }.primaryButton()
                    if let event = relay.lastEvent {
                        Text(event).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(width: 180)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Se arrivano nell'app ntfy ma non come avviso").font(.headline)
                    ChecklistRow(text: "Nell'app ntfy: + e il topic qui sotto", detail: "Server: lo stesso scelto qui.",
                                 done: .constant(true), automatic: true)
                    ChecklistRow(text: "iPhone > Impostazioni > Notifiche > ntfy",
                                 detail: "Consenti notifiche, Banner, Avvisi con priorità.", done: $allowed)
                    ChecklistRow(text: "Nessuna Full immersion che blocchi ntfy", done: $focus)
                    ChecklistRow(text: "App Watch > Notifiche > ntfy: rispecchia gli avvisi", done: $mirror)
                    ChecklistRow(text: "Blocca l'iPhone e tieni il Watch al polso",
                                 detail: "Il Watch mostra le notifiche solo quando l'iPhone è bloccato.", done: $locked)
                    ChecklistRow(text: "Nod in ascolto delle risposte", detail: relay.isListening ? "Collegato." : "Non collegato: controlla il server.",
                                 done: .constant(relay.isListening), automatic: true)
                    ChecklistRow(text: "Tocca Ricevuta sulla notifica di prova",
                                 detail: relay.lastRoundTrip.map { "Risposta arrivata alle \($0.formatted(date: .omitted, time: .shortened))." }
                                     ?? "Quando arriva fino al Mac si spunta da sola.",
                                 done: .constant(relay.lastRoundTrip != nil), automatic: true)
                }
                .contentCard()
            }
            Form { ServerSettingsSection(prefs: prefs, relay: relay) }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 230)
        }
    }
}

private struct PresenceStep: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(eyebrow: "Passo 5", title: "Quando ti allontani",
                       subtitle: "Il Watch ti chiede cosa fare. Se non rispondi, vale questa regola.")
            HStack(alignment: .center, spacing: 28) {
                WeekStrip(schedule: prefs.leavingRule.schedule)
                Text(PresenceRuleEditor.summary(prefs.leavingRule))
                    .font(.title3.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentCard(padding: 22)
            Form { PresenceRuleEditor(prefs: prefs) }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 400)
        }
    }
}

private struct AppearanceStep: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(eyebrow: "Passo 6", title: "Aspetto",
                       subtitle: "Scegli il tema dell'app e come appare Nod nella barra dei menu.")
            VStack(alignment: .leading, spacing: 14) {
                Text("Tema").font(.headline)
                Picker("Tema", selection: $prefs.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
            }
            .contentCard()
            VStack(alignment: .leading, spacing: 14) {
                Text("Barra dei menu").font(.headline)
                HStack(spacing: 16) {
                    ForEach(MenuBarStyle.allCases) { style in
                        MenuBarPreview(style: style, selected: prefs.menuBarStyle == style)
                            .onTapGesture { prefs.menuBarStyle = style }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Icona \(style.title)")
                    }
                }
                Text("Da sinistra: al Mac, in uscita, lontano.").font(.callout).foregroundStyle(.secondary)
            }
            .contentCard()
        }
    }
}

private struct DoneStep: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    FloatingAppIcon(size: 120)
                    DrawnCheck(trigger: 1, size: 54).offset(x: 54, y: 48)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tutto pronto").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Nod resta nella barra dei menu. Questa configurazione si riapre da Nod > Ripeti configurazione.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            FlowPills(items: [
                ("powersleep", model.cocaine.isInstalled ? "Cocaine collegato" : "Cocaine da installare", model.cocaine.isInstalled),
                ("airpodspro", model.head.isRunning ? "AirPods pronte" : "AirPods non usate", true),
                ("applewatch", model.watch.isAvailable ? "Watch pronto" : "Watch da attivare", model.watch.isAvailable),
                ("bell.badge", model.relay.isListening ? "Notifiche collegate" : "Notifiche da verificare", model.relay.isListening),
            ])
            Toggle("Apri Nod all'accesso", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) {
                    do {
                        if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                }
                .contentCard()
            if let loginError { Text(loginError).foregroundStyle(.orange) }
            DeveloperLinks()
        }
    }
}

/// Pillole in righe da due.
private struct FlowPills: View {
    let items: [(String, String, Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(spacing: 10) {
                    ForEach(start..<min(start + 2, items.count), id: \.self) { i in
                        SummaryPill(symbol: items[i].0, text: items[i].1, ok: items[i].2)
                    }
                }
            }
        }
    }
}
