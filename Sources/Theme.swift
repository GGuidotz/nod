// Aspetto dell'app scelto, accento e superfici. Le forme, i riempimenti, i colori neutri e le molle vengono da Sguardo, il
// sistema di design comune (Vendor/Sguardo, compilato insieme all'app da build.sh): qui restano l'accento di Nod e i
// pochi adattatori che mantengono le firme usate dalle viste.
// Regola (HIG, Materials / Liquid Glass): il vetro solo sui controlli che galleggiano (la barra delle schede, la barra
// dei passi della configurazione), mai sul contenuto; il contenuto usa i riempimenti di Sguardo (velo traslucido più filo
// da 1 pt). Riduci trasparenza e Aumenta contrasto li gestisce il sistema; con Riduci movimento le molle diventano dissolvenze.

import AppKit
import SwiftUI

extension SG.Accent {
    /// L'accento di Nod per Sguardo: il blu del marchio (rgb 0,11 · 0,62 · 0,86, #1C9EDB). Il bianco sopra dà circa 3:1, sotto i 4,5:1.
    static let nod = SG.Accent(NSColor(srgbRed: 0.11, green: 0.62, blue: 0.86, alpha: 1))
}

/// Aspetto dell'app scelto nelle impostazioni (Sistema segue macOS).
enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Chiaro"
        case .dark: "Scuro"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

extension View {
    /// Vetro per i controlli che galleggiano (barra dei passi, capsule). Mai per il contenuto. Prima di macOS 26:
    /// materiale + velo + filo (Sguardo).
    func glassSurface(in shape: some InsettableShape, interactive: Bool = false) -> some View {
        sgFloatingChrome(in: shape, interactive: interactive)
    }

    /// Una scheda del contenuto, come le righe di Sguardo: velo traslucido (più bianco della finestra in chiaro), filo da
    /// 1 pt, angoli continui da 16 pt. Niente vetro (il vetro è dei controlli), niente ombre.
    func contentCard(padding: CGFloat = SG.Space.l, radius: CGFloat = SG.Radius.row) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(ContentCardBackground(radius: radius))
    }
}

private struct ContentCardBackground: ViewModifier {
    var radius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .sgRowSurface(in: shape)
            .overlay {
                // Aumenta contrasto: un bordo pieno sopra il filo.
                if contrast == .increased { shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 1) }
            }
    }
}
