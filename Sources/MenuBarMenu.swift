// Il menu dell'icona nella barra dei menu (un menu, non un popover: HIG, The menu bar).

import AppKit
import SwiftUI

struct MenuBarMenu: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuContent(presence: model.presence, cocaine: model.cocaine, approvals: model.approvals)
        Divider()
        Button("Apri Nod") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Impostazioni…") }
            .keyboardShortcut(",")
        Divider()
        Button("Esci da Nod") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private struct MenuContent: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var cocaine: CocaineBridge
    @ObservedObject var approvals: ApprovalFlow

    var body: some View {
        Text("Presenza: \(presence.state.title)")
        if presence.state == .here {
            Button("Sto uscendo…") { presence.markLeaving(manual: true) }
        } else {
            Button("Sono al Mac") { presence.markHere(manual: true) }
        }
        Divider()
        if cocaine.isInstalled {
            Button(cocaine.status?.on == true ? "Spegni Cocaine" : "Tieni sveglio ora") {
                Task { if cocaine.status?.on == true { await cocaine.stopKeepingAwake() } else { await cocaine.keepAwake() } }
            }
        }
        Button("Prova un'approvazione") { approvals.demo() }
    }
}
