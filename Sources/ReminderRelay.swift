// Avvisi sul Watch con Promemoria (iCloud): nativo su iPhone e Watch, senza app da installare. Nod crea nella lista "Nod"
// dell'account iCloud un promemoria con l'allarme fra pochi secondi; iCloud lo porta sull'iPhone e il Watch rispecchia
// l'avviso (di solito entro qualche secondo, a volte un minuto).
// Risposta: completare il promemoria (dall'avviso sul Watch o dall'app Promemoria) vale come risposta. Nod ascolta le
// modifiche di EventKit e in più controlla ogni 5 s finché c'è una richiesta aperta. Come i token di ntfy: vale solo un
// promemoria creato da Nod, entro la sua scadenza, una volta sola; dopo la risposta o la scadenza viene cancellato.

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
    /// L'ultima andata e ritorno: promemoria completato dal Watch e visto dal Mac.
    @Published private(set) var lastRoundTrip: String?

    private struct Pending {
        let created: Date
        let expires: Date
        let ref: String
        let onComplete: @MainActor () -> Void
    }

    private let store = EKEventStore()
    private let prefs: Preferences
    private var cleanups: [String: Task<Void, Never>] = [:]
    private var pending: [String: Pending] = [:]
    private var pollTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    init(prefs: Preferences) {
        self.prefs = prefs
        refreshAccess()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPending() }
        }
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

    /// Crea l'avviso e aspetta la risposta: se lo completi entro `lifetime`, `onComplete` viene chiamato una volta.
    @discardableResult
    func ask(title: String, notes: String, lifetime: TimeInterval, force: Bool = false,
             onComplete: @escaping @MainActor () -> Void) -> String? {
        let ref = String(UUID().uuidString.prefix(8)).lowercased()
        guard let id = alert(title: title, notes: notes + "\n\n[nod:\(ref)]",
                             lifetime: lifetime, force: force) else { return nil }
        pending[id] = Pending(created: Date(), expires: Date().addingTimeInterval(lifetime), ref: ref, onComplete: onComplete)
        startPolling()
        return id
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
        if pending.removeValue(forKey: id) != nil, reason == "expired" { diag(.reminders, "no answer before expiry") }
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        do {
            try store.remove(reminder, commit: true)
            diag(.reminders, "alert removed (\(reason))")
        } catch {
            diag(.reminders, "alert not removed: \(error.localizedDescription)")
        }
    }

    func sendTest() {
        ask(title: L("Nod: prova"), notes: L("Completalo dal Watch: Nod ti dirà dopo quanti secondi l'ha visto."), lifetime: 600, force: true) {
            [weak self] in self?.lastEvent = L("Risposta da Promemoria ricevuta.")
        }
    }

    // MARK: risposte

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, !self.pending.isEmpty else { break }
                self.store.refreshSourcesIfNecessary()
                self.checkPending()
            }
            self?.pollTask = nil
        }
    }

    /// Per ogni richiesta aperta: il promemoria è completato? Prima per id, poi (se iCloud l'ha cambiato) per riferimento.
    private func checkPending() {
        guard !pending.isEmpty else { return }
        for (id, entry) in pending {
            if entry.expires < Date() { continue }   // la pulizia a scadenza lo cancella
            if let reminder = store.calendarItem(withIdentifier: id) as? EKReminder {
                if reminder.isCompleted { complete(id, entry) }
                continue
            }
            findByRef(entry.ref) { [weak self] reminder in
                guard let self, let reminder, reminder.isCompleted, self.pending[id] != nil else { return }
                self.complete(id, entry, reminder: reminder)
            }
        }
    }

    private func complete(_ id: String, _ entry: Pending, reminder: EKReminder? = nil) {
        guard pending.removeValue(forKey: id) != nil else { return }
        let seconds = Int(Date().timeIntervalSince(entry.created))
        lastRoundTrip = "\(DiagnosticsLog.stamp(Date())) completed after \(seconds) s"
        lastEvent = L("Risposta da Promemoria ricevuta in %d s.", seconds)
        diag(.reminders, "completed on another device after \(seconds)s (round trip ok)")
        entry.onComplete()
        if let reminder {
            cleanups[id]?.cancel()
            cleanups[id] = nil
            try? store.remove(reminder, commit: true)
            diag(.reminders, "alert removed (answered)")
        } else {
            clear(id, reason: "answered")
        }
    }

    private func findByRef(_ ref: String, _ done: @escaping @MainActor (EKReminder?) -> Void) {
        guard let list = store.calendars(for: .reminder).first(where: { $0.title == Self.listTitle }) else { done(nil); return }
        let predicate = store.predicateForReminders(in: [list])
        store.fetchReminders(matching: predicate) { reminders in
            let match = reminders?.first { $0.notes?.contains("[nod:\(ref)]") == true }
            Task { @MainActor in done(match) }
        }
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
