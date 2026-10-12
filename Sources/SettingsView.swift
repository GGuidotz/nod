// Nod > Impostazioni (⌘,): solo ciò che si cambia di rado. Pannelli con la barra degli strumenti fissa:
// Generale, Aspetto, Notifiche, Info.

import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            GeneralSettings(prefs: model.prefs)
                .environmentObject(model)
                .tabItem { Label(L("Generale"), systemImage: "gearshape") }
            AppearanceSettings(prefs: model.prefs)
                .tabItem { Label(L("Aspetto"), systemImage: "paintpalette") }
            NotificationSettings(prefs: model.prefs, relay: model.relay)
                .tabItem { Label(L("Notifiche"), systemImage: "applewatch.radiowaves.left.and.right") }
            UpdatesSettings(updater: model.updater, prefs: model.prefs)
                .tabItem { Label(L("Aggiornamenti"), systemImage: "arrow.down.circle") }
            InfoSettings(version: model.appVersion)
                .tabItem { Label(L("Info"), systemImage: "info.circle") }
        }
        .frame(width: 540)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle(L("Apri Nod all'accesso"), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    if launchAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                }
            Toggle(L("Usa il movimento della testa (AirPods)"), isOn: $prefs.headMotionEnabled)
            Toggle(L("Leggi ad alta voce le richieste di approvazione"), isOn: $prefs.speakSummaries)
            LabeledContent(L("Configurazione")) {
                Button(L("Ripeti configurazione…")) { model.startSetup(.full) }
            }
        }
        .formStyle(.grouped)
        .frame(height: 250)
    }
}

private struct AppearanceSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Picker(L("Lingua"), selection: $prefs.language) {
                ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
            }
            Picker(L("Tema"), selection: $prefs.appearance) {
                ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Section(L("Icona nella barra dei menu")) {
                HStack(spacing: 16) {
                    ForEach(MenuBarStyle.allCases) { style in
                        MenuBarPreview(style: style, selected: prefs.menuBarStyle == style)
                            .onTapGesture { prefs.menuBarStyle = style }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(L("Icona %@", style.title))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 340)
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
                    Button(L("Invia notifica di prova")) { Task { await relay.sendTest() } }
                    if let event = relay.lastEvent { Text(event).foregroundStyle(.secondary) }
                }
                LabeledContent(L("Risposte")) {
                    Text(relay.isListening ? L("In ascolto") : L("Non collegato")).foregroundStyle(.secondary)
                }
                Button(L("Nuovo topic…")) { prefs.topic = Preferences.newTopic(); relay.restartListening() }
            } footer: {
                Text(L("Un nuovo topic scollega l'iPhone: dovrai iscriverti di nuovo in ntfy.")).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 400)
    }
}

private struct InfoSettings: View {
    let version: String

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(L("Nod")).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(L("Versione %@", version)).foregroundStyle(.secondary)
            Text(L("Approvazioni a mani libere e presenza per Cocaine, con AirPods e Apple Watch."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Divider().padding(.horizontal, 60)
            Text(L("Sviluppato da %@", Developer.name)).font(.headline)
            HStack(spacing: 20) {
                Link(destination: Developer.github) {
                    Label("github.com/GGuidotz/nod", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: Developer.mail) { Label(Developer.email, systemImage: "envelope") }
            }
            Text(L("Progetto indipendente, non affiliato a Cocaine.")).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}
