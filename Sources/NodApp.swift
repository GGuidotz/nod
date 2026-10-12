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
                .frame(minWidth: 780, minHeight: 620)
        }
        .defaultSize(width: 920, height: 680)
        .commands { NodCommands(model: model) }

        Settings {
            SettingsView()
                .environmentObject(model)
        }

        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(model)
        } label: {
            MenuBarLabel(presence: model.presence, prefs: model.prefs)
        }
    }
}

/// L'icona nella barra dei menu segue lo stato della presenza.
struct MenuBarLabel: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var prefs: Preferences

    var body: some View {
        Image(nsImage: MenuBarGlyph.image(state: presence.state, style: prefs.menuBarStyle))
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
        CommandGroup(replacing: .appInfo) {
            Button("Informazioni su Nod") { AboutPanel.show() }
        }
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
