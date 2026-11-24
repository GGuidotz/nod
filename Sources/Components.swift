// Pezzi d'interfaccia condivisi tra configurazione, finestra principale e impostazioni. Righe, capsule e riempimenti
// vengono da Sguardo (Vendor/Sguardo); qui ci sono i pezzi propri di Nod e quelli che il kit non ha (campo di testo
// nelle finestre, nota con simbolo colorato).

import AppKit
import SwiftUI

/// L'elemento distintivo di Nod: le AirPods disegnate seguono la tua testa in tempo reale. Con Riduci movimento restano
/// ferme e i gradi sono scritti sotto.
struct HeadIndicator: View {
    @ObservedObject var head: HeadMotionMonitor
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sgAccent) private var accent

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "airpodspro")
                .font(.system(size: size * 0.5, weight: .regular))
                .foregroundStyle(head.isConnected ? accent.base : SG.Ink.secondary)
                .frame(width: size, height: size)
                .background(Circle().fill(SG.Fill.tile))
                .overlay(Circle().strokeBorder(SG.Fill.rowBorder, lineWidth: SG.Stroke.hairline))
                .rotation3DEffect(.radians(reduceMotion ? 0 : head.pitch), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.radians(reduceMotion ? 0 : head.yaw), axis: (x: 0, y: 1, z: 0))
                .rotationEffect(.radians(reduceMotion ? 0 : -head.roll))
            if reduceMotion, head.isConnected {
                Text(L("su/giù %.0f°  destra/sinistra %.0f°", head.pitch * 180 / .pi, head.yaw * 180 / .pi))
                    .font(SG.Font.caption).monospacedDigit().foregroundStyle(SG.Ink.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(head.isConnected ? L("AirPods indossate") : L("AirPods non indossate"))
    }
}

/// Una nota con un simbolo colorato: il colore sta solo nel simbolo, il testo resta nell'inchiostro normale (leggibile
/// anche con il giallo di avviso su fondo chiaro) e lo stato è sempre scritto in parole. Il kit non ha questo pezzo.
struct NoteLabel: View {
    let text: String
    let symbol: String
    var tint: Color = SG.Status.warning
    var ink: Color = SG.Ink.primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            Text(text).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
        }
        .font(SG.Font.body)
        .accessibilityElement(children: .combine)
    }
}

/// Campo di testo a capsula per le finestre (il kit ha solo quello per l'isola scura): fondo del selettore e filo da 1 pt.
struct NodField: View {
    let title: String
    @Binding var text: String
    var prompt: String
    var secure = false
    var width: CGFloat = 240

    var body: some View {
        Group {
            if secure {
                SecureField(title, text: $text, prompt: Text(verbatim: prompt))
            } else {
                TextField(title, text: $text, prompt: Text(verbatim: prompt))
            }
        }
        .textFieldStyle(.plain)
        .labelsHidden()
        .font(SG.Font.field)
        .foregroundStyle(SG.Ink.primary)
        .padding(.horizontal, 12)
        .frame(width: width, height: 28)
        .background(Capsule().fill(SG.Fill.pickerPill))
        .overlay(Capsule().strokeBorder(SG.Fill.rowBorder, lineWidth: SG.Stroke.hairline))
        .accessibilityLabel(title)
    }
}

/// Una riga di stato: simbolo, testo e un'etichetta che non si affida al solo colore.
struct StatusRow: View {
    let title: String
    let value: String
    let ok: Bool
    var symbol: String? = nil

    var body: some View {
        SGLabeledRow {
            if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
        } trailing: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(ok ? SG.Status.success : SG.Status.warning)
                Text(value).foregroundStyle(SG.Ink.secondary)
            }
            .font(SG.Font.body)
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
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
            NoteLabel(text: systemLevel ? L("Su questo Mac il doppio clic sul Watch non è disponibile: macOS lo rifiuta a ogni app, anche a quelle Apple.")
                                        : L("macOS non manda la richiesta al Watch. Controlla:"),
                      symbol: "exclamationmark.applewatch")
            if systemLevel { Text(L("Puoi ancora provare:")).font(SG.Font.field) }
            ForEach(items, id: \.self) { item in
                Text("• " + item).font(SG.Font.field).fixedSize(horizontal: false, vertical: true)
            }
            Text(systemLevel ? L("Intanto approvi con Touch ID al Mac e, da lontano, con la notifica o l'avviso di Promemoria.")
                             : L("Intanto Nod usa Touch ID: al Mac approvi col dito."))
                .font(SG.Font.field).foregroundStyle(SG.Ink.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Dalla 0.4.1, per tutti: il doppio clic sul Watch è sperimentale. Su macOS 27 chiude la richiesta ma il sistema risponde
/// "annullato" a ogni app, e serve un fix di Apple. Le risposte a distanza che funzionano.
struct WatchDoubleClickNotice: View {
    var body: some View {
        NoteLabel(text: L("Doppio clic sul tasto laterale del Watch: sperimentale, in attesa di un fix di Apple. Su macOS 27 il sistema chiude la richiesta ma risponde \"annullato\" a ogni app, anche a quelle Apple. Intanto rispondi dal Watch con la notifica ntfy (Approva o Nega) o completando il promemoria (approva)."),
                  symbol: "exclamationmark.applewatch")
    }
}

/// Promemoria come secondo canale verso il Watch: permesso, interruttore e prova. Sono righe da mettere in un gruppo
/// (`SGSection`, `SGGroup`): nelle Impostazioni, nella configurazione e in Diagnostica.
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
        VStack(spacing: 0) {
            SGToggleRow(L("Avvisi anche con Promemoria"), isOn: enabled)
            SGDivider()
            SGRowBlock {
                VStack(alignment: .leading, spacing: 10) {
                    SGFootnote(L("Nod crea un promemoria nella lista \"Nod\" di iCloud: l'avviso arriva su iPhone e Watch senza app da installare, di solito entro un minuto. Completarlo dal Watch vale come risposta (Approva, Tieni sveglio)."))
                    HStack {
                        if reminders.access != .granted {
                            Button(L("Consenti l'accesso a Promemoria")) { Task { await reminders.requestAccess() } }
                                .buttonStyle(.sgSecondary)
                        }
                        Button(L("Prova Promemoria")) { reminders.sendTest() }
                            .buttonStyle(.sgSecondary)
                            .disabled(reminders.access != .granted)
                    }
                    SGFootnote(L("Nella prova: quando l'avviso arriva sul Watch, toccalo e scegli Completato."))
                    if let event = reminders.lastEvent { SGFootnote(event) }
                }
            }
        }
        .onAppear { reminders.refreshAccess() }
    }
}

/// Giorni della settimana come capsule attivabili, da lunedì. Il giorno scelto ha l'anello e il velo dell'accento.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    @Environment(\.sgAccent) private var accent
    /// Da lunedì: (giorno di Calendar, iniziale, nome per VoiceOver) nella lingua dell'app.
    private var days: [(Int, String, String)] { Weekdays.ordered }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { day in
                let on = selection.contains(day.0)
                Button {
                    withAnimation(SG.Motion.respecting(SG.Motion.snappy)) {
                        if on { selection.remove(day.0) } else { selection.insert(day.0) }
                    }
                } label: {
                    Text(day.1)
                        .font(SG.Font.label)
                        .foregroundStyle(on ? SG.Ink.primary : SG.Ink.secondary)
                        .frame(width: 26, height: 26)
                        .background(Capsule().fill(on ? accent.selectedWash : SG.Fill.pickerPill))
                        .overlay(Capsule().strokeBorder(on ? accent.base : SG.Fill.rowBorder, lineWidth: on ? 1.5 : SG.Stroke.hairline))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.2)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// La regola "mi sto allontanando": app, giorni, fascia oraria, attese. Sotto, la regola scritta per intero. Sono tre
/// gruppi (`SGSection`) da mettere in una pagina.
struct PresenceRuleEditor: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Group {
            SGSection(L("Con una di queste app aperta")) {
                ForEach(Array(WatchedApp.suggestions.enumerated()), id: \.element.id) { index, app in
                    if index > 0 { SGDivider() }
                    SGToggleRow(app.name, isOn: Binding(
                        get: { prefs.leavingRule.apps.contains(app) },
                        set: { on in
                            if on { prefs.leavingRule.apps.append(app) } else { prefs.leavingRule.apps.removeAll { $0 == app } }
                        }))
                }
            }
            SGSection(L("Nella tua fascia oraria")) {
                SGLabeledRow { Text(L("Giorni")) } trailing: { WeekdayPicker(selection: $prefs.leavingRule.schedule.weekdays) }
                SGDivider()
                SGLabeledRow { Text(L("Dalle")) } trailing: {
                    DatePicker(L("Dalle"), selection: minutes(\.startMinutes), displayedComponents: .hourAndMinute).labelsHidden()
                }
                SGDivider()
                SGLabeledRow { Text(L("Alle")) } trailing: {
                    DatePicker(L("Alle"), selection: minutes(\.endMinutes), displayedComponents: .hourAndMinute).labelsHidden()
                }
            }
            SGSection(L("Tempi")) {
                let idle = L("Ti consideriamo in uscita dopo %d s senza usare il Mac", prefs.leavingIdleSeconds)
                SGLabeledRow { Text(idle) } trailing: {
                    Stepper(idle, value: $prefs.leavingIdleSeconds, in: 15...600, step: 15).labelsHidden()
                }
                SGDivider()
                let wait = L("Aspetta la tua risposta %d min", prefs.leavingRule.timeoutMinutes)
                SGLabeledRow { Text(wait) } trailing: {
                    Stepper(wait, value: $prefs.leavingRule.timeoutMinutes, in: 1...30).labelsHidden()
                }
            } footer: {
                SGFootnote(Self.summary(prefs.leavingRule))
            }
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

/// Server ntfy: ntfy.sh (predefinito) o un server tuo, con token di accesso nel Portachiavi. Un gruppo (`SGSection`).
struct ServerSettingsSection: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var relay: NotificationRelay
    @State private var token = Keychain.read("ntfy-token") ?? ""
    @State private var replyToken = Keychain.read("ntfy-reply-token") ?? ""

    var body: some View {
        SGSection(L("Server delle notifiche")) {
            SGMenuRow(L("Server"), selection: $prefs.serverChoice,
                      options: NtfyServerChoice.allCases.map { (value: $0, title: $0.title) })
            if prefs.serverChoice == .own {
                SGDivider()
                SGLabeledRow { Text(L("Indirizzo")) } trailing: {
                    NodField(title: L("Indirizzo"), text: $prefs.ownServerURL, prompt: "https://ntfy.example.com")
                }
                SGDivider()
                SGLabeledRow { Text(L("Token di accesso")) } trailing: {
                    NodField(title: L("Token di accesso"), text: $token, prompt: "tk_…", secure: true)
                        .onSubmit { relay.restartListening() }
                        .onChange(of: token) { Keychain.write(token, for: "ntfy-token") }
                }
                SGDivider()
                SGLabeledRow { Text(L("Token per i pulsanti")) } trailing: {
                    NodField(title: L("Token per i pulsanti"), text: $replyToken, prompt: "tk_…", secure: true)
                        .onChange(of: replyToken) { Keychain.write(replyToken, for: "ntfy-reply-token") }
                }
                SGDivider()
                SGRowBlock {
                    SGFootnote(L("Facoltativo. I pulsanti delle notifiche restano scritti sul server e sull'iPhone: usa un token con permesso di sola scrittura sul topic di risposta (nome del topic + \"-r\"), mai quello principale. Senza, i pulsanti non portano nessun token."))
                }
            }
            SGDivider()
            SGLabeledRow { Text(L("Topic")) } trailing: {
                HStack(spacing: 10) {
                    Text(prefs.topic).font(SG.Font.value).foregroundStyle(SG.Ink.secondary)
                        .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    Button(L("Copia")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(prefs.topic, forType: .string)
                    }
                    .buttonStyle(.sgSecondary)
                }
            }
        } footer: {
            SGFootnote(prefs.serverChoice == .ntfySh
                       ? L("Su ntfy.sh il gestore del servizio può leggere il testo delle notifiche: Nod lo tiene al minimo. Un server tuo lo evita.")
                       : L("Con un server tuo il contenuto resta lì; a ntfy.sh arriva solo un avviso senza testo, che serve all'iPhone per riceverlo subito."))
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
