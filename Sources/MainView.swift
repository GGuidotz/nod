// La finestra principale: barra laterale con Stato, Approvazioni, Presenza, Dispositivi, Novità, Diagnostica.
// Le impostazioni che si cambiano di rado (server, accesso) stanno in Nod > Impostazioni (⌘,).
// I moduli sono pagine di Sguardo (SGPage, SGSection): righe su velo traslucido con filo da 1 pt, pulsanti a capsula.

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                ForEach(SidebarItem.allCases) { item in
                    NavigationLink(value: item) { Label(item.title, systemImage: item.symbol) }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch model.selection ?? .status {
                case .status: StatusView()
                case .approvals: ApprovalsView(flow: model.approvals, cocaine: model.cocaine)
                case .presence: PresenceView(presence: model.presence, prefs: model.prefs)
                case .devices: DevicesView(head: model.head, watch: model.watch, prefs: model.prefs)
                case .whatsNew: WhatsNewView()
                case .diagnostics: DiagnosticsView()
                }
            }
        }
        .sheet(item: $model.setup) { session in
            SetupView(session: session).environmentObject(model).sguardoAccent(default: .nod)
        }
    }
}

/// Spazio sopra la prima riga di un modulo: la barra del titolo della finestra principale ha già la sua zona sicura.
private let moduleTopInset: CGFloat = SG.Space.l

/// Il valore a destra di una riga: simbolo e testo, nell'inchiostro secondario.
private struct ValueLabel: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(SG.Font.body)
            .foregroundStyle(SG.Ink.secondary)
            .multilineTextAlignment(.trailing)
    }
}

// MARK: - Stato

struct StatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        StatusContent(cocaine: model.cocaine, presence: model.presence, head: model.head, watch: model.watch, relay: model.relay,
                      updater: model.updater)
            .navigationTitle(L("Stato"))
    }
}

private struct StatusContent: View {
    @ObservedObject var cocaine: CocaineBridge
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var relay: NotificationRelay
    @ObservedObject var updater: Updater

    var body: some View {
        SGPage(topInset: moduleTopInset, hasTabBar: false) {
            if updater.isUpdateAvailable {
                UpdateCard(updater: updater)
            }
            SGSection(L("Tu")) {
                SGLabeledRow {
                    Text(L("Presenza"))
                } trailing: {
                    ValueLabel(text: presence.state.title, symbol: presence.state.symbol)
                }
                SGDivider()
                SGValueRow(L("Da")) { Text(presence.since, style: .relative) }
                if let decision = presence.decision, presence.state == .away {
                    SGDivider()
                    SGValueRow(L("Scelta"), value: decision.title)
                }
            }
            SGSection(L("Cocaine")) {
                StatusRow(title: L("App"), value: cocaine.isInstalled ? L("Versione %@", cocaine.version ?? "?") : L("Non installata"),
                          ok: cocaine.isInstalled)
                SGDivider()
                StatusRow(title: L("Mac sveglio"), value: cocaine.status?.on == true ? L("Sì") : L("No"), ok: cocaine.status?.on == true)
                if cocaine.isInstalled {
                    SGDivider()
                    SGRowBlock {
                        HStack(spacing: 10) {
                            Button(cocaine.status?.on == true ? L("Spegni Cocaine") : L("Tieni sveglio ora")) {
                                Task { if cocaine.status?.on == true { await cocaine.stopKeepingAwake() } else { await cocaine.keepAwake() } }
                            }
                            .buttonStyle(.sgSecondary)
                            Button(L("Apri Cocaine")) { cocaine.openCocaine() }
                                .buttonStyle(.sgSecondary)
                        }
                    }
                }
                if let error = cocaine.lastError {
                    SGDivider()
                    SGRowBlock { NoteLabel(text: error, symbol: "exclamationmark.triangle.fill") }
                }
            }
            SGSection(L("Dispositivi")) {
                StatusRow(title: L("AirPods"), value: head.isConnected ? (head.isWalking ? L("Indossate, stai camminando") : L("Indossate"))
                                                                    : L("Non indossate"), ok: head.isConnected)
                SGDivider()
                StatusRow(title: L("Apple Watch"), value: watch.isAvailable ? L("Pronto per le conferme") : L("Non disponibile"),
                          ok: watch.isAvailable)
                SGDivider()
                StatusRow(title: L("Notifiche"), value: relay.isListening ? L("In ascolto delle risposte") : L("Non collegato"),
                          ok: relay.isListening)
            }
        }
        .onAppear { cocaine.refresh(); watch.refresh() }
    }
}

// MARK: - Approvazioni

struct ApprovalsView: View {
    @ObservedObject var flow: ApprovalFlow
    @ObservedObject var cocaine: CocaineBridge

    var body: some View {
        SGPage(topInset: moduleTopInset, hasTabBar: false) {
            if !cocaine.approvalsAvailable {
                SGSection {
                    SGRowBlock {
                        NoteLabel(text: L("Le richieste vere dell'AI non sono ancora collegate a Cocaine: quando lo saranno arriveranno qui. Intanto puoi provare il flusso completo."),
                                  symbol: "info.circle", tint: SG.Ink.secondary)
                    }
                }
            }
            SGSection(L("Prova")) {
                SGLabeledRow {
                    Text(L("Modo adesso"))
                } trailing: {
                    ValueLabel(text: flow.usesGestures ? L("AirPods e Watch") : L("Solo Watch"),
                               symbol: flow.usesGestures ? "airpodspro" : "applewatch")
                }
                SGDivider()
                SGRowBlock { phaseView }
                SGDivider()
                SGRowBlock {
                    HStack(spacing: 10) {
                        Button(L("Prova un'approvazione")) { flow.demo() }
                            .buttonStyle(.sgSecondary)
                        if flow.phase != .idle {
                            Button(L("Annulla")) { flow.cancel() }
                                .buttonStyle(.sgSecondary)
                        }
                    }
                }
            } footer: {
                SGFootnote(L("Con le AirPods: annuisci, poi conferma dal Watch; scuoti la testa per negare. ")
                           + L("Dal Watch: Approva o Nega nella notifica, oppure completa il promemoria per approvare. Il doppio clic sul tasto laterale è sperimentale. ")
                           + L("\"Consenti sempre\" non è mai disponibile da qui: resta nel notch di Cocaine o nel terminale."))
            }
        }
        .navigationTitle(L("Approvazioni"))
    }

    @ViewBuilder private var phaseView: some View {
        switch flow.phase {
        case .idle:
            Text(L("Nessuna richiesta in attesa.")).foregroundStyle(SG.Ink.secondary)
        case .waitingForGesture(let summary, let until):
            VStack(alignment: .leading, spacing: 6) {
                Text(summary)
                HStack(spacing: 4) { Text(L("Annuisci o scuoti la testa, tempo rimasto:")); Text(until, style: .timer) }
                    .foregroundStyle(SG.Ink.secondary)
            }
        case .confirmingOnWatch(let summary, let notified):
            VStack(alignment: .leading, spacing: 6) {
                NoteLabel(text: L("Conferma sul Watch: %@", summary), symbol: "applewatch", tint: SG.Ink.secondary)
                Text(notified ? L("Rispondi alla notifica o al promemoria sul Watch (doppio clic: sperimentale).")
                              : L("Doppio clic sul tasto laterale per approvare, Nega per rifiutare."))
                    .foregroundStyle(SG.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .approved(let summary, let by):
            NoteLabel(text: L("Approvata %@: %@", by, summary), symbol: "checkmark.circle.fill", tint: SG.Status.success)
        case .denied(let summary, let by):
            NoteLabel(text: L("Negata %@: %@", by, summary), symbol: "xmark.circle.fill", tint: SG.Status.danger)
        case .expired(let summary):
            NoteLabel(text: L("Nessuna risposta in tempo: %@", summary), symbol: "clock", tint: SG.Ink.secondary)
        case .failed(let summary, let reason):
            NoteLabel(text: reason + " " + summary, symbol: "exclamationmark.circle")
        }
    }
}

// MARK: - Presenza

struct PresenceView: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGPage(topInset: moduleTopInset, hasTabBar: false) {
            SGSection(L("Adesso")) {
                SGLabeledRow {
                    Text(L("Stato"))
                } trailing: {
                    ValueLabel(text: presence.state.title, symbol: presence.state.symbol)
                }
                SGDivider()
                SGRowBlock {
                    HStack(spacing: 10) {
                        Button(L("Sono al Mac")) { presence.markHere(manual: true) }
                            .buttonStyle(.sgSecondary)
                            .disabled(presence.state == .here)
                        Button(L("Sto uscendo…")) { presence.markLeaving(manual: true) }
                            .buttonStyle(.sgSecondary)
                            .disabled(presence.state != .here)
                    }
                }
            }
            PresenceRuleEditor(prefs: prefs)
            SGSection(L("Ultimi eventi")) {
                if presence.log.isEmpty {
                    SGRowBlock { Text(L("Ancora niente.")).foregroundStyle(SG.Ink.secondary) }
                }
                ForEach(Array(presence.log.enumerated()), id: \.offset) { item in
                    if item.offset > 0 { SGDivider() }
                    SGLabeledRow {
                        Text(item.element.text)
                    } trailing: {
                        Text(item.element.date, style: .time).font(SG.Font.body).foregroundStyle(SG.Ink.secondary)
                    }
                }
            }
        }
        .navigationTitle(L("Presenza"))
    }
}

// MARK: - Dispositivi

struct DevicesView: View {
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGPage(topInset: moduleTopInset, hasTabBar: false) {
            SGSection(L("AirPods")) {
                SGRowBlock {
                    HStack(spacing: 20) {
                        HeadIndicator(head: head, size: 88)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(head.isConnected ? L("Indossate") : L("Non indossate")).font(SG.Font.instruction)
                            if let g = head.lastGesture {
                                Text(L("Ultimo gesto: %@, alle %@", g.gesture.title.lowercased(), g.at.formatted(date: .omitted, time: .standard)))
                                    .foregroundStyle(SG.Ink.secondary)
                            }
                            if head.isWalking { Label(L("Stai camminando"), systemImage: "figure.walk") }
                        }
                    }
                }
                SGDivider()
                SGToggleRow(L("Usa il movimento della testa"), isOn: $prefs.headMotionEnabled)
                    .onChange(of: prefs.headMotionEnabled) { if prefs.headMotionEnabled { head.start() } else { head.stop() } }
            }
            SGSection(L("Apple Watch")) {
                StatusRow(title: L("Conferme"), value: watch.isAvailable ? L("Pronto") : (watch.unavailableReason ?? L("Non disponibile")),
                          ok: watch.isAvailable)
                SGDivider()
                SGRowBlock {
                    Button(watch.isAsking ? L("Guarda il Watch…") : L("Prova la conferma")) {
                        Task { _ = await watch.confirm(L("provare la conferma con Apple Watch")) }
                    }
                    .buttonStyle(.sgSecondary)
                    .disabled(watch.isAsking)
                }
                if let outcome = watch.lastOutcome {
                    SGDivider()
                    SGRowBlock { Text(outcome.title).foregroundStyle(SG.Ink.secondary) }
                }
                if !watch.currentChain.isEmpty {
                    SGDivider()
                    SGValueRow(L("Metodi, in ordine"), value: watch.currentChain.map(\.title).joined(separator: " → "))
                }
                SGDivider()
                SGRowBlock { WatchDoubleClickNotice() }
                if watch.needsTroubleshooting {
                    SGDivider()
                    SGRowBlock { WatchTroubleshooting(systemLevel: watch.systemRefusesWatch) }
                }
            }
        }
        .navigationTitle(L("Dispositivi"))
        .onAppear { watch.refresh() }
    }
}

// MARK: - Novità

struct WhatsNewView: View {
    private let entries = Changelog.load()

    var body: some View {
        SGPage(topInset: moduleTopInset, hasTabBar: false) {
            ChangelogList(entries: entries, cards: true)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L("Novità"))
    }
}
