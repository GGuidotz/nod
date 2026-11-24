// Diagnostica: il report che si compila da solo, da copiare, salvare o mandare; le prove del Watch e di ntfy; i rimedi
// (metodo di conferma, icona classica nel Dock).

import AppKit
import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var log = DiagnosticsLog.shared
    @State private var report = ""
    @State private var status: String?

    var body: some View {
        SGPage(topInset: SG.Space.l, hasTabBar: false) {
            SGSection(L("Report")) {
                SGRowBlock {
                    Text(L("Nod tiene un registro di ciò che succede (conferme del Watch, notifiche, presenza) e lo raccoglie in un report senza dati segreti. Se qualcosa non va, salvalo e mandacelo."))
                        .fixedSize(horizontal: false, vertical: true)
                }
                SGDivider()
                SGRowBlock {
                    HStack(spacing: 8) {
                        Button(L("Copia report")) { copy() }
                        Button(L("Salva…")) { save() }
                        Button(L("Invia per email")) { email() }
                        Button(L("Apri una issue su GitHub")) { openIssue() }
                    }
                    .buttonStyle(.sgSecondary)
                }
                if let status {
                    SGDivider()
                    SGRowBlock { Text(status).foregroundStyle(SG.Ink.secondary) }
                }
            }

            WatchDiagnostics(watch: model.watch, prefs: model.prefs)

            NtfyDiagnostics(relay: model.relay)

            RemindersDiagnostics(reminders: model.reminders, prefs: model.prefs)

            IconDiagnostics(icon: IconHealth.shared, prefs: model.prefs)

            SGSection(L("Anteprima")) {
                SGRowBlock {
                    ScrollView {
                        Text(report)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SG.Ink.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 240)
                }
            }
        }
        .navigationTitle(L("Diagnostica"))
        .onAppear { refresh(); model.watch.refresh() }
        .onChange(of: log.entries.count) { refresh() }
    }

    private func refresh() { report = DiagnosticsReport.make(model: model) }

    private func copy() {
        refresh()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        status = L("Report copiato.")
    }

    private func save() {
        refresh()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = DiagnosticsReport.suggestedFileName
        panel.allowedContentTypes = [.plainText]
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DiagnosticsReport.save(report, to: url)
            status = L("Salvato: %@", url.lastPathComponent)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            status = error.localizedDescription
        }
    }

    private func email() {
        refresh()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(DiagnosticsReport.suggestedFileName)
        do { try DiagnosticsReport.save(report, to: url) } catch { status = error.localizedDescription; return }
        guard let service = NSSharingService(named: .composeEmail) else { status = L("Mail non disponibile."); return }
        service.recipients = [Developer.email]
        service.subject = "Nod \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") – diagnostics"
        service.perform(withItems: [L("Ciao, ecco il report di diagnostica di Nod."), url])
    }

    private func openIssue() {
        var components = URLComponents(string: "https://github.com/GGuidotz/nod/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Diagnostics: "),
            URLQueryItem(name: "body", value: "Describe the problem here, then attach the diagnostics file (Diagnostics > Save…).\n\n"
                + "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
                + "Nod: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"),
        ]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }
}

private struct IconDiagnostics: View {
    @ObservedObject var icon: IconHealth
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGSection(L("Icona")) {
            SGRowBlock {
                HStack(alignment: .top, spacing: 16) {
                    if let preview = icon.preview {
                        Image(nsImage: preview).resizable().frame(width: 64, height: 64)
                            .accessibilityLabel(L("Anteprima dell'icona del bundle"))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text(L("Icona compilata")); Spacer(); Text(icon.tier).foregroundStyle(SG.Ink.secondary) }
                        HStack { Text(L("Parte visibile")); Spacer()
                            Text(icon.coverage.map(IconMetrics.percent) ?? "-").foregroundStyle(SG.Ink.secondary) }
                        if let check = icon.buildCheck {
                            HStack { Text(L("Controllo di build.sh")); Spacer(); Text(check).foregroundStyle(SG.Ink.secondary) }
                        }
                        if icon.fallbackActive {
                            NoteLabel(text: L("Risultava vuota: Nod mostra da solo l'icona classica."), symbol: "arrow.uturn.backward.circle")
                        }
                    }
                }
            }
            SGDivider()
            SGToggleRow(L("Usa l'icona classica nel Dock"), isOn: $prefs.classicDockIcon)
        } footer: {
            SGFootnote(L("All'avvio Nod misura l'icona che il Dock disegna: se è vuota mette quella classica. Con questa opzione la classica resta sempre."))
        }
    }
}

private struct RemindersDiagnostics: View {
    @ObservedObject var reminders: ReminderRelay
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGSection(L("Promemoria")) {
            RemindersControls(reminders: reminders, prefs: prefs)
            SGDivider()
            SGValueRow(L("Lista"), value: reminders.listStatus ?? "-")
            SGDivider()
            SGValueRow(L("Ultimo avviso"), value: reminders.lastAlert ?? "-")
        }
    }
}

private struct NtfyDiagnostics: View {
    @ObservedObject var relay: NotificationRelay

    var body: some View {
        SGSection(L("Notifiche")) {
            SGRowBlock {
                HStack(spacing: 10) {
                    Button(L("Prova invio ntfy")) { Task { await relay.sendTest() } }
                        .buttonStyle(.sgSecondary)
                    if let event = relay.lastEvent { Text(event).foregroundStyle(SG.Ink.secondary) }
                }
            }
            SGDivider()
            SGValueRow(L("Ultimo invio"), value: relay.lastPublish ?? "-")
            SGDivider()
            SGValueRow(L("Verifica sul server"), value: relay.lastServerCheck ?? "-")
            SGDivider()
            SGValueRow(L("Risposte"), value: relay.isListening ? L("In ascolto") : L("Non collegato"))
            SGDivider()
            SGRowBlock { NtfyAlertChecklist(relay: relay) }
        } footer: {
            SGFootnote(L("Se la verifica sul server trova il messaggio ma l'avviso non compare, il percorso fino al server funziona: resta la consegna sull'iPhone (lista qui sopra)."))
        }
    }
}

private struct WatchDiagnostics: View {
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGSection(L("Apple Watch")) {
            SGMenuRow(L("Metodo di conferma"), selection: $prefs.watchMethod,
                      options: WatchMethod.allCases.map { (value: $0, title: $0.title) })
            if prefs.watchMethod == .automatic, !watch.currentChain.isEmpty {
                SGDivider()
                SGValueRow(L("Ordine in automatico"), value: watch.currentChain.map(\.title).joined(separator: " → "))
            }
            SGDivider()
            SGRowBlock {
                HStack(spacing: 10) {
                    Button(watch.isAsking ? L("Guarda il Watch…") : L("Prova guidata del doppio clic")) {
                        Task { await watch.testAllMethods() }
                    }
                    .buttonStyle(.sgSecondary)
                    .disabled(watch.isAsking || watch.isProbing)
                    Button(watch.isProbing ? L("Guarda il Watch…") : L("Prova il Watch tramite osascript")) {
                        Task { await watch.probeViaOsascript() }
                    }
                    .buttonStyle(.sgSecondary)
                    .disabled(watch.isAsking || watch.isProbing)
                }
            }
            if let step = watch.guidedStep {
                SGDivider()
                SGRowBlock {
                    NoteLabel(text: step, symbol: "applewatch.radiowaves.left.and.right", tint: SG.Ink.secondary)
                        .font(SG.Font.bodyEmphasis)
                }
            }
            if prefs.watchMethod != .automatic,
               watch.attempts.last(where: { $0.method == prefs.watchMethod.rawValue })?.code == LAError.Code.userFallback.rawValue {
                SGDivider()
                SGRowBlock {
                    HStack {
                        NoteLabel(text: L("Con questo metodo il doppio clic torna come \"altro metodo\" e non vale come conferma."),
                                  symbol: "exclamationmark.triangle.fill")
                        Button(L("Torna ad Automatico")) { prefs.watchMethod = .automatic; watch.refresh() }
                            .buttonStyle(.sgSecondary)
                    }
                }
            }
            if let probe = watch.probeResult {
                SGDivider()
                SGValueRow(L("osascript (firmato Apple)"), value: probe)
            }
            ForEach(WatchMethod.concrete) { method in
                if let result = watch.methodResults[method] {
                    SGDivider()
                    SGValueRow(method.title, value: result)
                }
            }
            if let last = watch.attempts.last {
                SGDivider()
                SGValueRow(L("Ultimo tentativo"), value: last.line)
            }
            if watch.needsTroubleshooting {
                SGDivider()
                SGRowBlock { WatchTroubleshooting(systemLevel: watch.systemRefusesWatch) }
            }
            SGDivider()
            SGRowBlock { WatchDoubleClickNotice() }
            if watch.doubleClickNotConfirmed {
                SGDivider()
                SGRowBlock {
                    Button(L("Copia testo per Feedback Assistant")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(DiagnosticsReport.appleFeedback(model: AppModel.shared), forType: .string)
                        NSWorkspace.shared.open(URL(string: "applefeedback://")!)
                    }
                    .buttonStyle(.sgSecondary)
                }
            }
        } footer: {
            SGFootnote(L("Sperimentale: i metodi col doppio clic restano qui per riprovarli dopo un aggiornamento di macOS o watchOS.")
                       + " " + L("Per ogni metodo Nod ti dice quando fare doppio clic sul tasto laterale del Watch: non toccare il Mac. Il metodo che dà \"Confermato\" sceglilo qui sopra.")
                       + " " + L("La prova tramite osascript fa la stessa richiesta da un processo firmato Apple: se così il Watch la riceve, il limite è la firma di Nod."))
        }
    }
}
