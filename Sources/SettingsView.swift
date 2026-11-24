// Nod > Impostazioni (⌘,): solo ciò che si cambia di rado. Cinque pannelli (Generale, Aspetto, Notifiche, Aggiornamenti,
// Info) con la barra a capsula di Sguardo che galleggia in fondo; righe su velo traslucido con filo da 1 pt (SGPage).

import AppKit
import ServiceManagement
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, notifications, updates, info
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: L("Generale")
        case .appearance: L("Aspetto")
        case .notifications: L("Notifiche")
        case .updates: L("Aggiornamenti")
        case .info: L("Info")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .notifications: "applewatch.radiowaves.left.and.right"
        case .updates: "arrow.down.circle"
        case .info: "info.circle"
        }
    }
}

struct SettingsView: View {
    static let size = CGSize(width: 580, height: 640)

    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch model.settingsTab {
                case .general: GeneralSettings(prefs: model.prefs).environmentObject(model)
                case .appearance: AppearanceSettings(prefs: model.prefs)
                case .notifications: NotificationSettings(prefs: model.prefs, relay: model.relay, reminders: model.reminders)
                case .updates: UpdatesSettings(updater: model.updater, prefs: model.prefs)
                case .info: InfoSettings(version: model.appVersion)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // La barra delle schede galleggia in fondo: le righe ci scorrono sotto (SGPage lascia lo spazio). ⌘1…⌘5.
            SGFloatingTabBar(SettingsTab.allCases.map { SGTab($0, title: $0.title, systemImage: $0.symbol) },
                             selection: $model.settingsTab, commandShortcuts: true)
                .padding(.bottom, SG.Size.tabBarBottomInset)
        }
        // In alto, sotto i semafori della finestra, il contenuto sfuma invece di tagliarsi di netto.
        .overlay(alignment: .top) { SGProgressiveBlur() }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(SGWindowBackground())
        // La barra del titolo è trasparente e la vista occupa tutta la finestra: senza questo la zona sicura in alto
        // spinge giù tutto e la barra delle schede finisce sul bordo inferiore.
        .ignoresSafeArea()
        .background(TransparentTitleBar())
    }
}

/// Barra del titolo trasparente e contenuto a tutta finestra per la scena Settings (il kit non ha questo pezzo).
private struct TransparentTitleBar: NSViewRepresentable {
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        }
    }

    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ nsView: Probe, context: Context) {}
}

// MARK: - Generale

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        SGPage {
            SGSection {
                SGToggleRow(L("Apri Nod all'accesso"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) {
                        if launchAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                    }
                SGDivider()
                SGToggleRow(L("Usa il movimento della testa (AirPods)"), isOn: $prefs.headMotionEnabled)
                SGDivider()
                SGToggleRow(L("Leggi ad alta voce le richieste di approvazione"), isOn: $prefs.speakSummaries)
            }
            SGSection {
                SGAccentRow(L("Colore d'accento"),
                            options: (app: L("Colore dell'app"), system: L("Colore di sistema"), custom: L("Personalizzato")),
                            appDefault: .nod)
                SGDivider()
                SGLabeledRow {
                    Text(L("Configurazione"))
                } trailing: {
                    Button(L("Ripeti configurazione…")) { model.startSetup(.full) }
                        .buttonStyle(.sgSecondary)
                }
            }
        }
    }
}

// MARK: - Aspetto

private struct AppearanceSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        SGPage {
            SGSection {
                SGMenuRow(L("Lingua"), selection: $prefs.language,
                          options: AppLanguage.allCases.map { (value: $0, title: $0.title) })
                SGDivider()
                SGLabeledRow {
                    Text(L("Tema"))
                } trailing: {
                    Picker(L("Tema"), selection: $prefs.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }
            }
            SGSection(L("Icona nella barra dei menu")) {
                SGRowBlock {
                    HStack(spacing: 16) {
                        ForEach(MenuBarStyle.allCases) { style in
                            MenuBarPreview(style: style, selected: prefs.menuBarStyle == style) { prefs.menuBarStyle = style }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

// MARK: - Notifiche

private struct NotificationSettings: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var relay: NotificationRelay
    @ObservedObject var reminders: ReminderRelay

    var body: some View {
        SGPage {
            ServerSettingsSection(prefs: prefs, relay: relay)
            SGSection {
                SGRowBlock {
                    HStack(spacing: 10) {
                        Button(L("Invia notifica di prova")) { Task { await relay.sendTest() } }
                            .buttonStyle(.sgSecondary)
                        if let event = relay.lastEvent { Text(event).font(SG.Font.field).foregroundStyle(SG.Ink.secondary) }
                    }
                }
                SGDivider()
                SGValueRow(L("Risposte"), value: relay.isListening ? L("In ascolto") : L("Non collegato"))
                SGDivider()
                SGRowBlock {
                    Button(L("Nuovo topic…")) { prefs.topic = Preferences.newTopic(); relay.restartListening() }
                        .buttonStyle(.sgSecondary)
                }
            } footer: {
                SGFootnote(L("Un nuovo topic scollega l'iPhone: dovrai iscriverti di nuovo in ntfy."))
            }
            SGSection(L("Promemoria")) {
                RemindersControls(reminders: reminders, prefs: prefs)
            }
        }
    }
}

// MARK: - Info

private struct InfoSettings: View {
    let version: String

    var body: some View {
        SGPage {
            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Text(L("Nod")).font(SG.Font.title)
                Text(L("Versione %@", version)).font(SG.Font.body).foregroundStyle(SG.Ink.secondary)
                Text(L("Approvazioni a mani libere e presenza per Cocaine, con AirPods e Apple Watch."))
                    .font(SG.Font.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SG.Ink.secondary)
                Rectangle().fill(SG.Fill.rowBorder).frame(height: SG.Stroke.hairline).padding(.horizontal, 60)
                Text(L("Sviluppato da %@", Developer.name)).font(SG.Font.bodyEmphasis)
                HStack(spacing: 20) {
                    Link(destination: Developer.github) {
                        Label("github.com/GGuidotz/nod", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: Developer.mail) { Label(Developer.email, systemImage: "envelope") }
                }
                .font(SG.Font.field)
                Text(L("Progetto indipendente, non affiliato a Cocaine.")).font(SG.Font.caption).foregroundStyle(SG.Ink.tertiary)
            }
            .frame(maxWidth: .infinity)
            .contentCard(padding: 28)
        }
    }
}
