// Nod > Impostazioni (⌘,): solo ciò che si cambia di rado. Due pannelli con la barra degli strumenti fissa.

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            GeneralSettings(prefs: model.prefs)
                .environmentObject(model)
                .tabItem { Label("Generale", systemImage: "gearshape") }
            NotificationSettings(prefs: model.prefs, relay: model.relay)
                .tabItem { Label("Notifiche", systemImage: "applewatch.radiowaves.left.and.right") }
        }
        .frame(width: 520)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Apri Nod all'accesso", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    if launchAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                }
            Toggle("Leggi ad alta voce le richieste di approvazione", isOn: $prefs.speakSummaries)
            LabeledContent("Configurazione") {
                Button("Ripeti configurazione…") { model.startSetup(.full) }
            }
            LabeledContent("Versione", value: model.appVersion)
        }
        .formStyle(.grouped)
        .frame(height: 260)
    }
}

private struct NotificationSettings: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var relay: NotificationRelay

    var body: some View {
        Form {
            ServerSettingsSection(prefs: prefs, relay: relay)
            Section {
                HStack {
                    Button("Invia notifica di prova") { Task { await relay.sendTest() } }
                    if let event = relay.lastEvent { Text(event).foregroundStyle(.secondary) }
                }
                Button("Nuovo topic…") { prefs.topic = Preferences.newTopic(); relay.restartListening() }
            } footer: {
                Text("Un nuovo topic scollega l'iPhone: dovrai iscriverti di nuovo in ntfy.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 380)
    }
}
