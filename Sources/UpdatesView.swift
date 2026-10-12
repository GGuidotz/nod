// Aggiornamenti a schermo: il pannello delle impostazioni e la scheda che compare in Stato quando c'è una nuova versione.

import SwiftUI

struct UpdatesSettings: View {
    @ObservedObject var updater: Updater
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Toggle(L("Controlla automaticamente (ogni 6 ore)"), isOn: $prefs.autoCheckUpdates)
            LabeledContent(L("Versione installata"), value: updater.currentVersion)
            LabeledContent(L("Ultimo controllo")) {
                if let last = updater.lastCheck {
                    Text(last, style: .relative)
                } else {
                    Text(L("Mai"))
                }
            }
            HStack {
                Button(L("Controlla ora")) { Task { await updater.check() } }
                    .disabled(updater.state == .checking)
                UpdateStateText(updater: updater)
            }
            if updater.isUpdateAvailable {
                UpdateCard(updater: updater)
            }
        }
        .formStyle(.grouped)
        .frame(height: 420)
    }
}

struct UpdateStateText: View {
    @ObservedObject var updater: Updater

    var body: some View {
        switch updater.state {
        case .idle: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .upToDate: Label(L("Nod è aggiornato."), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .available(let version): Label(L("Disponibile la versione %@", version), systemImage: "arrow.down.circle.fill")
            .foregroundStyle(Brand.accent)
        case .failed(let why): Text(why).foregroundStyle(.orange)
        }
    }
}

/// Le novità della nuova versione e il comando per aggiornare.
struct UpdateCard: View {
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .available(let version) = updater.state {
                Label(L("Disponibile Nod %@", version), systemImage: "arrow.down.circle.fill")
                    .font(.headline)
            }
            if !updater.news.isEmpty {
                ChangelogList(entries: updater.news)
            }
            Text(L("Per aggiornare, esegui nel Terminale:")).foregroundStyle(.secondary)
            Text(updater.command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            HStack {
                Button(L("Copia comando")) { updater.copyCommand() }
                Button(L("Aggiorna nel Terminale")) { updater.runInTerminal() }
                    .primaryButton()
            }
            if let error = updater.terminalError {
                Text(error).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
