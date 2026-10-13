// Pezzi d'interfaccia condivisi tra configurazione, finestra principale e impostazioni.

import AppKit
import SwiftUI

/// L'elemento distintivo di Nod: le AirPods disegnate seguono la tua testa in tempo reale. Con Riduci movimento restano
/// ferme e i gradi sono scritti sotto.
struct HeadIndicator: View {
    @ObservedObject var head: HeadMotionMonitor
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "airpodspro")
                .font(.system(size: size * 0.5, weight: .regular))
                .foregroundStyle(head.isConnected ? Color.accentColor : Color.secondary)
                .frame(width: size, height: size)
                .background(Circle().fill(.quaternary))
                .rotation3DEffect(.radians(reduceMotion ? 0 : head.pitch), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.radians(reduceMotion ? 0 : head.yaw), axis: (x: 0, y: 1, z: 0))
                .rotationEffect(.radians(reduceMotion ? 0 : -head.roll))
            if reduceMotion, head.isConnected {
                Text(L("su/giù %.0f°  destra/sinistra %.0f°", head.pitch * 180 / .pi, head.yaw * 180 / .pi))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(head.isConnected ? L("AirPods indossate") : L("AirPods non indossate"))
    }
}

/// Una riga di stato: simbolo, testo e un'etichetta che non si affida al solo colore.
struct StatusRow: View {
    let title: String
    let value: String
    let ok: Bool
    var symbol: String? = nil

    var body: some View {
        LabeledContent {
            Label(value, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ok ? Color.green : Color.orange)
                .labelStyle(.titleAndIcon)
        } label: {
            if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
        }
    }
}

/// Cosa controllare quando le richieste solo-Watch falliscono subito: macOS non le manda al Watch. Con `systemLevel`
/// (rifiutata anche a osascript, firmato Apple) il limite è del sistema: lo dice e propone l'unico rimedio noto.
struct WatchTroubleshooting: View {
    var systemLevel = false

    private var items: [String] {
        if systemLevel {
            return [L("Impostazioni di Sistema > Touch ID e password: spegni e riaccendi l'opzione Apple Watch, poi riavvia il Mac e il Watch."),
                    L("Watch al polso e sbloccato, con il rilevamento del polso attivo (app Watch sull'iPhone > Codice).")]
        }
        return [L("Impostazioni di Sistema > Touch ID e password: \"Usa Apple Watch per sbloccare app e Mac\" attivo."),
                L("Watch al polso e sbloccato, con il rilevamento del polso attivo (app Watch sull'iPhone > Codice)."),
                L("Bluetooth e Wi-Fi accesi sul Mac; Mac e Watch con lo stesso Apple ID."),
                L("Prova con un'app Apple, per esempio Password: se neanche lì il Watch propone il doppio clic, è un'impostazione del sistema."),
                L("Altrimenti Diagnostica > \"Prova il Watch tramite osascript\": se così funziona, il limite è la firma di Nod.")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(systemLevel ? L("Su questo Mac il doppio clic sul Watch non è disponibile: macOS lo rifiuta a ogni app, anche a quelle Apple.")
                              : L("macOS non manda la richiesta al Watch. Controlla:"),
                  systemImage: "exclamationmark.applewatch")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            if systemLevel { Text(L("Puoi ancora provare:")).font(.callout) }
            ForEach(items, id: \.self) { item in
                Text("• " + item).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            Text(systemLevel ? L("Intanto approvi con Touch ID al Mac e, da lontano, con la notifica o l'avviso di Promemoria.")
                             : L("Intanto Nod usa Touch ID: al Mac approvi col dito."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Dalla 0.4.1, per tutti: il doppio clic sul Watch è sperimentale. Su macOS 27 chiude la richiesta ma il sistema risponde
/// "annullato" a ogni app, e serve un fix di Apple. Le risposte a distanza che funzionano.
struct WatchDoubleClickNotice: View {
    var body: some View {
        Label(L("Doppio clic sul tasto laterale del Watch: sperimentale, in attesa di un fix di Apple. Su macOS 27 il sistema chiude la richiesta ma risponde \"annullato\" a ogni app, anche a quelle Apple. Intanto rispondi dal Watch con la notifica ntfy (Approva o Nega) o completando il promemoria (approva)."),
              systemImage: "exclamationmark.applewatch")
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Promemoria come secondo canale verso il Watch: permesso, interruttore e prova. Nelle Impostazioni, nella
/// configurazione e in Diagnostica.
struct RemindersControls: View {
    @ObservedObject var reminders: ReminderRelay
    @ObservedObject var prefs: Preferences

    private var enabled: Binding<Bool> {
        Binding(get: { prefs.remindersEnabled && reminders.access == .granted },
                set: { on in
                    if on, reminders.access != .granted { Task { await reminders.requestAccess() } } else { prefs.remindersEnabled = on }
                })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L("Avvisi anche con Promemoria"), isOn: enabled)
            Text(L("Nod crea un promemoria nella lista \"Nod\" di iCloud: l'avviso arriva su iPhone e Watch senza app da installare, di solito entro un minuto. Completarlo dal Watch vale come risposta (Approva, Tieni sveglio)."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                if reminders.access != .granted {
                    Button(L("Consenti l'accesso a Promemoria")) { Task { await reminders.requestAccess() } }
                }
                Button(L("Prova Promemoria")) { reminders.sendTest() }
                    .disabled(reminders.access != .granted)
            }
            Text(L("Nella prova: quando l'avviso arriva sul Watch, toccalo e scegli Completato."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let event = reminders.lastEvent {
                Text(event).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { reminders.refreshAccess() }
    }
}

/// Giorni della settimana come pulsanti attivabili, da lunedì.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    /// Da lunedì: (giorno di Calendar, iniziale, nome per VoiceOver) nella lingua dell'app.
    private var days: [(Int, String, String)] { Weekdays.ordered }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { day in
                Toggle(isOn: Binding(get: { selection.contains(day.0) },
                                     set: { on in if on { selection.insert(day.0) } else { selection.remove(day.0) } })) {
                    Text(day.1).frame(width: 18)
                }
                .toggleStyle(.button)
                .accessibilityLabel(day.2)
            }
        }
    }
}

/// La regola "mi sto allontanando": app, giorni, fascia oraria, attese. Sotto, la regola scritta per intero.
struct PresenceRuleEditor: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Section {
            ForEach(WatchedApp.suggestions) { app in
                Toggle(app.name, isOn: Binding(
                    get: { prefs.leavingRule.apps.contains(app) },
                    set: { on in
                        if on { prefs.leavingRule.apps.append(app) } else { prefs.leavingRule.apps.removeAll { $0 == app } }
                    }))
            }
        } header: {
            Text(L("Con una di queste app aperta"))
        }
        Section {
            LabeledContent(L("Giorni")) { WeekdayPicker(selection: $prefs.leavingRule.schedule.weekdays) }
            DatePicker(L("Dalle"), selection: minutes(\.startMinutes), displayedComponents: .hourAndMinute)
            DatePicker(L("Alle"), selection: minutes(\.endMinutes), displayedComponents: .hourAndMinute)
        } header: {
            Text(L("Nella tua fascia oraria"))
        }
        Section {
            Stepper(L("Ti consideriamo in uscita dopo %d s senza usare il Mac", prefs.leavingIdleSeconds),
                    value: $prefs.leavingIdleSeconds, in: 15...600, step: 15)
            Stepper(L("Aspetta la tua risposta %d min", prefs.leavingRule.timeoutMinutes),
                    value: $prefs.leavingRule.timeoutMinutes, in: 1...30)
        } header: {
            Text(L("Tempi"))
        } footer: {
            Text(Self.summary(prefs.leavingRule)).foregroundStyle(.secondary)
        }
    }

    /// La regola scritta per intero, aggiornata mentre la modifichi.
    static func summary(_ r: LeavingRule) -> String {
        let apps = r.apps.map(\.name).formatted(.list(type: .or).locale(Localization.locale))
        guard !r.apps.isEmpty, !r.schedule.weekdays.isEmpty else {
            return L("Senza app o giorni scelti, quando non rispondi non succede niente.")
        }
        return L("Se ti allontani con %@ aperto, nei giorni scelti tra %@ e %@, e non rispondi entro %d min, Cocaine tiene sveglio il Mac. Altrimenti non succede niente. Quando torni, Cocaine torna com'era.",
                 apps, clock(r.schedule.startMinutes), clock(r.schedule.endMinutes), r.timeoutMinutes)
    }

    private static func clock(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }

    /// Minuti dalla mezzanotte <-> Date per il DatePicker.
    private func minutes(_ key: WritableKeyPath<WorkSchedule, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(prefs.leavingRule.schedule[keyPath: key] * 60)) },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                prefs.leavingRule.schedule[keyPath: key] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }
}

/// Server ntfy: ntfy.sh (predefinito) o un server tuo, con token di accesso nel Portachiavi.
struct ServerSettingsSection: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var relay: NotificationRelay
    @State private var token = Keychain.read("ntfy-token") ?? ""

    var body: some View {
        Section {
            Picker(L("Server"), selection: $prefs.serverChoice) {
                ForEach(NtfyServerChoice.allCases) { Text($0.title).tag($0) }
            }
            if prefs.serverChoice == .own {
                TextField(L("Indirizzo"), text: $prefs.ownServerURL, prompt: Text(verbatim: "https://ntfy.example.com"))
                SecureField(L("Token di accesso"), text: $token, prompt: Text(verbatim: "tk_…"))
                    .onSubmit { relay.restartListening() }
                    .onChange(of: token) { Keychain.write(token, for: "ntfy-token") }
            }
            LabeledContent(L("Topic")) {
                HStack {
                    Text(prefs.topic).font(.body.monospaced()).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    Button(L("Copia")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(prefs.topic, forType: .string)
                    }
                }
            }
        } header: {
            Text(L("Server delle notifiche"))
        } footer: {
            Text(prefs.serverChoice == .ntfySh
                 ? L("Su ntfy.sh il gestore del servizio può leggere il testo delle notifiche: Nod lo tiene al minimo. Un server tuo lo evita.")
                 : L("Con un server tuo il contenuto resta lì; a ntfy.sh arriva solo un avviso senza testo, che serve all'iPhone per riceverlo subito."))
                .foregroundStyle(.secondary)
        }
        .onChange(of: prefs.serverChoice) { relay.restartListening() }
    }
}

/// I giorni da lunedì a domenica nella lingua dell'app: (numero di Calendar, iniziale, nome intero).
enum Weekdays {
    static var ordered: [(Int, String, String)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Localization.locale
        let short = calendar.veryShortStandaloneWeekdaySymbols, full = calendar.standaloneWeekdaySymbols
        return [2, 3, 4, 5, 6, 7, 1].map { ($0, short[$0 - 1], full[$0 - 1]) }
    }
}
