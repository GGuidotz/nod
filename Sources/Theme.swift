// Colori del marchio, sfondo aurora e Liquid Glass.
// Regola (HIG, Materials / Liquid Glass): il vetro solo sui controlli che galleggiano (barre, pulsanti), mai sul contenuto;
// il contenuto usa i materiali standard. Su macOS 26+ il vetro vero (`glassEffect`), prima un materiale sottile.
// Riduci trasparenza e Aumenta contrasto li gestisce il sistema; con Riduci movimento l'aurora sta ferma.

import AppKit
import SwiftUI

enum Brand {
    static let night = Color(red: 0.047, green: 0.071, blue: 0.204)
    static let indigo = Color(red: 0.118, green: 0.173, blue: 0.471)
    static let violet = Color(red: 0.431, green: 0.275, blue: 0.863)
    static let aurora = Color(red: 0.157, green: 0.839, blue: 0.925)
    /// Il colore delle azioni principali e degli stati positivi.
    static let accent = Color(red: 0.11, green: 0.62, blue: 0.86)

    static let gradient = LinearGradient(colors: [aurora, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
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

/// Sfondo del livello del contenuto: un'aurora che si muove piano (MeshGradient su macOS 15+).
struct AuroraBackground: View {
    /// 1 nella configurazione, più tenue dietro i moduli della finestra principale.
    var intensity: Double = 1
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
                    MeshGradient(width: 3, height: 3,
                                 points: points(reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate),
                                 colors: colors)
                }
            } else {
                LinearGradient(colors: [colors[0], colors[4], colors[8]], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .opacity(intensity)
        .background(scheme == .dark ? Brand.night : Color(nsColor: .windowBackgroundColor))
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        if scheme == .dark {
            return [Brand.violet.opacity(0.85), Brand.night, Brand.indigo,
                    Brand.night, Brand.indigo, Brand.accent.opacity(0.7),
                    Brand.indigo, Brand.accent.opacity(0.8), Brand.aurora]
        }
        let pale = Color(red: 0.93, green: 0.95, blue: 1.0)
        return [Color(red: 0.86, green: 0.82, blue: 1.0), pale, Color(red: 0.84, green: 0.93, blue: 1.0),
                pale, .white, Color(red: 0.80, green: 0.94, blue: 0.98),
                Color(red: 0.88, green: 0.90, blue: 1.0), Color(red: 0.78, green: 0.93, blue: 0.99),
                Color(red: 0.70, green: 0.94, blue: 0.97)]
    }

    private func points(_ t: Double) -> [SIMD2<Float>] {
        let a = Float(sin(t / 7)) * 0.12, b = Float(cos(t / 9)) * 0.10, c = Float(sin(t / 11)) * 0.08
        return [[0, 0], [0.5 + c, 0], [1, 0],
                [0, 0.5 + b], [0.5 + a, 0.5 - b], [1, 0.5 + c],
                [0, 1], [0.5 - a, 1], [1, 1]]
    }
}

extension View {
    /// Vetro per i controlli che galleggiano (barra della configurazione, capsule). Mai per il contenuto.
    @ViewBuilder
    func glassSurface(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Il pulsante principale (uno per vista): vetro colorato su macOS 26+.
    @ViewBuilder
    func primaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent).tint(Brand.accent).controlSize(.large)
        } else {
            self.buttonStyle(.borderedProminent).tint(Brand.accent).controlSize(.large)
        }
    }

    @ViewBuilder
    func secondaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass).controlSize(.large)
        } else {
            self.buttonStyle(.bordered).controlSize(.large)
        }
    }

    /// Una scheda del contenuto: materiale standard (non vetro), angoli ampi.
    func contentCard(padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }
}

/// Contenitore dei controlli di vetro: su macOS 26 le forme vicine si fondono e si trasformano insieme.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
