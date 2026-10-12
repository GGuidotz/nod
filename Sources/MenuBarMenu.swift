// Il menu dell'icona nella barra dei menu (un menu, non un popover: HIG, The menu bar).

import AppKit
import SwiftUI

struct MenuBarMenu: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuContent(presence: model.presence, cocaine: model.cocaine, approvals: model.approvals)
        UpdateMenuItem(updater: model.updater)
        Divider()
        Button(L("Apri Nod")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text(L("Impostazioni…")) }
            .keyboardShortcut(",")
        Divider()
        Button(L("Esci da Nod")) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private struct MenuContent: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var cocaine: CocaineBridge
    @ObservedObject var approvals: ApprovalFlow

    var body: some View {
        Text(L("Presenza: %@", presence.state.title))
        if presence.state == .here {
            Button(L("Sto uscendo…")) { presence.markLeaving(manual: true) }
        } else {
            Button(L("Sono al Mac")) { presence.markHere(manual: true) }
        }
        Divider()
        if cocaine.isInstalled {
            Button(cocaine.status?.on == true ? L("Spegni Cocaine") : L("Tieni sveglio ora")) {
                Task { if cocaine.status?.on == true { await cocaine.stopKeepingAwake() } else { await cocaine.keepAwake() } }
            }
        }
        Button(L("Prova un'approvazione")) { approvals.demo() }
    }
}

private struct UpdateMenuItem: View {
    @ObservedObject var updater: Updater

    var body: some View {
        if case .available(let version) = updater.state {
            Divider()
            Button(L("Aggiorna a Nod %@ nel Terminale", version)) { updater.runInTerminal() }
            Button(L("Copia il comando di aggiornamento")) { updater.copyCommand() }
        }
    }
}
