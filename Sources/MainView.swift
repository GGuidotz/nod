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
        StatusContent(cocaine: model.cocaine, presence: model.presence, head: model.head, watch: model.watch, relay: model.relay)
            .navigationTitle("Stato")
    }
}

private struct StatusContent: View {
    @ObservedObject var cocaine: CocaineBridge
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var relay: NotificationRelay

    var body: some View {
        Form {
            Section("Tu") {
                LabeledContent("Presenza") {
                    Label(presence.state.title, systemImage: presence.state.symbol)
                }
                LabeledContent("Da") { Text(presence.since, style: .relative) }
                if let decision = presence.decision, presence.state == .away {
                    LabeledContent("Scelta", value: decision.title)
                }
            }
            Section("Cocaine") {
                StatusRow(title: "App", value: cocaine.isInstalled ? "Versione \(cocaine.version ?? "?")" : "Non installata",
                          ok: cocaine.isInstalled)
                StatusRow(title: "Mac sveglio", value: cocaine.status?.on == true ? "Sì" : "No", ok: cocaine.status?.on == true)
                if cocaine.isInstalled {
                    HStack {
                        Button(cocaine.status?.on == true ? "Spegni Cocaine" : "Tieni sveglio ora") {
                            Task { if cocaine.status?.on == true { await cocaine.stopKeepingAwake() } else { await cocaine.keepAwake() } }
                        }
                        Button("Apri Cocaine") { cocaine.openCocaine() }
                    }
                }
                if let error = cocaine.lastError { Text(error).foregroundStyle(.orange) }
            }
            Section("Dispositivi") {
                StatusRow(title: "AirPods", value: head.isConnected ? (head.isWalking ? "Indossate, stai camminando" : "Indossate")
                                                                    : "Non indossate", ok: head.isConnected)
                StatusRow(title: "Apple Watch", value: watch.isAvailable ? "Pronto per le conferme" : "Non disponibile",
                          ok: watch.isAvailable)
                StatusRow(title: "Notifiche", value: relay.isListening ? "In ascolto delle risposte" : "Non collegato",
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
                    Label("Le richieste vere dell'AI non sono ancora collegate a Cocaine: quando lo saranno arriveranno qui. Intanto puoi provare il flusso completo.",
                          systemImage: "info.circle")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                LabeledContent("Modo adesso") {
                    Label(flow.usesGestures ? "AirPods e Watch" : "Solo Watch",
                          systemImage: flow.usesGestures ? "airpodspro" : "applewatch")
                }
                phaseView
                HStack {
                    Button("Prova un'approvazione") { flow.demo() }
                    if flow.phase != .idle { Button("Annulla") { flow.cancel() } }
                }
            } header: {
                Text("Prova")
            } footer: {
                Text("Con le AirPods: annuisci, poi premi due volte il tasto laterale del Watch; scuoti la testa per negare. "
                     + "Senza AirPods: doppio clic per approvare, Nega nella richiesta o il pulsante Nega della notifica sul Watch. "
                     + "\"Consenti sempre\" non è mai disponibile da qui: resta nel notch di Cocaine o nel terminale.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Approvazioni")
    }

    @ViewBuilder private var phaseView: some View {
        switch flow.phase {
        case .idle:
            Text("Nessuna richiesta in attesa.").foregroundStyle(.secondary)
        case .waitingForGesture(let summary, let until):
            VStack(alignment: .leading, spacing: 6) {
                Text(summary)
                Text("Annuisci o scuoti la testa, ancora \(Text(until, style: .timer))").foregroundStyle(.secondary)
            }
        case .confirmingOnWatch(let summary, let notified):
            VStack(alignment: .leading, spacing: 6) {
                Label("Conferma sul Watch: \(summary)", systemImage: "applewatch")
                Text(notified ? "Doppio clic sul tasto laterale, oppure rispondi alla notifica sul Watch."
                              : "Doppio clic sul tasto laterale per approvare, Nega per rifiutare.")
                    .foregroundStyle(.secondary)
            }
        case .approved(let summary, let by):
            Label("Approvata \(by): \(summary)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .denied(let summary, let by):
            Label("Negata \(by): \(summary)", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .expired(let summary):
            Label("Nessuna risposta in tempo: \(summary)", systemImage: "clock").foregroundStyle(.secondary)
        case .failed(let summary, let reason):
            Label("\(reason) \(summary)", systemImage: "exclamationmark.circle").foregroundStyle(.orange)
        }
    }
}

// MARK: - Presenza

struct PresenceView: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section("Adesso") {
                LabeledContent("Stato") { Label(presence.state.title, systemImage: presence.state.symbol) }
                HStack {
                    Button("Sono al Mac") { presence.markHere(manual: true) }.disabled(presence.state == .here)
                    Button("Sto uscendo…") { presence.markLeaving(manual: true) }.disabled(presence.state != .here)
                }
            }
            PresenceRuleEditor(prefs: prefs)
            Section("Ultimi eventi") {
                if presence.log.isEmpty {
                    Text("Ancora niente.").foregroundStyle(.secondary)
                }
                ForEach(Array(presence.log.enumerated()), id: \.offset) { item in
                    LabeledContent(item.element.text) { Text(item.element.date, style: .time).foregroundStyle(.secondary) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Presenza")
    }
}

// MARK: - Dispositivi

struct DevicesView: View {
    @ObservedObject var head: HeadMotionMonitor
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section("AirPods") {
                HStack(spacing: 20) {
                    HeadIndicator(head: head, size: 88)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(head.isConnected ? "Indossate" : "Non indossate").font(.headline)
                        if let g = head.lastGesture {
                            Text("Ultimo gesto: \(g.gesture.title.lowercased()), \(Text(g.at, style: .relative)) fa")
                                .foregroundStyle(.secondary)
                        }
                        if head.isWalking { Label("Stai camminando", systemImage: "figure.walk") }
                    }
                }
                Toggle("Usa il movimento della testa", isOn: $prefs.headMotionEnabled)
                    .onChange(of: prefs.headMotionEnabled) { if prefs.headMotionEnabled { head.start() } else { head.stop() } }
            }
            Section("Apple Watch") {
                StatusRow(title: "Conferme", value: watch.isAvailable ? "Pronto" : (watch.unavailableReason ?? "Non disponibile"),
                          ok: watch.isAvailable)
                Button(watch.isAsking ? "Guarda il Watch…" : "Prova la conferma") {
                    Task { _ = await watch.confirm("provare la conferma con Apple Watch") }
                }
                .disabled(watch.isAsking)
                if let outcome = watch.lastOutcome {
                    Text(outcome.title).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Dispositivi")
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
        .navigationTitle("Novità")
    }
}
