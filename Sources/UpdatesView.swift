// Aggiornamenti a schermo: il pannello delle impostazioni e la scheda che compare in Stato quando c'è una nuova versione.

import SwiftUI

struct UpdatesSettings: View {
    @ObservedObject var updater: Updater
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGPage {
            SGSection {
                SGToggleRow(L("Controlla automaticamente (ogni 6 ore)"), isOn: $prefs.autoCheckUpdates)
                SGDivider()
                SGValueRow(L("Versione installata"), value: updater.currentVersion)
                SGDivider()
                SGValueRow(L("Ultimo controllo")) {
                    if let last = updater.lastCheck {
                        Text(last, style: .relative)
                    } else {
                        Text(L("Mai"))
                    }
                }
                SGDivider()
                SGRowBlock {
                    HStack(spacing: 10) {
                        Button(L("Controlla ora")) { Task { await updater.check() } }
                            .buttonStyle(.sgSecondary)
                            .disabled(updater.state == .checking)
                        UpdateStateText(updater: updater)
                    }
                }
            }
            if updater.isUpdateAvailable {
                UpdateCard(updater: updater)
            }
        }
    }
}

struct UpdateStateText: View {
    @ObservedObject var updater: Updater
    @Environment(\.sgAccent) private var accent

    var body: some View {
        switch updater.state {
        case .idle: EmptyView()
        case .checking: ProgressView().controlSize(.small)
        case .upToDate: NoteLabel(text: L("Nod è aggiornato."), symbol: "checkmark.circle.fill", tint: SG.Status.success)
        case .available(let version): NoteLabel(text: L("Disponibile la versione %@", version), symbol: "arrow.down.circle.fill",
                                                tint: accent.base)
        case .failed(let why): NoteLabel(text: why, symbol: "exclamationmark.triangle.fill")
        }
    }
}

/// Le novità della nuova versione e il comando per aggiornare. Una scheda a sé: l'unico pulsante principale è "Aggiorna".
struct UpdateCard: View {
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .available(let version) = updater.state {
                Label(L("Disponibile Nod %@", version), systemImage: "arrow.down.circle.fill")
                    .font(SG.Font.instruction)
                    .foregroundStyle(SG.Ink.primary)
            }
            if !updater.news.isEmpty {
                ChangelogList(entries: updater.news)
            }
            Text(L("Per aggiornare, esegui nel Terminale:")).font(SG.Font.body).foregroundStyle(SG.Ink.secondary)
            Text(updater.command)
                .font(SG.Font.value)
                .foregroundStyle(SG.Ink.primary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: SG.Radius.tile, style: .continuous).fill(SG.Fill.tile))
                .overlay(RoundedRectangle(cornerRadius: SG.Radius.tile, style: .continuous)
                    .strokeBorder(SG.Fill.rowBorder, lineWidth: SG.Stroke.hairline))
            HStack(spacing: 10) {
                Button(L("Copia comando")) { updater.copyCommand() }
                    .buttonStyle(.sgSecondary)
                Button(L("Aggiorna nel Terminale")) { updater.runInTerminal() }
                    .buttonStyle(.sgPrimary)
            }
            if let error = updater.terminalError {
                NoteLabel(text: error, symbol: "exclamationmark.triangle.fill")
            }
        }
        .contentCard()
    }
}
