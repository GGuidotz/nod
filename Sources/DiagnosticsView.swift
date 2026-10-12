// Diagnostica: il report che si compila da solo, da copiare, salvare o mandare; le prove del Watch e di ntfy; i rimedi
// (metodo di conferma, icona classica nel Dock).

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var log = DiagnosticsLog.shared
    @State private var report = ""
    @State private var status: String?

    var body: some View {
        Form {
            Section {
                Text(L("Nod tiene un registro di ciò che succede (conferme del Watch, notifiche, presenza) e lo raccoglie in un report senza dati segreti. Se qualcosa non va, salvalo e mandacelo."))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L("Copia report")) { copy() }
                    Button(L("Salva…")) { save() }
                    Button(L("Invia per email")) { email() }
                    Button(L("Apri una issue su GitHub")) { openIssue() }
                }
                if let status { Text(status).foregroundStyle(.secondary) }
            } header: {
                Text(L("Report"))
            }

            WatchDiagnostics(watch: model.watch, prefs: model.prefs)

            NtfyDiagnostics(relay: model.relay)

            RemindersDiagnostics(reminders: model.reminders, prefs: model.prefs)

            IconDiagnostics(icon: IconHealth.shared, prefs: model.prefs)

            Section {
                ScrollView {
                    Text(report)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 240)
            } header: {
                Text(L("Anteprima"))
            }
        }
        .formStyle(.grouped)
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
        Section {
            HStack(alignment: .top, spacing: 16) {
                if let preview = icon.preview {
                    Image(nsImage: preview).resizable().frame(width: 64, height: 64)
                        .accessibilityLabel(L("Anteprima dell'icona del bundle"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent(L("Icona compilata"), value: icon.tier)
                    LabeledContent(L("Parte visibile"), value: icon.coverage.map(IconMetrics.percent) ?? "-")
                    if let check = icon.buildCheck { LabeledContent(L("Controllo di build.sh"), value: check) }
                    if icon.fallbackActive {
                        Label(L("Risultava vuota: Nod mostra da solo l'icona classica."), systemImage: "arrow.uturn.backward.circle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            Toggle(L("Usa l'icona classica nel Dock"), isOn: $prefs.classicDockIcon)
        } header: {
            Text(L("Icona"))
        } footer: {
            Text(L("All'avvio Nod misura l'icona che il Dock disegna: se è vuota mette quella classica. Con questa opzione la classica resta sempre."))
                .foregroundStyle(.secondary)
        }
    }
}

private struct RemindersDiagnostics: View {
    @ObservedObject var reminders: ReminderRelay
    @ObservedObject var prefs: Preferences

    var body: some View {
        Section {
            RemindersControls(reminders: reminders, prefs: prefs)
            LabeledContent(L("Lista"), value: reminders.listStatus ?? "-")
            LabeledContent(L("Ultimo avviso"), value: reminders.lastAlert ?? "-")
        } header: {
            Text(L("Promemoria"))
        }
    }
}

private struct NtfyDiagnostics: View {
    @ObservedObject var relay: NotificationRelay

    var body: some View {
        Section {
            HStack {
                Button(L("Prova invio ntfy")) { Task { await relay.sendTest() } }
                if let event = relay.lastEvent { Text(event).foregroundStyle(.secondary) }
            }
            LabeledContent(L("Ultimo invio"), value: relay.lastPublish ?? "-")
            LabeledContent(L("Verifica sul server"), value: relay.lastServerCheck ?? "-")
            LabeledContent(L("Risposte"), value: relay.isListening ? L("In ascolto") : L("Non collegato"))
            NtfyAlertChecklist(relay: relay)
        } header: {
            Text(L("Notifiche"))
        } footer: {
            Text(L("Se la verifica sul server trova il messaggio ma l'avviso non compare, il percorso fino al server funziona: resta la consegna sull'iPhone (lista qui sopra)."))
                .foregroundStyle(.secondary)
        }
    }
}

private struct WatchDiagnostics: View {
    @ObservedObject var watch: WatchConfirmer
    @ObservedObject var prefs: Preferences

    var body: some View {
        Section {
            Picker(L("Metodo di conferma"), selection: $prefs.watchMethod) {
                ForEach(WatchMethod.allCases) { Text($0.title).tag($0) }
            }
            if prefs.watchMethod == .automatic, !watch.currentChain.isEmpty {
                LabeledContent(L("Ordine in automatico"), value: watch.currentChain.map(\.title).joined(separator: " → "))
            }
            HStack {
                Button(watch.isAsking ? L("Guarda il Watch…") : L("Prova ogni metodo del Watch")) {
                    Task { await watch.testAllMethods() }
                }
                .disabled(watch.isAsking || watch.isProbing)
                Button(watch.isProbing ? L("Guarda il Watch…") : L("Prova il Watch tramite osascript")) {
                    Task { await watch.probeViaOsascript() }
                }
                .disabled(watch.isAsking || watch.isProbing)
            }
            if let probe = watch.probeResult {
                LabeledContent(L("osascript (firmato Apple)"), value: probe)
            }
            ForEach(WatchMethod.concrete) { method in
                if let result = watch.methodResults[method] {
                    LabeledContent(method.title, value: result)
                }
            }
            if let last = watch.attempts.last {
                LabeledContent(L("Ultimo tentativo"), value: last.line)
            }
            if watch.needsTroubleshooting { WatchTroubleshooting(systemLevel: watch.systemRefusesWatch) }
        } header: {
            Text(L("Apple Watch"))
        } footer: {
            Text(L("Per ogni metodo compare la richiesta sul Mac: premi due volte il tasto laterale del Watch. Il metodo che funziona sceglilo qui sopra.")
                 + " " + L("La prova tramite osascript fa la stessa richiesta da un processo firmato Apple: se così il Watch la riceve, il limite è la firma di Nod."))
                .foregroundStyle(.secondary)
        }
    }
}
