// L'icona nel Dock all'avvio: misura l'icona del bundle (quella che il Dock disegna) e, se risulta vuota, mette nel Dock
// l'icona classica inclusa (AppIcon.icns) e lo annota nel registro. Lo stesso se l'icona classica è scelta in Diagnostica.

import AppKit

@MainActor
final class IconHealth: ObservableObject {
    static let shared = IconHealth()

    @Published private(set) var coverage: Double?
    @Published private(set) var differenceFromGeneric: Double?
    /// L'icona del bundle è risultata vuota e Nod mostra la classica.
    @Published private(set) var fallbackActive = false
    @Published private(set) var preview: NSImage?
    /// Nod ha messo l'icona classica nel Dock (da togliere se non serve più). Se non serve, l'icona del Dock non si tocca:
    /// niente `applicationIconImage = nil` all'avvio.
    private var classicApplied = false

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }
    var tier: String { info["NodIconTier"] as? String ?? "unknown" }
    /// Le misure di build.sh (tools/icon-check), se il controllo è stato fatto.
    var buildCheck: String? { info["NodIconCheck"] as? String }
    var iconName: String? { info["CFBundleIconName"] as? String }
    var hasAssetCatalog: Bool { Bundle.main.url(forResource: "Assets", withExtension: "car") != nil }

    /// Misura l'icona e sceglie quella del Dock: la classica se richiesta o se quella del bundle è vuota.
    func apply(forceClassic: Bool) {
        let image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        var empty = false
        if let rep = IconMetrics.render(image), let generic = IconMetrics.render(IconMetrics.genericAppIcon) {
            let coverage = IconMetrics.coverage(rep), difference = IconMetrics.difference(rep, generic)
            self.coverage = coverage
            differenceFromGeneric = difference
            let snapshot = NSImage(size: NSSize(width: IconMetrics.side, height: IconMetrics.side))
            snapshot.addRepresentation(rep)
            preview = snapshot
            empty = IconMetrics.looksEmpty(coverage: coverage, differenceFromGeneric: difference)
            diag(.icon, "bundle icon: tier \(tier), coverage \(IconMetrics.percent(coverage)), "
                 + "different from generic \(IconMetrics.percent(difference))" + (empty ? " → looks empty" : ""))
        }
        fallbackActive = empty && !forceClassic
        if forceClassic || empty, let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let classic = NSImage(contentsOf: url) {
            NSApp?.applicationIconImage = classic
            classicApplied = true
            if fallbackActive { diag(.icon, "classic Dock icon applied automatically") }
        } else if classicApplied {
            NSApp?.applicationIconImage = nil
            classicApplied = false
        }
    }
}
