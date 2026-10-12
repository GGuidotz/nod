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
            LanguageRoot(prefs: model.prefs) { MainView() }
                .environmentObject(model)
                .frame(minWidth: 780, minHeight: 620)
        }
        .defaultSize(width: 920, height: 680)
        .commands { NodCommands(model: model, prefs: model.prefs) }

        Settings {
            LanguageRoot(prefs: model.prefs) { SettingsView() }
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

/// Ricostruisce l'interfaccia quando cambi lingua, così ogni testo passa di nuovo da L().
struct LanguageRoot<Content: View>: View {
    @ObservedObject var prefs: Preferences
    @ViewBuilder var content: Content

    var body: some View {
        content.id(prefs.language)
    }
}

/// L'icona nella barra dei menu segue lo stato della presenza.
struct MenuBarLabel: View {
    @ObservedObject var presence: PresenceEngine
    @ObservedObject var prefs: Preferences

    var body: some View {
        Image(nsImage: MenuBarGlyph.image(state: presence.state, style: prefs.menuBarStyle))
            .accessibilityLabel("Nod, " + presence.state.title)
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
    /// Osservato perché i comandi cambino lingua insieme al resto.
    @ObservedObject var prefs: Preferences

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L("Informazioni su Nod")) { AboutPanel.show() }
        }
        CommandGroup(after: .appInfo) {
            Button(L("Novità di Nod…")) { model.showWhatsNew() }
            Button(L("Ripeti configurazione…")) { model.startSetup(.full) }
            Button(L("Controlla aggiornamenti…")) {
                model.selection = .status
                Task { await model.updater.check() }
            }
        }
        CommandGroup(replacing: .help) {
            Button(L("Diagnostica di Nod")) { model.selection = .diagnostics; NSApp.activate(ignoringOtherApps: true) }
            Link(L("Nod su GitHub"), destination: Developer.github)
        }
        CommandMenu(L("Presenza")) {
            Button(L("Sono al Mac")) { model.presence.markHere(manual: true) }
            Button(L("Sto uscendo…")) { model.presence.markLeaving(manual: true) }
            Divider()
            Button(L("Invia notifica di prova")) { Task { await model.relay.sendTest() } }
        }
    }
}
