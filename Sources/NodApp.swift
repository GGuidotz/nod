// Nod: approvazioni a mani libere e presenza per Cocaine, con AirPods e Apple Watch.
// Scene: la finestra principale (barra laterale), le Impostazioni (⌘,) e l'extra nella barra dei menu.

import AppKit
import SwiftUI

@main
struct NodApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("Nod", id: "main") {
            MainView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 500)
        }
        .defaultSize(width: 880, height: 580)
        .commands { NodCommands(model: model) }

        Settings {
            SettingsView()
                .environmentObject(model)
        }

        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(model)
        } label: {
            MenuBarLabel(presence: model.presence)
        }
    }
}

/// L'icona nella barra dei menu segue lo stato della presenza.
struct MenuBarLabel: View {
    @ObservedObject var presence: PresenceEngine

    var body: some View {
        Image(systemName: presence.state.symbol)
            .accessibilityLabel("Nod, \(presence.state.title)")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in AppModel.shared.didLaunch() }
    }

    /// Chiudere la finestra non chiude l'app: resta nella barra dei menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Comandi della barra dei menu: ogni azione dell'app è raggiungibile anche da qui.
struct NodCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Novità di Nod…") { model.showWhatsNew() }
            Button("Ripeti configurazione…") { model.startSetup(.full) }
        }
        CommandMenu("Presenza") {
            Button("Sono al Mac") { model.presence.markHere(manual: true) }
            Button("Sto uscendo…") { model.presence.markLeaving(manual: true) }
            Divider()
            Button("Invia notifica di prova") { Task { await model.relay.sendTest() } }
        }
    }
}
