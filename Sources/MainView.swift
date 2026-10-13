// La finestra principale: barra laterale con Stato, Approvazioni, Presenza, Dispositivi, Novità.
// Le impostazioni che si cambiano di rado (server, accesso) stanno in Nod > Impostazioni (⌘,).

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
            ZStack {
                DetailBackground()
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
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $model.setup) { session in
            SetupView(session: session).environmentObject(model)
        }
    }
}

/// Aurora tenue dietro i moduli; su macOS 26 si estende sotto la barra laterale di vetro.
private struct DetailBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            AuroraBackground(intensity: 0.35).backgroundExtensionEffect().ignoresSafeArea()
        } else {
            AuroraBackground(intensity: 0.35).ignoresSafeArea()
        }
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
        Form {
            if updater.isUpdateAvailable {
                Section { UpdateCard(updater: updater) }
            }
            Section(L("Tu")) {
                LabeledContent(L("Presenza")) {
                    Label(presence.state.title, systemImage: presence.state.symbol)
                }
                LabeledContent(L("Da")) { Text(presence.since, style: .relative) }
                if let decision = presence.decision, presence.state == .away {
                    LabeledContent(L("Scelta"), value: decision.title)
                }
            }
            Section(L("Cocaine")) {
                StatusRow(title: L("App"), value: cocaine.isInstalled ? L("Versione %@", cocaine.version ?? "?") : L("Non installata"),
                          ok: cocaine.isInstalled)
                StatusRow(title: L("Mac sveglio"), value: cocaine.status?.on == true ? L("Sì") : L("No"), ok: cocaine.status?.on == true)
                if cocaine.isInstalled {
                    HStack {
                        Button(cocaine.status?.on == true ? L("Spegni Cocaine") : L("Tieni sveglio ora")) {
                            Task { if cocaine.status?.on == true { await cocaine.stopKeepingAwake() } else { await cocaine.keepAwake() } }
                        }
                        Button(L("Apri Cocaine")) { cocaine.openCocaine() }
                    }
                }
                if let error = cocaine.lastError { Text(error).foregroundStyle(.orange) }
            }
            Section(L("Dispositivi")) {
                StatusRow(title: L("AirPods"), value: head.isConnected ? (head.isWalking ? L("Indossate, stai camminando") : L("Indossate"))
                                                                    : L("Non indossate"), ok: head.isConnected)
                StatusRow(title: L("Apple Watch"), value: watch.isAvailable ? L("Pronto per le conferme") : L("Non disponibile"),
                          ok: watch.isAvailable)
                StatusRow(title: L("Notifiche"), value: relay.isListening ? L("In ascolto delle risposte") : L("Non collegato"),
                          ok: relay.isListening)
            }
        }
        .formStyle(.grouped)
        .onAppear { cocaine.refresh(); watch.refresh() }
    }
}

// MARK: - Approvazioni

struct ApprovalsView: View {
    @ObservedObject var flow: ApprovalFlow
    @ObservedObject var cocaine: CocaineBridge

    var body: some View {
        Form {
            if !cocaine.approvalsAvailable {
                Section {
                    Label(L("Le richieste vere dell'AI non sono ancora collegate a Cocaine: quando lo saranno arriveranno qui. Intanto puoi provare il flusso completo."),
                          systemImage: "info.circle")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                LabeledContent(L("Modo adesso")) {
                    Label(flow.usesGestures ? L("AirPods e Watch") : L("Solo Watch"),
                          systemImage: flow.usesGestures ? "airpodspro" : "applewatch")
                }
                phaseView
                HStack {
                    Button(L("Prova un'approvazione")) { flow.demo() }
                    if flow.phase != .idle { Button(L("Annulla")) { flow.cancel() } }
                }
            } header: {
                Text(L("Prova"))
            } footer: {
                Text(L("Con le AirPods: annuisci, poi conferma dal Watch; scuoti la testa per negare. ")
                     + L("Dal Watch: Approva o Nega nella notifica, oppure completa il promemoria per approvare. Il doppio clic sul tasto laterale è sperimentale. ")
                     + L("\"Consenti sempre\" non è mai disponibile da qui: resta nel notch di Cocaine o nel terminale."))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Approvazioni"))
    }

    @ViewBuilder private var phaseView: some View {
        switch flow.phase {
        case .idle:
            Text(L("Nessuna richiesta in attesa.")).foregroundStyle(.secondary)
        case .waitingForGesture(let summary, let until):
            VStack(alignment: .leading, spacing: 6) {
                Text(summary)
                HStack(spacing: 4) { Text(L("Annuisci o scuoti la testa, tempo rimasto:")); Text(until, style: .timer) }.foregroundStyle(.secondary)
            }
        case .confirmingOnWatch(let summary, let notified):
            VStack(alignment: .leading, spacing: 6) {
                Label(L("Conferma sul Watch: %@", summary), systemImage: "applewatch")
                Text(notified ? L("Rispondi alla notifica o al promemoria sul Watch (doppio clic: sperimentale).")
                              : L("Doppio clic sul tasto laterale per approvare, Nega per rifiutare."))
                    .foregroundStyle(.secondary)
            }
        case .approved(let summary, let by):
            Label(L("Approvata %@: %@", by, summary), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .denied(let summary, let by):
            Label(L("Negata %@: %@", by, summary), systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .expired(let summary):
            Label(L("Nessuna risposta in tempo: %@", summary), systemImage: "clock").foregroundStyle(.secondary)
        case .failed(let summary, let reason):
            Label(reason + " " + summary, systemImage: "exclamationmark.circle").foregroundStyle(.orange)
        }
    }
}

// MARK: - Presenza

struct PresenceView: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section(L("Adesso")) {
                LabeledContent(L("Stato")) { Label(presence.state.title, systemImage: presence.state.symbol) }
                HStack {
                    Button(L("Sono al Mac")) { presence.markHere(manual: true) }.disabled(presence.state == .here)
                    Button(L("Sto uscendo…")) { presence.markLeaving(manual: true) }.disabled(presence.state != .here)
                }
            }
            PresenceRuleEditor(prefs: prefs)
            Section(L("Ultimi eventi")) {
                if presence.log.isEmpty {
                    Text(L("Ancora niente.")).foregroundStyle(.secondary)
                }
                ForEach(Array(presence.log.enumerated()), id: \.offset) { item in
                    LabeledContent(item.element.text) { Text(item.element.date, style: .time).foregroundStyle(.secondary) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Presenza"))
    }
}

// MARK: - Dispositivi

struct DevicesView: View {
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section(L("AirPods")) {
                HStack(spacing: 20) {
                    HeadIndicator(head: head, size: 88)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(head.isConnected ? L("Indossate") : L("Non indossate")).font(.headline)
                        if let g = head.lastGesture {
                            Text(L("Ultimo gesto: %@, alle %@", g.gesture.title.lowercased(), g.at.formatted(date: .omitted, time: .standard)))
                                .foregroundStyle(.secondary)
                        }
                        if head.isWalking { Label(L("Stai camminando"), systemImage: "figure.walk") }
                    }
                }
                Toggle(L("Usa il movimento della testa"), isOn: $prefs.headMotionEnabled)
                    .onChange(of: prefs.headMotionEnabled) { if prefs.headMotionEnabled { head.start() } else { head.stop() } }
            }
            Section(L("Apple Watch")) {
                StatusRow(title: L("Conferme"), value: watch.isAvailable ? L("Pronto") : (watch.unavailableReason ?? L("Non disponibile")),
                          ok: watch.isAvailable)
                Button(watch.isAsking ? L("Guarda il Watch…") : L("Prova la conferma")) {
                    Task { _ = await watch.confirm(L("provare la conferma con Apple Watch")) }
                }
                .disabled(watch.isAsking)
                if let outcome = watch.lastOutcome {
                    Text(outcome.title).foregroundStyle(.secondary)
                }
                if !watch.currentChain.isEmpty {
                    LabeledContent(L("Metodi, in ordine"), value: watch.currentChain.map(\.title).joined(separator: " → "))
                }
                WatchDoubleClickNotice()
                if watch.needsTroubleshooting { WatchTroubleshooting(systemLevel: watch.systemRefusesWatch) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L("Dispositivi"))
        .onAppear { watch.refresh() }
    }
}

// MARK: - Novità

struct WhatsNewView: View {
    private let entries = Changelog.load()

    var body: some View {
        ScrollView {
            ChangelogList(entries: entries)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .navigationTitle(L("Novità"))
    }
}
