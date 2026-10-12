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
                .tabItem { Label("Generale", systemImage: "gearshape") }
            AppearanceSettings(prefs: model.prefs)
                .tabItem { Label("Aspetto", systemImage: "paintpalette") }
            NotificationSettings(prefs: model.prefs, relay: model.relay)
                .tabItem { Label("Notifiche", systemImage: "applewatch.radiowaves.left.and.right") }
            InfoSettings(version: model.appVersion)
                .tabItem { Label("Info", systemImage: "info.circle") }
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
            Toggle("Apri Nod all'accesso", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    if launchAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                }
            Toggle("Usa il movimento della testa (AirPods)", isOn: $prefs.headMotionEnabled)
            Toggle("Leggi ad alta voce le richieste di approvazione", isOn: $prefs.speakSummaries)
            LabeledContent("Configurazione") {
                Button("Ripeti configurazione…") { model.startSetup(.full) }
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
            Picker("Tema", selection: $prefs.appearance) {
                ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Section("Icona nella barra dei menu") {
                HStack(spacing: 16) {
                    ForEach(MenuBarStyle.allCases) { style in
                        MenuBarPreview(style: style, selected: prefs.menuBarStyle == style)
                            .onTapGesture { prefs.menuBarStyle = style }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Icona \(style.title)")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 300)
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
                LabeledContent("Risposte") {
                    Text(relay.isListening ? "In ascolto" : "Non collegato").foregroundStyle(.secondary)
                }
                Button("Nuovo topic…") { prefs.topic = Preferences.newTopic(); relay.restartListening() }
            } footer: {
                Text("Un nuovo topic scollega l'iPhone: dovrai iscriverti di nuovo in ntfy.").foregroundStyle(.secondary)
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
            Text("Nod").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Versione \(version)").foregroundStyle(.secondary)
            Text("Approvazioni a mani libere e presenza per Cocaine, con AirPods e Apple Watch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Divider().padding(.horizontal, 60)
            Text("Sviluppato da \(Developer.name)").font(.headline)
            HStack(spacing: 20) {
                Link(destination: Developer.github) {
                    Label("github.com/GGuidotz/nod", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: Developer.mail) { Label(Developer.email, systemImage: "envelope") }
            }
            Text("Progetto indipendente, non affiliato a Cocaine.").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}
