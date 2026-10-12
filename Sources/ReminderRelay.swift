// Avvisi sul Watch con Promemoria (iCloud): nativo su iPhone e Watch, senza app da installare. Nod crea nella lista "Nod"
// dell'account iCloud un promemoria con l'allarme fra pochi secondi; iCloud lo porta sull'iPhone e il Watch rispecchia
// l'avviso (di solito entro qualche secondo, a volte un minuto). Niente pulsanti: si risponde con Touch ID al Mac o con la
// notifica ntfy. Dopo la risposta o la scadenza il promemoria viene cancellato, così la lista resta vuota.

import EventKit
import Foundation

@MainActor
final class ReminderRelay: ObservableObject {
    enum Access: String { case notDetermined, denied, granted }

    enum Failure: LocalizedError {
        case noICloud
        var errorDescription: String? { L("Nessun account iCloud con Promemoria su questo Mac.") }
    }

    static let listTitle = "Nod"

    @Published private(set) var access: Access = .notDetermined
    @Published private(set) var lastEvent: String?
    /// Per la diagnostica: dove sta la lista "Nod" e l'ultimo avviso creato.
    @Published private(set) var listStatus: String?
    @Published private(set) var lastAlert: String?
    /// La lista "Nod" è solo su questo Mac: l'iPhone non la vede.
    @Published private(set) var listIsLocal = false

    private let store = EKEventStore()
    private let prefs: Preferences
    private var cleanups: [String: Task<Void, Never>] = [:]

    init(prefs: Preferences) {
        self.prefs = prefs
        refreshAccess()
    }

    func refreshAccess() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            diag(.reminders, "access \(granted ? "granted" : "denied")")
        } catch {
            diag(.reminders, "access request failed: \(error.localizedDescription)")
        }
        refreshAccess()
        if access == .granted {
            prefs.remindersEnabled = true
            _ = try? nodList()
        } else {
            prefs.remindersEnabled = false
            lastEvent = L("Accesso a Promemoria negato: Impostazioni di Sistema > Privacy e sicurezza > Promemoria.")
        }
    }

    /// Crea l'avviso e restituisce l'id da passare a `clear`; dopo `lifetime` si cancella da solo.
    /// `force` lo crea anche con il canale spento (la prova).
    @discardableResult
    func alert(title: String, notes: String, lifetime: TimeInterval, force: Bool = false) -> String? {
        guard force || prefs.remindersEnabled else { return nil }
        refreshAccess()
        guard access == .granted else {
            lastEvent = L("Serve l'accesso a Promemoria.")
            return nil
        }
        do {
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = try nodList()
            reminder.title = title
            reminder.notes = notes
            reminder.priority = 1
            let fire = Date().addingTimeInterval(5)
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
            reminder.addAlarm(EKAlarm(absoluteDate: fire))
            try store.save(reminder, commit: true)
            let id = reminder.calendarItemIdentifier
            lastAlert = "\(DiagnosticsLog.stamp(Date())) created, alarm +5 s, lifetime \(Int(lifetime)) s"
            lastEvent = L("Promemoria creato: l'avviso arriva sul Watch appena iCloud lo sincronizza.")
            diag(.reminders, "alert created (lifetime \(Int(lifetime))s)")
            cleanups[id] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(lifetime, 10) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.clear(id, reason: "expired")
            }
            return id
        } catch {
            lastEvent = L("Promemoria non creato: %@", error.localizedDescription)
            lastAlert = "\(DiagnosticsLog.stamp(Date())) failed: \(error.localizedDescription)"
            diag(.reminders, "alert failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Cancella l'avviso (risposta arrivata o tempo scaduto).
    func clear(_ id: String?, reason: String = "answered") {
        guard let id else { return }
        cleanups[id]?.cancel()
        cleanups[id] = nil
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        do {
            try store.remove(reminder, commit: true)
            diag(.reminders, "alert removed (\(reason))")
        } catch {
            diag(.reminders, "alert not removed: \(error.localizedDescription)")
        }
    }

    func sendTest() {
        alert(title: L("Nod: prova"), notes: L("Se vedi questo avviso sul Watch, Promemoria funziona."), lifetime: 120, force: true)
    }

    /// La lista "Nod", creata nell'account iCloud se manca (una lista "Sul mio Mac" non arriva all'iPhone).
    private func nodList() throws -> EKCalendar {
        let lists = store.calendars(for: .reminder)
        if let list = lists.first(where: { $0.title == Self.listTitle }) {
            noteList(list)
            return list
        }
        let candidates = [store.defaultCalendarForNewReminders()?.source].compactMap { $0 } + lists.compactMap(\.source)
        guard let source = candidates.first(where: { $0.sourceType == .calDAV }) else { throw Failure.noICloud }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = Self.listTitle
        list.source = source
        try store.saveCalendar(list, commit: true)
        diag(.reminders, "created list \"\(Self.listTitle)\" in \(source.title)")
        noteList(list)
        return list
    }

    private func noteList(_ list: EKCalendar) {
        listIsLocal = list.source.sourceType != .calDAV
        listStatus = "\"\(list.title)\" in \(list.source.title)" + (listIsLocal ? " (this Mac only)" : "")
    }
}
